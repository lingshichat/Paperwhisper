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
import '../features/editor/application/editor_save_coordinator.dart';
import '../features/editor/application/editor_session_controller.dart';
import '../features/sync/presentation/sync_ui_coordinator.dart';
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
  // 编辑会话：编辑状态、草稿生命周期与自动保存编排由控制器持有
  late final EditorSessionController _session;

  // 保存/删除业务编排协调器（context-free，依赖注入 DiaryProvider）
  EditorSaveCoordinator? _saveCoordinator;

  // 懒加载状态
  bool _isPreviewMode = false; // 是否处于首屏预览模式

  // Focus Node
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 编辑会话：初始值来自入口条目，草稿服务由页面注入
    _session = EditorSessionController(
      initialEntry: widget.entry,
      draftService: DraftService(),
    );

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

    // Check Draft after UI build (For BOTH new and existing entries)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDraft());
  }

  // 监听路由动画状态
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 保存/删除编排协调器：依赖注入 DiaryProvider（懒创建，避免在
    // initState 中读取 InheritedWidget）。
    _saveCoordinator ??= EditorSaveCoordinator(
      diaryProvider: context.read<DiaryProvider>(),
      session: _session,
    );
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
        _session.syncPreviewText();

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
    _session.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _session.performAutoSave(); // 切后台立即保存
    }
  }

  // Auto-Save Logic (Debounce) 由 EditorSessionController 持有
  // Restore Logic
  // Static lock to prevent multiple dialogs (e.g. double click opening two pages)
  static bool _isDialogShowing = false;

  Future<void> _checkDraft() async {
    // 数据判定（草稿是否需恢复/是否残缺）在控制器内完成
    final info = await _session.checkDraftRestore();
    if (info == null) return;

    if (!mounted) return;

    // Critical Check: If dialog is already showing (globally), skip this one
    if (_isDialogShowing) return;

    final draft = info.draft;
    final bool isIncomplete = info.isIncomplete;

    _isDialogShowing = true; // Lock

    await showDialog(
      // await the dialog result to ensure lock is held
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SkeuomorphicDialog(
        title: isIncomplete ? '发现残缺手稿' : '发现未保存手稿',
        headerIcon: isIncomplete
            ? Icons.warning_amber_rounded
            : Icons.restore_page,
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
                      await _session.clearDraft();
                      if (mounted) {
                        SkeuomorphicToast.success(context, '草稿已丢弃');
                      }
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
                        _session.restoreFromDraft(draft);
                      });
                      if (mounted) {
                        SkeuomorphicToast.success(context, '内容已恢复');
                      }
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
    // 保存编排（取消防抖、构建 DiaryEntry、saveEntry、成功清草稿、
    // 失败保留草稿）在 EditorSaveCoordinator 内完成，页面只翻译结果。
    final result = await _saveCoordinator!.save();
    if (!mounted) return;
    switch (result) {
      case EditorSaveValidation():
        // 契约完整性：当前编排不产生该分支，防御忽略
        return;
      case EditorSaveFailure(:final error):
        _showSaveError(error);
        return;
      case EditorSaveSuccess():
        // 保存成功：同步反馈（决策与即时 pending 提示由
        // SyncUiCoordinator 处理），反馈异常与页面原编排一致走保存失败提示
        try {
          final syncProvider = context.read<SyncProvider>();
          await SyncUiCoordinator(context).handleSaveAutoSync(
            provider: syncProvider,
            savedToast: '日记已保存',
            preparingToast: '日记已保存，准备同步...',
          );
          if (!mounted) return;
          Navigator.pop(context);
        } catch (e) {
          _showSaveError(e);
        }
        break;
    }
  }

  void _showSaveError(Object e) {
    debugPrint('Save failed: $e');
    if (mounted) {
      SkeuomorphicToast.error(context, '保存失败: $e\n请检查存储权限或稍后重试');
    }
  }

  void _delete() async {
    if (widget.entry == null) return;

    // 停止防抖（同步）：与原有行为一致，在确认弹窗前取消
    _session.cancelPendingAutoSave();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
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
      // 删除编排（确认后的删除、清草稿）在协调器内完成；删除失败不吞
      // 异常（原页面无 catch，Failure 对象正常不可达），validation 分支
      // 为契约完整性保留，防御忽略
      final result = await _saveCoordinator!.delete(widget.entry!.filename);
      if (!mounted) return;
      switch (result) {
        case EditorDeleteValidation():
          // 契约完整性：当前编排不产生该分支，防御忽略
          return;
        case EditorDeleteFailure():
          // 防御分支：若将来删除改为返回 Failure，展示用户友好提示
          // （不含原始 stack）
          SkeuomorphicToast.error(context, '删除失败，请稍后重试');
          return;
        case EditorDeleteSuccess():
          final syncProvider = context.read<SyncProvider>();
          await syncProvider.refreshTrustSnapshot();
          if (!mounted) return;
          Navigator.pop(context);
          break;
      }
    }
  }

  bool get _hasChanges => _session.hasChanges;

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => SkeuomorphicDialog(
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
              await _session.clearDraft();
              if (!context.mounted) return;
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
    if (_session.contentController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(height: 1, width: 20, color: color.withValues(alpha: 0.2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${_session.contentController.text.length} 字',
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
    bool usePerformanceMode = _session.contentController.text.length > 3000;
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
        top: MediaQuery.of(context).padding.top > 0
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

          if (!_session.isEditing && widget.entry != null) ...[
            IconButton(
              icon: Icon(Icons.delete_outline, color: iconColor),
              onPressed: _delete,
              tooltip: '撕毁',
            ),
            const SizedBox(width: 10),
          ],

          if (_session.isEditing)
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
              onPressed: () => setState(() => _session.isEditing = true),
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
          _session.titleController.text.isEmpty
              ? '无题'
              : _session.titleController.text,
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
            Text(_session.dateString, style: _metaStyle(secondaryColor)),
            _metaSeparator(secondaryColor),
            Text(
              _session.weather.name.toUpperCase(),
              style: _metaStyle(secondaryColor),
            ),
            _metaSeparator(secondaryColor),
            Text(
              _session.mood.name.toUpperCase(),
              style: _metaStyle(secondaryColor),
            ),
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
        if (_session.isEditing)
          TextField(
            controller: _session.titleController,
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
            _session.titleController.text.isEmpty
                ? '无题'
                : _session.titleController.text,
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
                  initialDate = DateTime.parse(_session.dateString);
                } catch (_) {
                  initialDate = DateTime.now();
                }

                showDialog(
                  context: context,
                  builder: (ctx) => SkeuomorphicDatePicker(
                    initialDate: initialDate,
                    onDateSelected: (date) {
                      setState(() {
                        _session.dateString = date.toString().split(
                          ' ',
                        )[0]; // yyyy-MM-dd
                      });
                    },
                  ),
                );
              },
              child: Text(
                _session.dateString,
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
    final bool hideLines = Provider.of<SettingsProvider>(
      context,
    ).compatibilityMode;

    final tc = AppTheme.getEditorTheme(theme);
    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
        lineColor: hideLines ? Colors.transparent : tc['lineColor'],
        lineHeight: lineHeight,
      ),
      child: Container(
        padding: const EdgeInsets.only(top: 0), // Adjust if needed
        constraints: const BoxConstraints(minHeight: 300),
        child: _session.isEditing
            ? TextField(
                controller: _isPreviewMode
                    ? _session.previewController
                    : _session.contentController, // Fix 1
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
                    ? _session.previewController.text
                    : _session
                          .contentController
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
    if (!_session.isEditing) {
      return Text(
        _session.weather.name.toUpperCase(),
        style: _metaStyle(color),
      );
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final tc = AppTheme.getEditorTheme(theme);

    // Dropdown Menu Style
    final Color dropdownBg = tc['dropdownBg'];
    final Color dropdownText = tc['dropdownText'];

    return DropdownButton<WeatherType>(
      value: _session.weather,
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
      items: WeatherType.values
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
        if (val != null) setState(() => _session.weather = val);
      },
    );
  }

  Widget _buildMoodSelector(Color color) {
    if (!_session.isEditing) {
      return Text(_session.mood.name.toUpperCase(), style: _metaStyle(color));
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final tc = AppTheme.getEditorTheme(theme);

    final Color menuBg = tc['dropdownBg'];
    final Color menuText = tc['dropdownText'];

    return PopupMenuButton<MoodType>(
      initialValue: _session.mood,
      color: menuBg,
      padding: EdgeInsets.zero,
      tooltip: '',
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (val) => setState(() => _session.mood = val),
      itemBuilder: (context) => MoodType.values
          .map(
            (m) => PopupMenuItem(
              value: m,
              child: Text(
                m.name.toUpperCase(),
                style: GoogleFonts.courierPrime(fontSize: 14, color: menuText),
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          _session.mood.name.toUpperCase(),
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
      final String textToExport = _session.contentController.text;

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
    if (_session.isEditing) {
      return SliverToBoxAdapter(child: _buildEditorField(textColor, theme));
    } else {
      // Split content into lines for performance
      // 在预览模式下，使用截断的文本，这会生成非常少的 lines，极大提升首屏渲染性能
      final text = _isPreviewMode
          ? _session.previewController.text
          : _session.contentController.text;
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
          final bool hideLines = Provider.of<SettingsProvider>(
            context,
          ).compatibilityMode;

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
                    _session.isEditing = true;
                  });
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (!context.mounted) return;
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
    final bool hideLines = Provider.of<SettingsProvider>(
      context,
    ).compatibilityMode;

    final tc = AppTheme.getEditorTheme(theme);
    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
        lineColor: hideLines ? Colors.transparent : tc['lineColor'],
        lineHeight: lineHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: TextField(
          controller: _isPreviewMode
              ? _session.previewController
              : _session.contentController, // 预览模式使用截断文本
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

    final String textToExport = _session.contentController.text;

    final List<String> lines = textToExport.split('\n');
    if (lines.isEmpty) lines.add('');

    const int linesPerChunk = 40;

    for (int i = 0; i < lines.length; i += linesPerChunk) {
      int end = (i + linesPerChunk < lines.length)
          ? i + linesPerChunk
          : lines.length;
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
    final bool hideLines = Provider.of<SettingsProvider>(
      context,
    ).compatibilityMode;
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
    final paint = Paint()
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
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        4,
      ); // Lighter shadow for export
    canvas.drawPath(ribbonPath, shadowPaint);
    canvas.restore();

    // Body
    final ribbonPaint = Paint()
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
