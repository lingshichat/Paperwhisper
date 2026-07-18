import 'dart:async';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img; // Added for splitting
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/diary_provider.dart';
import '../providers/sync_provider.dart';
import '../models/diary_entry.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';
import '../widgets/paper_sheet_widget.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../services/draft_service.dart'; // Added
import '../widgets/slide_page_route.dart'; // Needed for "Save As New" navigation
import '../widgets/skeuomorphic_date_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../widgets/export_success_dialog.dart';
import 'package:flutter/rendering.dart'; // For RenderRepaintBoundary
import 'package:permission_handler/permission_handler.dart';

class EditorPage extends StatefulWidget {
  final DiaryEntry? entry;
  final bool lazyLoad; // 是否延迟加载内容（长日记优化）
  final void Function(VoidCallback)? onContentReady; // 内容准备好的回调
  final bool usePreviewMode; // 首屏渲染优化模式

  const EditorPage({
    super.key,
    this.entry,
    this.lazyLoad = false,
    this.onContentReady,
    this.usePreviewMode = false,
  });

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController
  _previewController; // Controller for truncated text

  late WeatherType _weather;
  late MoodType _mood;
  late bool _isMarkdown;

  bool _isEditing = false;
  late String _currentDateStr;

  // 懒加载状态
  bool _isPreviewMode = false; // 是否处于首屏预览模式

  // Draft Logic
  // Focus Node
  final FocusNode _focusNode = FocusNode();

  final _draftService = DraftService();
  Timer? _autoSaveTimer;
  bool _hasDraftChanges = false;
  bool _hasCheckedDraft = false; // Prevent double checking

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final e = widget.entry;
    final fullText = e?.content ?? '';
    _titleController = TextEditingController(text: e?.title ?? '');
    _contentController = TextEditingController(text: fullText);

    // 初始化预览控制器：只截取前 200 字符（约一屏），极致减少渲染压力
    // 1000字符依然会导致显著卡顿，200字符是性能与视觉填充的平衡点
    _previewController = TextEditingController(
      text: fullText.length > 200 ? fullText.substring(0, 200) : fullText,
    );

    _weather = e?.weather ?? WeatherType.sunny;
    _mood = e?.mood ?? MoodType.calm;
    _isMarkdown = e?.isMarkdown ?? false;
    _isEditing = (e == null);
    _currentDateStr = e?.dateString ?? DateTime.now().toString().split(' ')[0];

    // 初始化状态
    _isPreviewMode = widget.usePreviewMode;

    if (widget.onContentReady != null) {
      widget.onContentReady!(() {
        if (mounted) {
          setState(() {
            _isPreviewMode = false;
          });
        }
      });
    }

