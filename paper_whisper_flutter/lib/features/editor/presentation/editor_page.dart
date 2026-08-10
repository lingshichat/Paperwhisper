import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_ui_coordinator.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/providers/diary_provider.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/services/draft_service.dart';
import 'package:paper_whisper_flutter/shared/widgets/export_success_dialog.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_dialog.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_toast.dart';

import '../application/editor_save_coordinator.dart';
import '../application/editor_session_controller.dart';
import '../data/diary_export_service.dart';
import 'widgets/editor_body.dart';
import 'widgets/editor_export_surface.dart';
import 'widgets/editor_top_bar.dart';

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
                  AppRoutes.editor(
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
                  EditorTopBar(
                    theme: theme,
                    isEditing: _session.isEditing,
                    showDelete: widget.entry != null,
                    onBack: () async {
                      if (await _onWillPop()) {
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    onSave: _save,
                    onDelete: _delete,
                    onExport: _captureAndSave,
                    onEditToggle: () =>
                        setState(() => _session.isEditing = true),
                  ),

                  Expanded(
                    child: EditorBody(
                      titleController: _session.titleController,
                      contentController: _session.contentController,
                      previewController: _session.previewController,
                      isEditing: _session.isEditing,
                      isPreviewMode: _isPreviewMode,
                      focusNode: _focusNode,
                      theme: theme,
                      textColor: textColor,
                      secondaryColor: secondaryColor,
                      hideLines: Provider.of<SettingsProvider>(
                        context,
                      ).compatibilityMode,
                      dateString: _session.dateString,
                      weather: _session.weather,
                      mood: _session.mood,
                      onDateChanged: (date) => setState(() {
                        _session.dateString = date.toString().split(
                          ' ',
                        )[0]; // yyyy-MM-dd
                      }),
                      onWeatherChanged: (val) =>
                          setState(() => _session.weather = val),
                      onMoodChanged: (val) =>
                          setState(() => _session.mood = val),
                      onTapToEdit: () {
                        setState(() => _session.isEditing = true);
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (!context.mounted) return;
                          FocusScope.of(context).requestFocus(_focusNode);
                        });
                      },
                    ),
                  ),
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
                        child: EditorExportSurface(
                          repaintKeys: _exportKeys,
                          plan: _exportPlan,
                          theme: theme,
                          textColor: textColor,
                          secondaryColor: secondaryColor,
                          title: _session.titleController.text,
                          dateString: _session.dateString,
                          weather: _session.weather,
                          mood: _session.mood,
                          hideLines: Provider.of<SettingsProvider>(
                            context,
                          ).compatibilityMode,
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

  // Export Logic
  // 导出服务：分块计划、捕获编排、拼接与写入（context-free）
  final DiaryExportService _exportService = const DiaryExportService();
  // 当前导出计划（_isCaptureMode 期间由 _captureAndSave 生成）
  DiaryExportChunkPlan? _exportPlan;
  // 导出分块捕获 key（展示层持有，供 RepaintBoundary 查找）
  List<GlobalKey> _exportKeys = [];

  Future<void> _captureAndSave() async {
    try {
      // 1. 分块计划与捕获 key（展示层负责 RepaintBoundary 查找）
      final DiaryExportChunkPlan plan = _exportService.buildChunkPlan(
        _session.contentController.text,
      );
      _exportPlan = plan;
      _exportKeys = List.generate(plan.totalChunks, (_) => GlobalKey());

      setState(() => _isCaptureMode = true);

      // 2. 预加载导出字体（避免捕获时字体 pending 截断）
      await GoogleFonts.pendingFonts([
        GoogleFonts.notoSerifSc(),
        GoogleFonts.courierPrime(),
      ]);

      // 3. 等待导出视图完成布局
      await Future.delayed(const Duration(milliseconds: 800));

      // 4. 捕获、拼接、编码、路径解析与文件写入由导出服务完成
      final DiaryExportResult result = await _exportService.export(
        plan: plan,
        baseName: widget.entry?.filename ?? 'new',
        capture: _captureExportChunk,
      );

      if (mounted) {
        await showExportSuccessDialog(context, result.filePath);
      }
    } catch (e) {
      debugPrint("Export error: $e");
      if (mounted) {
        SkeuomorphicToast.error(context, '导出失败: $e');
      }
    } finally {
      // 无论捕获/写入成功与否，都恢复临时导出 UI 状态并释放本次分块文本
      if (mounted) {
        setState(() {
          _isCaptureMode = false;
          _exportPlan = null;
        });
      }
    }
  }

  /// 捕获指定分块：查找 RepaintBoundary 并转 ui.Image（不可捕获返回 null）。
  Future<ui.Image?> _captureExportChunk(
    int chunkIndex,
    double pixelRatio,
  ) async {
    if (chunkIndex >= _exportKeys.length) return null;
    final RenderRepaintBoundary? boundary =
        _exportKeys[chunkIndex].currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return boundary.toImage(pixelRatio: pixelRatio);
  }
}