    // Listeners for auto-save
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    // Check Draft after UI build (For BOTH new and existing entries)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDraft());
  }

  // 监听路由动画状态
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 获取当前路由的动画对象
    final route = ModalRoute.of(context);
    if (route != null && route is PageRoute && _routeAnimation == null) {
      _routeAnimation = route.animation;
      _routeAnimation!.addStatusListener(_onRouteAnimationStatusChanged);
    }
  }

  void _onRouteAnimationStatusChanged(AnimationStatus status) {
    // 当路由动画开始反向运行（退出/返回）时
    if (status == AnimationStatus.reverse) {
      // 必须同步最新的编辑内容到预览控制器
      if (!_isPreviewMode) {
        final fullText = _contentController.text;
        final trunk =
            fullText.length > 200 ? fullText.substring(0, 200) : fullText;
        if (_previewController.text != trunk) {
          _previewController.text = trunk;
        }

        setState(() {
          _isPreviewMode = true; // 开启优化的预览模式
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 移除监听
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _performAutoSave(); // 切后台立即保存
    }
  }

  // Auto-Save Logic (Debounce)
  void _onTextChanged() {
    if (!_isEditing) return;

    // Reset timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _performAutoSave);
    _hasDraftChanges = true;
  }

  Future<void> _performAutoSave() async {
    if (!mounted || !_hasDraftChanges) return;
    if (_titleController.text.isEmpty && _contentController.text.isEmpty)
      return; // 空内容不存

    final id = widget.entry?.filename ?? 'new';
    final currentEntry = DiaryEntry(
      filename: id == 'new' ? '' : id,
      dateString: _currentDateStr,
      title: _titleController.text,
      weather: _weather,
      mood: _mood,
      content: _contentController.text,
      isMarkdown: _isMarkdown,
    );

    await _draftService.saveDraft(id, currentEntry);
    debugPrint('Auto-saved draft for $id');
    _hasDraftChanges = false;
  }

  // Restore Logic
  // Static lock to prevent multiple dialogs (e.g. double click opening two pages)
  static bool _isDialogShowing = false;

  Future<void> _checkDraft() async {
    if (_hasCheckedDraft) return;
    _hasCheckedDraft = true;

    final id = widget.entry?.filename ?? 'new';
    final draft = await _draftService.getDraft(id);

    if (draft == null) return;

    // 如果是新建，只要有草稿就恢复
    // 如果是编辑旧日记，对比内容是否不同
    if (id != 'new') {
      final currentContent = widget.entry?.content ?? '';
      if (draft.content == currentContent &&
          draft.title == (widget.entry?.title ?? '')) {
        await _draftService.clearDraft(id);
        return;
      }
    } else {
      if (draft.content.isEmpty && draft.title.isEmpty) {
        await _draftService.clearDraft(id);
        return;
      }
    }

    if (!mounted) return;

    // Critical Check: If dialog is already showing (globally), skip this one
    if (_isDialogShowing) return;

    bool isIncomplete = false;
    if (id != 'new' && widget.entry != null) {
      if (draft.content.length < widget.entry!.content.length) {
        isIncomplete = true;
      }
    }

    _isDialogShowing = true; // Lock

    await showDialog(
      // await the dialog result to ensure lock is held
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => SkeuomorphicDialog(
            title: isIncomplete ? '发现残缺手稿' : '发现未保存手稿',
            headerIcon:
                isIncomplete ? Icons.warning_amber_rounded : Icons.restore_page,
            content: Text(
              isIncomplete
                  ? '上次编辑可能意外中断，本地草稿内容少于原日记。\n建议"另存为新日记"以对比查看，\n或选择"丢弃"保留原样。'
                  : '上次编辑似乎没有保存成功，\n是否恢复到当时的状态？',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerifSc(fontSize: 16, height: 1.6),
            ),
            // Use footer for custom layout (Column > [Button, Row])
            actions: null,
            footer: Column(
              children: [
                // 1. 另存为新日记 (Safe Choice - Primary Action)
                SkeuomorphicDialogButton(
                  label: '另存为新日记',
                  isPrimary: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      SlidePageRoute(
                        page: EditorPage(
                          entry: DiaryEntry(
                            filename: '',
                            dateString: draft.dateString,
                            title: draft.title,
                            content: draft.content,
                            weather: draft.weather,
                            mood: draft.mood,
                            isMarkdown: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12), // Spacing
                // 2. Secondary Actions in a Row
                Row(
                  children: [
                    // 丢弃 (Discard)
                    Expanded(
                      child: SkeuomorphicDialogButton(
                        label: '丢弃草稿',
                        isPrimary: false,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _draftService.clearDraft(id);
                          if (mounted)
                            SkeuomorphicToast.success(context, '草稿已丢弃');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 恢复 (Overwrite)
                    Expanded(
                      child: SkeuomorphicDialogButton(
                        label: '恢复覆盖',
                        isPrimary: !isIncomplete,
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          setState(() {
                            _titleController.text = draft.title;
                            _contentController.text = draft.content;
                            _weather = draft.weather;
                            _mood = draft.mood;
                            _currentDateStr = draft.dateString;
                          });
                          if (mounted)
                            SkeuomorphicToast.success(context, '内容已恢复');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );

    _isDialogShowing = false; // Reset lock
  }

  void _save() async {
    // 1. STOP AUTO SAVE! Prevent race condition where auto-save writes draft AFTER we clear it
    _autoSaveTimer?.cancel();
    _hasDraftChanges = false;

    final provider = Provider.of<DiaryProvider>(context, listen: false);
    final newEntry = DiaryEntry(
      filename: widget.entry?.filename ?? '',
      dateString: _currentDateStr,
      title: _titleController.text,
      weather: _weather,
      mood: _mood,
      content: _contentController.text,
      isMarkdown: _isMarkdown,
    );

    try {
      await provider.saveEntry(newEntry);

      // Save Success: Clear Draft!
      final id = widget.entry?.filename ?? 'new';
      await _draftService.clearDraft(id);

      if (mounted) {
        final syncProvider = context.read<SyncProvider>();
        await syncProvider.refreshTrustSnapshot();
        final pendingCount = syncProvider.trustSnapshot.totalPendingCount;

        if (syncProvider.config.enabled &&
            syncProvider.config.autoSync &&
            syncProvider.isConfigured) {
          SkeuomorphicToast.success(context, '日记已保存，准备同步...');
          final granted = await syncProvider.checkNotificationPermission(
            context,
          );
          if (mounted && granted) {
            unawaited(syncProvider.requestAutoSync(context: context));
          }
        } else if (syncProvider.config.enabled && pendingCount > 0) {
          SkeuomorphicToast.info(context, '已保存，尚有 $pendingCount 项待同步');
        } else {
          SkeuomorphicToast.success(context, '日记已保存');
        }
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Save failed: $e");
      if (mounted) {
        SkeuomorphicToast.error(context, '保存失败: $e\n请检查存储权限或稍后重试');
      }
    }
  }

  void _delete() async {
    if (widget.entry == null) return;

    // STOP AUTO SAVE
    _autoSaveTimer?.cancel();
    _hasDraftChanges = false;

    final provider = Provider.of<DiaryProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => SkeuomorphicDialog(
            title: '移入回收站？',
            headerIcon: Icons.delete_outline,
            content: Text(
              '这段回忆会先放入回收站，之后仍可恢复。\n确定要继续吗？',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerifSc(fontSize: 16, height: 1.6),
            ),
            actions: [
              SkeuomorphicDialogButton(
                label: '移入回收站',
                isPrimary: true,
                onPressed: () => Navigator.pop(ctx, true),
              ),
              SkeuomorphicDialogButton(
                label: '保留',
                isPrimary: false,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await provider.deleteEntry(widget.entry!.filename);
      // Delete success: Also clear draft if any
      await _draftService.clearDraft(widget.entry!.filename);
      if (mounted) {
        final syncProvider = context.read<SyncProvider>();
        await syncProvider.refreshTrustSnapshot();
      }

      if (mounted) Navigator.pop(context);
    }
  }

  bool get _hasChanges {
    // New entry: only dirty if there is content
    if (widget.entry == null) {
      return _titleController.text.isNotEmpty ||
          _contentController.text.isNotEmpty;
    }
    // Existing entry: compare with initial values
    return _titleController.text != (widget.entry?.title ?? '') ||
        _contentController.text != (widget.entry?.content ?? '') ||
        _weather != (widget.entry?.weather ?? WeatherType.sunny) ||
        _mood != (widget.entry?.mood ?? MoodType.calm);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder:
          (context) => SkeuomorphicDialog(
            title: '尚未保存',
            headerIcon: Icons.save_as,
            content: Text(
              '文字还未落到纸上，确认要丢弃刚才的修改吗？',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerifSc(fontSize: 16, height: 1.6),
            ),
            actions: [
              SkeuomorphicDialogButton(
                label: '丢弃',
                isPrimary: false,
                onPressed: () async {
                  // Discard: Clear draft too!
                  final id = widget.entry?.filename ?? 'new';
                  await _draftService.clearDraft(id);
                  Navigator.pop(context, true);
                },
              ),
              SkeuomorphicDialogButton(
                label: '继续编辑',
                isPrimary: true,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
    );

    return shouldPop ?? false;
  }

  bool _isCaptureMode = false;

  @override
  Widget build(BuildContext context) {
    // print('DEBUG: EditorPage build called'); // Temporary debug
    // ... (Keep existing build method unchanged)
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final textColor = AppTheme.getTextColor(theme);
    final secondaryColor = AppTheme.getTextSecondaryColor(theme);

    // 700px width constraint handled by PaperSheetWidget
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (await _onWillPop() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1. Background
            Container(decoration: AppTheme.getBackground(theme)),

            // 2. Visual Effects (由 AppTheme 统一管理)
            ...AppTheme.getBackgroundOverlays(theme),

            if (!_isCaptureMode)
              Column(
                children: [
                  _buildTopBar(context, theme, textColor),

                  _buildAdaptiveContent(textColor, secondaryColor, theme),
                ],
              ),

            // Export View (Multi-Chunk)
            if (_isCaptureMode)
              Positioned.fill(
                child: Container(
                  decoration: AppTheme.getBackground(theme),
                  child: SingleChildScrollView(
                    child: Center(
                      child: Container(
                        width: 700,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _buildExportChunks(
                            textColor,
                            secondaryColor,
                            theme,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (_isCaptureMode)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        "正在生成长图...",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingFooter(Color secondaryColor) {
    return Center(
      child: Column(
        children: [
          Text(
            'CREATED WITH',
            style: GoogleFonts.courierPrime(
              fontSize: 10,
              color: secondaryColor.withValues(alpha: 0.4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '纸语 PaperWhisper',
            style: GoogleFonts.notoSerifSc(
              fontSize: 12,
              color: secondaryColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildWordCount(Color color) {
    if (_contentController.text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(height: 1, width: 20, color: color.withValues(alpha: 0.2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${_contentController.text.length} 字',
              style: GoogleFonts.notoSerifSc(
                fontSize: 12,
                color: color.withValues(alpha: 0.4),
                letterSpacing: 1,
              ),
            ),
          ),
          Container(height: 1, width: 20, color: color.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _buildAdaptiveContent(
    Color textColor,
    Color secondaryColor,
    String theme,
  ) {
    // Threshold for switching to performance mode
    // ~200 lines or ~5000 chars
    bool usePerformanceMode = _contentController.text.length > 3000;
    final tc = AppTheme.getEditorTheme(theme);

    if (usePerformanceMode) {
      // --- Performance Mode (Slivers) ---
      // Fully expanded, no outer padding
      return Expanded(
        child: RepaintBoundary(
          // key: _sheetKey, // Removed to avoid conflict with export view
          child: PaperSheetWidget(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildHeader(textColor, secondaryColor),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 2,
                        color: (tc['cursorColor'] as Color).withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildContentSliver(textColor, theme),
                SliverToBoxAdapter(child: const SizedBox(height: 40)),
                SliverToBoxAdapter(
                  child: _buildWordCount(secondaryColor),
                ), // Word Count
                SliverToBoxAdapter(child: const SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildBrandingFooter(secondaryColor)),
                // Sufficient bottom padding inside the scroll view
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ),
      );
    } else {
      // --- Standard Mode (SingleChildScrollView) ---
      // Uses shrinkWrap to float as a card when short, fills screen when long
      return Expanded(
        child: RepaintBoundary(
          // key: _sheetKey, // Removed to avoid conflict with export view
          child: PaperSheetWidget(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(textColor, secondaryColor),
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      width: 60,
                      height: 2,
                      color: (tc['cursorColor'] as Color).withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Standard Content Area (TextField/Text)
                  _buildContentArea(textColor, theme),
                  const SizedBox(height: 30),
                  _buildWordCount(secondaryColor), // Word Count
                  const SizedBox(height: 10),
                  _buildBrandingFooter(secondaryColor),
                  // Bottom padding inside scroll view
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTopBar(BuildContext context, String theme, Color textColor) {
    final tc = AppTheme.getEditorTheme(theme);

    final Color barBg = tc['appBarBg'];
    final Color iconColor = tc['iconColor'];
    final Border? border = tc['appBarBorder'];

    Widget barContent = Container(
      // 移除固定高度，改用最小高度约束+padding适配
      constraints: BoxConstraints(
        minHeight: kToolbarHeight + MediaQuery.of(context).padding.top,
      ),
      padding: EdgeInsets.only(
        top:
            MediaQuery.of(context).padding.top > 0
                ? MediaQuery.of(context).padding.top
                : 24,
        left: 10,
        right: 20,
        bottom: 8, // 添加底部留白以保证美观
      ),
      decoration: BoxDecoration(color: barBg, border: border),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (await _onWillPop()) {
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: iconColor, size: 18),
                  const SizedBox(width: 4),
                  Text('返回列表', style: TextStyle(color: iconColor)),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Action Buttons
          IconButton(
            icon: Icon(Icons.share_outlined, color: iconColor),
            onPressed: _captureAndSave,
            tooltip: '导出为图片',
          ),
          const SizedBox(width: 5),

          if (!_isEditing && widget.entry != null) ...[
            IconButton(
              icon: Icon(Icons.delete_outline, color: iconColor),
              onPressed: _delete,
              tooltip: '撕毁',
            ),
            const SizedBox(width: 10),
          ],

          if (_isEditing)
            GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tc['saveButtonBg'],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      offset: const Offset(0, -1),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '✓',
                      style: TextStyle(
                        color: tc['saveButtonCheckColor'],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '完成',
                      style: TextStyle(
                        color: tc['saveButtonTextColor'],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.edit_outlined, color: iconColor),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: '编辑',
            ),
        ],
      ),
    );

    // 部分主题需要模糊效果
    if (tc['applyBlur'] == true) {
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: barContent,
        ),
      );
    }

    return barContent;
  }

  /// Export-specific header - uses pure Text widgets to avoid
  /// TextField, DropdownButton, PopupMenuButton artifacts in exported images.
  Widget _buildExportHeader(Color textColor, Color secondaryColor) {
    return Column(
      children: [
        // Title (always Text, never TextField)
        Text(
          _titleController.text.isEmpty ? '无题' : _titleController.text,
          style: GoogleFonts.notoSerifSc(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 15),
        // Meta (all Text, no interactive elements)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(_currentDateStr, style: _metaStyle(secondaryColor)),
            _metaSeparator(secondaryColor),
            Text(
              _weather.name.toUpperCase(),
              style: _metaStyle(secondaryColor),
            ),
            _metaSeparator(secondaryColor),
            Text(_mood.name.toUpperCase(), style: _metaStyle(secondaryColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(Color textColor, Color secondaryColor) {
    // 通过 AppTheme 获取编辑器主题配置
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final tc = AppTheme.getEditorTheme(theme);
    return Column(
      children: [
        if (_isEditing)
          TextField(
            controller: _titleController,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            cursorColor: tc['cursorColor'],
            decoration: InputDecoration(
              hintText: '在此输入标题...',
              hintStyle: TextStyle(color: tc['hintColor']),
              border: InputBorder.none,
            ),
          )
        else
          Text(
            _titleController.text.isEmpty ? '无题' : _titleController.text,
            style: GoogleFonts.notoSerifSc(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: textColor, // Use dynamic theme color
            ),
            textAlign: TextAlign.center,
          ),

        const SizedBox(height: 15),
        // Meta
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                DateTime initialDate;
                try {
                  initialDate = DateTime.parse(_currentDateStr);
                } catch (_) {
                  initialDate = DateTime.now();
                }

                showDialog(
                  context: context,
                  builder:
                      (ctx) => SkeuomorphicDatePicker(
                        initialDate: initialDate,
                        onDateSelected: (date) {
                          setState(() {
                            _currentDateStr =
                                date.toString().split(' ')[0]; // yyyy-MM-dd
                          });
                        },
                      ),
                );
              },
              child: Text(
                _currentDateStr,
                style: _metaStyle(secondaryColor),
              ), // _metaStyle sends color
            ),
            _metaSeparator(secondaryColor),
            _buildWeatherSelector(secondaryColor),
            _metaSeparator(secondaryColor),
            _buildMoodSelector(secondaryColor),
          ],
        ),
      ],
    );
  }

  Widget _buildContentArea(Color textColor, String theme) {
    const double fontSize = 18.0;
    const double lineHeight = 32.0;

    // Strict alignment: height = 32/18 = 1.7777...
    final bool hideLines =
        Provider.of<SettingsProvider>(context).compatibilityMode;

    final tc = AppTheme.getEditorTheme(theme);
    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
        lineColor: hideLines ? Colors.transparent : tc['lineColor'],
        lineHeight: lineHeight,
      ),
      child: Container(
        padding: const EdgeInsets.only(top: 0), // Adjust if needed
        constraints: const BoxConstraints(minHeight: 300),
        child:
            _isEditing
                ? TextField(
                  controller:
                      _isPreviewMode
                          ? _previewController
                          : _contentController, // Fix 1
                  style: GoogleFonts.notoSerifSc(
                    fontSize: fontSize,
                    color: textColor,
                    height: lineHeight / fontSize,
                  ),
                  strutStyle: StrutStyle(
                    fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                    fontSize: fontSize,
                    height: (lineHeight / fontSize),
                    leading: 0,
                    forceStrutHeight: true,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                  cursorColor: tc['cursorColor'],
                  cursorHeight: 22,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.zero, // Important: keep zero to match Strut
                    isCollapsed: true,
                    isDense: true,
                    counterText: "",
                  ),
                  maxLines: null,
                )
                : Text(
                  _isPreviewMode
                      ? _previewController.text
                      : _contentController
                          .text, // Fix 2: Critical for preview lag
                  style: GoogleFonts.notoSerifSc(
                    fontSize: fontSize,
                    color: textColor,
                    height: lineHeight / fontSize,
                  ),
                  // Ensure display text matches input style exactly
                  strutStyle: StrutStyle(
                    fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                    fontSize: fontSize,
                    height: (lineHeight / fontSize),
                    leading: 0,
                    forceStrutHeight: true,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
      ),
    );
  }

  // Helpers
  TextStyle _metaStyle(Color color) =>
      GoogleFonts.courierPrime(fontSize: 14, color: color);

  Widget _metaSeparator(Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      '·',
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildWeatherSelector(Color color) {
    if (!_isEditing) {
      return Text(_weather.name.toUpperCase(), style: _metaStyle(color));
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final tc = AppTheme.getEditorTheme(theme);

    // Dropdown Menu Style
    final Color dropdownBg = tc['dropdownBg'];
    final Color dropdownText = tc['dropdownText'];

    return DropdownButton<WeatherType>(
      value: _weather,
      underline: const SizedBox(),
      icon: const SizedBox(),
      dropdownColor: dropdownBg,
      isDense: true,
      alignment: AlignmentDirectional.center, // Center text in button
      // The text shown on the button (when closed)
      selectedItemBuilder: (BuildContext context) {
        return WeatherType.values.map((w) {
          return Container(
            alignment: Alignment.center,
            child: Text(w.name.toUpperCase(), style: _metaStyle(color)),
          );
        }).toList();
      },
      items:
          WeatherType.values
              .map(
                (w) => DropdownMenuItem(
                  value: w,
                  alignment: AlignmentDirectional.center,
                  child: Text(
                    w.name.toUpperCase(),
                    style: GoogleFonts.courierPrime(
                      fontSize: 14,
                      color: dropdownText,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged: (val) {
        if (val != null) setState(() => _weather = val);
      },
    );
  }

  Widget _buildMoodSelector(Color color) {
    if (!_isEditing) {
      return Text(_mood.name.toUpperCase(), style: _metaStyle(color));
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final tc = AppTheme.getEditorTheme(theme);

    final Color menuBg = tc['dropdownBg'];
    final Color menuText = tc['dropdownText'];

    return PopupMenuButton<MoodType>(
      initialValue: _mood,
      color: menuBg,
      padding: EdgeInsets.zero,
      tooltip: '',
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (val) => setState(() => _mood = val),
      itemBuilder:
          (context) =>
              MoodType.values
                  .map(
                    (m) => PopupMenuItem(
                      value: m,
                      child: Text(
                        m.name.toUpperCase(),
                        style: GoogleFonts.courierPrime(
                          fontSize: 14,
                          color: menuText,
                        ),
                      ),
                    ),
                  )
                  .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          _mood.name.toUpperCase(),
          style: _metaStyle(color).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Export Logic
  List<GlobalKey> _exportKeys = [];

  Future<void> _captureAndSave() async {
    try {
      // 1. Prepare Data & Keys
      final String textToExport = _contentController.text;

      final List<String> lines = textToExport.split('\n');
      if (lines.isEmpty) lines.add('');

      const int linesPerChunk =
          40; // 40 lines * 32px = 1280px height (plus padding) -> Safe
      int textChunkCount = (lines.length / linesPerChunk).ceil();
      if (textChunkCount == 0) textChunkCount = 1;

      // Chunks: 1 Header + N Body + 1 Footer
      int totalChunks = 1 + textChunkCount + 1;

      _exportKeys = List.generate(totalChunks, (_) => GlobalKey());

      setState(() => _isCaptureMode = true);

      // 2. Preload fonts
      await GoogleFonts.pendingFonts([
        GoogleFonts.notoSerifSc(),
        GoogleFonts.courierPrime(),
      ]);

      // 3. Wait for Layout
      await Future.delayed(const Duration(milliseconds: 800));

      // 4. Capture All Chunks
      List<img.Image> capturedImages = [];
      double totalHeight = 0;
      double maxWidth = 0;

      for (int i = 0; i < totalChunks; i++) {
        GlobalKey key = _exportKeys[i];
        RenderRepaintBoundary? boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) continue;

        // Use pixelRatio 2.0 or 3.0 depending on need. 2.0 is usually enough for reading, 3.0 is crisp.
        // Since we split, we can afford 3.0 easily.
        double pixelRatio = 3.0;
        ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

        var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        var pngBytes = byteData.buffer.asUint8List();
        img.Image? decoded = img.decodePng(pngBytes);

        if (decoded != null) {
          capturedImages.add(decoded);
          totalHeight += decoded.height;
          if (decoded.width > maxWidth) maxWidth = decoded.width.toDouble();
        }
      }

      if (capturedImages.isEmpty) {
        throw Exception("No content captured");
      }

      // 5. Stitch
      // Create canvas
      img.Image stitchCanvas = img.Image(
        width: maxWidth.toInt(),
        height: totalHeight.toInt(),
      );

      // Fill background (Optional, but images should normally cover it.
      // If there are gaps/transparency, we might want a base color.)
      // But our chunks should include the paper color.

      int currentY = 0;
      for (var imgPart in capturedImages) {
        img.compositeImage(stitchCanvas, imgPart, dstX: 0, dstY: currentY);
        currentY += imgPart.height;
      }

      // 6. Save
      final directory = await getApplicationDocumentsDirectory();
      String exportPath;
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
          exportPath = '/storage/emulated/0/Pictures/PaperWhisper';
        } else {
          final extDir = await getExternalStorageDirectory();
          exportPath = path.join(extDir?.path ?? directory.path, 'Exports');
        }
      } else {
        exportPath = path.join(directory.path, 'PaperWhisper_Exports');
      }

      final exportDir = Directory(exportPath);
      if (!await exportDir.exists()) {
        try {
          await exportDir.create(recursive: true);
        } catch (_) {}
      }

      // Save as single large image (stitched)
      // Or if user wants to split for sharing? The specific requirements was to fix "garbled first image".
      // Stitched image might still be huge (height > 10000).
      // JPG handles large dimensions better than PNG implementation in some viewers?
      // Let's stick to the request: "Fix garbled image". Stitching solves the rendering artifact.
      // We can offer split *after* stitching if it's super huge?
      // But for now, let's output the stitched file.

      String fileName =
          'diary_${widget.entry?.filename ?? "new"}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path.join(exportDir.path, fileName));

      // Encode to JPG (Quality 90)
      await file.writeAsBytes(img.encodeJpg(stitchCanvas, quality: 90));

      if (mounted) {
        await showExportSuccessDialog(context, file.path);
      }
    } catch (e) {
      debugPrint("Export error: $e");
      if (mounted) {
        SkeuomorphicToast.error(context, '导出失败: $e');
      }
    } finally {
      if (mounted) setState(() => _isCaptureMode = false);
    }
  }

  // --- New Helper Methods for CustomScrollView Refactor ---

  Widget _buildContentSliver(Color textColor, String theme) {
    if (_isEditing) {
      return SliverToBoxAdapter(child: _buildEditorField(textColor, theme));
    } else {
      // Split content into lines for performance
      // 在预览模式下，使用截断的文本，这会生成非常少的 lines，极大提升首屏渲染性能
      final text =
          _isPreviewMode ? _previewController.text : _contentController.text;
      final lines = text.split('\n');
      if (lines.isEmpty) lines.add('');

      const double fontSize = 18.0;
      const double lineHeight = 32.0;

      final style = GoogleFonts.notoSerifSc(
        fontSize: fontSize,
        height: lineHeight / fontSize,
        color: textColor,
      );

      final tc = AppTheme.getEditorTheme(theme);

      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final line = lines[index];
          final bool hideLines =
              Provider.of<SettingsProvider>(context).compatibilityMode;

          return CustomPaint(
            foregroundPainter: LinedPaperPainter(
              lineColor: hideLines ? Colors.transparent : tc['lineColor'],
              lineHeight: lineHeight,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: lineHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: 0,
              ), // Already padded by PaperSheetWidget
              alignment: Alignment.centerLeft, // Ensure text starts from left
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isEditing = true;
                  });
                  Future.delayed(const Duration(milliseconds: 50), () {
                    FocusScope.of(context).requestFocus(_focusNode);
                  });
                },
                child: Text(
                  line.isEmpty ? ' ' : line,
                  style: style,
                  strutStyle: StrutStyle(
                    fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                    fontSize: fontSize,
                    height: lineHeight / fontSize,
                    forceStrutHeight: true,
                  ),
                ),
              ),
            ),
          );
        }, childCount: lines.length),
      );
    }
  }

  Widget _buildEditorField(Color textColor, String theme) {
    const double fontSize = 18.0;
    const double lineHeight = 32.0;
    final bool hideLines =
        Provider.of<SettingsProvider>(context).compatibilityMode;

    final tc = AppTheme.getEditorTheme(theme);
    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
        lineColor: hideLines ? Colors.transparent : tc['lineColor'],
        lineHeight: lineHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: TextField(
          controller:
              _isPreviewMode
                  ? _previewController
                  : _contentController, // 预览模式使用截断文本
          focusNode: _focusNode,
          maxLines: null,
          style: GoogleFonts.notoSerifSc(
            fontSize: fontSize,
            color: textColor,
            height: lineHeight / fontSize,
          ),
          strutStyle: StrutStyle(
            fontFamily: GoogleFonts.notoSerifSc().fontFamily,
            fontSize: fontSize,
            height: (lineHeight / fontSize),
            leading: 0,
            forceStrutHeight: true,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isCollapsed: true,
            isDense: true,
          ),
          cursorColor: textColor,
        ),
      ),
    );
  }

  List<Widget> _buildExportChunks(
    Color textColor,
    Color secondaryColor,
    String theme,
  ) {
    if (_exportKeys.isEmpty) return [];

    List<Widget> chunks = [];
    int keyIndex = 0;

    // 通过 AppTheme 获取导出相关颜色
    final tc = AppTheme.getEditorTheme(theme);
    final Color paperColor = tc['exportPaperColor'];
    final Color borderColor = tc['exportBorderColor'];

    // Default theme special case: Top border only.
    final bool isDefaultTheme =
        theme != AppTheme.themeSeaFlower &&
        theme != AppTheme.themeMidnight &&
        theme != AppTheme.themeAmberLens &&
        theme != AppTheme.themeAfterRain;

    // --- Chunk 1: Header ---
    if (keyIndex < _exportKeys.length) {
      chunks.add(
        RepaintBoundary(
          key: _exportKeys[keyIndex++],
          child: Container(
            width: 700,
            decoration: BoxDecoration(
              color: paperColor,
              border: Border(top: BorderSide(color: borderColor, width: 8)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(0),
              ),
            ),
            // Padding handled inside
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 60,
                    right: 60,
                    top: 60,
                    bottom: 0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Default Theme Red Line
                      if (isDefaultTheme)
                        Container(
                          height: 8,
                          width: 80,
                          margin: const EdgeInsets.only(bottom: 20),
                          color: const Color(0xFFC0392B),
                        ),

                      _buildExportHeader(textColor, secondaryColor),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 60,
                          height: 2,
                          color: (tc['cursorColor'] as Color).withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                      ), // Spacing between line and text
                    ],
                  ),
                ),
                // Ribbon (Only on Header)
                Positioned(
                  right: 40,
                  top: -8,
                  child: _buildRibbonForExport(theme),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- Body Chunks ---

    final String textToExport = _contentController.text;

    final List<String> lines = textToExport.split('\n');
    if (lines.isEmpty) lines.add('');

    const int linesPerChunk = 40;

    for (int i = 0; i < lines.length; i += linesPerChunk) {
      int end =
          (i + linesPerChunk < lines.length) ? i + linesPerChunk : lines.length;
      List<String> chunkLines = lines.sublist(i, end);
      String chunkText = chunkLines.join('\n');

      if (keyIndex < _exportKeys.length) {
        chunks.add(
          RepaintBoundary(
            key: _exportKeys[keyIndex++],
            child: Container(
              width: 700,
              decoration: BoxDecoration(
                color: paperColor,
                borderRadius: BorderRadius.zero, // Square for seamless stitch
              ),
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 0),
              child: _buildExportChunkText(chunkText, textColor, theme),
            ),
          ),
        );
      }
    }

    // --- Chunk Last: Footer ---
    if (keyIndex < _exportKeys.length) {
      chunks.add(
        RepaintBoundary(
          key: _exportKeys[keyIndex++],
          child: Container(
            width: 700,
            decoration: BoxDecoration(
              color: paperColor,
              // Rounded Bottom?
            ),
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add a bit of lined paper to fill the gap if last chunk was short?
                // No, simply finish.
                const SizedBox(height: 20),
                _buildBrandingFooter(secondaryColor),
                const SizedBox(height: 40), // Bottom Padding
              ],
            ),
          ),
        ),
      );
    }

    return chunks;
  }

  Widget _buildRibbonForExport(String theme) {
    final tc = AppTheme.getEditorTheme(theme);
    final Color accentColor = tc['ribbonAccentColor'];

    return CustomPaint(
      size: const Size(50, 90),
      painter: _ExportRibbonPainter(color: accentColor),
    );
  }

  Widget _buildExportChunkText(String text, Color textColor, String theme) {
    const double fontSize = 18.0;
    const double lineHeight = 32.0;
    final bool hideLines =
        Provider.of<SettingsProvider>(context).compatibilityMode;
    final tc = AppTheme.getEditorTheme(theme);

    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
        lineColor: hideLines ? Colors.transparent : tc['lineColor'],
        lineHeight: lineHeight,
      ),
      child: Container(
        // Ensure width constraint match
        width: double.infinity,
        padding: EdgeInsets.zero,
        child: Text(
          text,
          style: GoogleFonts.notoSerifSc(
            fontSize: fontSize,
            color: textColor,
            height: lineHeight / fontSize,
          ),
          strutStyle: StrutStyle(
            fontFamily: GoogleFonts.notoSerifSc().fontFamily,
            fontSize: fontSize,
            height: (lineHeight / fontSize),
            leading: 0,
            forceStrutHeight: true,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    );
  }
}

class LinedPaperPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;

  LinedPaperPainter({required this.lineColor, required this.lineHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 1.0;

    // Start drawing lines from top
    // We want the text to sit ON the line. Text height is fixed via StrutStyle.
    // Draw lines exactly at multiples of lineHeight (bottom of each line box)
    for (
      double y = lineHeight;
      y <= size.height + lineHeight;
      y += lineHeight
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ExportRibbonPainter extends CustomPainter {
  final Color color;
  _ExportRibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double ribbonWidth = 40;
    const double ribbonHeight = 80;
    const double offsetX = 5;
    const double offsetY = 0;

    // Shadow
    final ribbonPath = Path();
    ribbonPath.moveTo(offsetX, offsetY);
    ribbonPath.lineTo(offsetX + ribbonWidth, offsetY);
    ribbonPath.lineTo(offsetX + ribbonWidth, offsetY + ribbonHeight);
    ribbonPath.lineTo(offsetX + ribbonWidth / 2, offsetY + ribbonHeight - 20);
    ribbonPath.lineTo(offsetX, offsetY + ribbonHeight);
    ribbonPath.close();

    canvas.save();
    canvas.translate(2, 5);
    final shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            4,
          ); // Lighter shadow for export
    canvas.drawPath(ribbonPath, shadowPaint);
    canvas.restore();

    // Body
    final ribbonPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final mainPath = Path();
    mainPath.moveTo(offsetX, offsetY);
    mainPath.lineTo(offsetX + ribbonWidth, offsetY);
    mainPath.lineTo(offsetX + ribbonWidth, offsetY + ribbonHeight);
    mainPath.lineTo(offsetX + ribbonWidth / 2, offsetY + ribbonHeight - 20);
    mainPath.lineTo(offsetX, offsetY + ribbonHeight);
    mainPath.close();
    canvas.drawPath(mainPath, ribbonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
