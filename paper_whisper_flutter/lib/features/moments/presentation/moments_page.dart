import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_index.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_send_pipeline.dart';
import 'package:paper_whisper_flutter/features/moments/application/moments_timeline_controller.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_ui_coordinator.dart';
import 'package:paper_whisper_flutter/features/update/application/update_check_coordinator.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_provider.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/features/premium/data/payment_service.dart';
import 'package:paper_whisper_flutter/app/shell/sidebar_widget.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_dialog.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_search_bar.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_toast.dart';
import 'package:paper_whisper_flutter/features/update/presentation/update_dialog.dart';

import 'widgets/moment_card.dart';
import 'widgets/moment_input_widget.dart';
import 'widgets/moments_desktop_header.dart';
import 'widgets/moments_empty_state.dart';
import 'widgets/moments_limit_banner.dart';
import 'widgets/moments_search_results.dart';
import 'widgets/moments_waterfall.dart';
import 'widgets/ruler_date_picker.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  // 共享 MomentService（composition root 注入），避免页面维护写
  // Manifest 的独立实例。
  late final MomentService _momentService;
  late final MomentsTimelineController _timeline;
  MomentIndex _index = MomentIndex.build(const []);
  String _cachedSearchQuery = '';
  int _momentsRevision = 0;
  int _cachedSearchRevision = -1;
  List<Moment> _cachedFilteredMoments = const [];
  Directory? _baseDir;

  // Search State
  bool _isSearching = false;

  // Focus Management
  final FocusNode _inputFocusNode = FocusNode();

  // Dynamic Input Height
  double _inputHeight = 80.0;

  @override
  void initState() {
    super.initState();
    _momentService = context.read<MomentService>();
    _timeline = MomentsTimelineController();
    _loadData();

    // Listen to focus changes to rebuild UI (toggle dismiss layer)
    _inputFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    // Check for updates once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
    });
  }

  // 自动检查委托 context-free 的 UpdateCheckCoordinator（purpose 级
  // 会话去重：成功一次后本进程不再重复，失败回滚可重试）；保留原 2s
  // 延迟与静默失败语义，available 才弹 UpdateDialog。延迟留在页面，
  // 延迟后先检查 mounted 再发起网络请求（不持页面生命周期闭包进协调器）。
  final UpdateCheckCoordinator _updateCheckCoordinator =
      UpdateCheckCoordinator();

  Future<void> _checkUpdate() async {
    // 保留原时序：先延迟 2s 不阻塞首帧渲染，延迟后先检查 mounted
    // 再发起网络请求（页面销毁时不再白费一次请求）。
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final outcome = await _updateCheckCoordinator.checkAuto(purpose: 'moments');
    if (!mounted) return;
    switch (outcome) {
      case UpdateCheckAvailable(:final info, :final currentVersion):
        UpdateDialog.show(
          context,
          updateInfo: info,
          currentVersion: currentVersion,
        );
      case UpdateCheckUpToDate():
      case UpdateCheckFailure():
      case UpdateCheckSkipped():
        break; // 自动检查静默
    }
  }

  @override
  void dispose() {
    _timeline.dispose();
    _inputFocusNode.dispose(); // Dispose focus node
    super.dispose();
  }

  List<Moment> _getFilteredMoments(String query) {
    if (query.isEmpty) return const [];

    if (_cachedSearchQuery == query &&
        _cachedSearchRevision == _momentsRevision) {
      return _cachedFilteredMoments;
    }

    final filteredMoments = _index.latestMoments
        .where((moment) => moment.content.contains(query))
        .toList(growable: false);

    _cachedSearchQuery = query;
    _cachedSearchRevision = _momentsRevision;
    _cachedFilteredMoments = filteredMoments;
    return filteredMoments;
  }

  void _onDateChanged(DateTime date, {bool animate = true}) {
    if (_timeline.isSameDay(date, _timeline.selectedDate)) return;

    setState(() {
      _timeline.selectDate(date);
    });

    // If caused by explicit selection (e.g. tap on ruler item not implemented yet but if any), sync page
    if (animate) {
      int index = _timeline.indexForDate(date);
      if (_timeline.pageController.hasClients &&
          _timeline.pageController.page?.round() != index) {
        _timeline.pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      // Ruler auto-syncs via page listener? No, need to sync ruler too if page doesn't move ruler during animation?
      // Page animation will trigger scroll update, which syncs ruler. So just moving page is enough.
    }
  }

  /// 跳转赞助页（额度弹窗与额度提示条共用）。
  void _openPremiumMembership() {
    Navigator.push(context, AppRoutes.premium());
  }

  Future<void> _handleSend(
    String content,
    List<XFile> images, {
    String? audioPath,
    String? audioTitle,
    int? audioDuration,
  }) async {
    // 发送管线 context-free：额度 → 图片/audio 落盘 → Moment 保存，
    // 返回 typed 结果；失败不清输入且不产生未处理异步错误。
    final pipeline = MomentSendPipeline(
      momentService: _momentService,
      canUseProFeatures: () => context.read<PaymentService>().canUseProFeatures,
      todayMomentCount: () => _index.momentsForDate(DateTime.now()).length,
    );
    final result = await pipeline.send(
      content: content,
      images: [for (final img in images) File(img.path)],
      audioPath: audioPath,
      audioTitle: audioTitle,
      audioDuration: audioDuration,
    );
    if (!mounted) return;

    switch (result) {
      case MomentSendQuotaExceeded():
        // 免费额度弹窗（原「今日额度已用完」对话框）
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => SkeuomorphicDialog(
            title: '今日额度已用完',
            headerIcon: Icons.lock_outline,
            content: const Text('免费版每日 3 条随心记。赞助后解锁无限创作、WebDAV 同步与更多能力。'),
            actions: [
              SkeuomorphicDialogButton(
                label: '取消',
                isPrimary: false,
                onPressed: () => Navigator.pop(ctx, false),
              ),
              SkeuomorphicDialogButton(
                label: '去赞助',
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        );
        if (go == true && mounted) {
          _openPremiumMembership();
        }
      case MomentSendSuccess():
        await _loadData(); // visual refresh
        if (!mounted) return;
        final syncProvider = context.read<SyncProvider>();
        // 保存后自动同步决策与即时 pending 提示统一由 SyncUiCoordinator
        // 处理（内部消费 context-free 的 SaveSyncCoordinator 决策）。
        await SyncUiCoordinator(context).handleSaveAutoSync(
          provider: syncProvider,
          savedToast: '记录已保存',
          preparingToast: '记录已保存，准备同步...',
          preparingToastAsInfo: true,
        );
      case MomentSendFailure():
        // typed 失败反馈：不再成为未处理异步错误，仅提示 Toast。
        // 输入清空由 MomentInputWidget 在触发发送后同步完成（重构前行为），
        // 与成败无关，此处不处理输入状态。
        SkeuomorphicToast.error(context, '发送失败，请稍后重试');
    }
  }

  Future<void> _handleAggregation() async {
    // Show Dialog
    String title = "今日份的日记";
    String inputVal = "";

    // Prepare theme-aware colors
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final dialogTheme = ThemeRegistry.get(theme).dialogInput;
    final inputBg = dialogTheme.backgroundColor;
    final inputBorder = dialogTheme.borderColor;
    final hintColor = dialogTheme.hintColor;
    final textColor = dialogTheme.textColor;
    final descColor = dialogTheme.descriptionColor;

    String? result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SkeuomorphicDialog(
          title: '生成长文日记',
          headerIcon: Icons.auto_awesome, // Magic icon
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将今天的记录汇聚成篇，存入专注书写模块。',
                style: GoogleFonts.notoSerifSc(fontSize: 14, color: descColor),
              ),
              const SizedBox(height: 20),

              // Skeuomorphic Input Field (Simple version)
              Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  border: Border(
                    bottom: BorderSide(color: inputBorder, width: 2),
                  ),
                ),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '为日记起个名字',
                    hintText: '默认: 今日份的日记',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    labelStyle: GoogleFonts.notoSerifSc(color: hintColor),
                    hintStyle: GoogleFonts.notoSerifSc(
                      color: hintColor.withValues(alpha: 0.5),
                    ),
                  ),
                  style: GoogleFonts.notoSerifSc(color: textColor),
                  onChanged: (v) => inputVal = v,
                ),
              ),
            ],
          ),
          actions: [
            SkeuomorphicDialogButton(
              label: '取消',
              isPrimary: false,
              onPressed: () => Navigator.pop(ctx),
            ),
            SkeuomorphicDialogButton(
              label: '生成',
              isPrimary: true,
              onPressed: () =>
                  Navigator.pop(ctx, inputVal.isEmpty ? title : inputVal),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await _momentService.exportDailySummary(
          _timeline.selectedDate,
          customTitle: result,
        );

        if (!mounted) return;

        final syncProvider = context.read<SyncProvider>();
        await syncProvider.refreshTrustSnapshot();
        if (!mounted) return;
        // 聚合导出后的自动同步请求（权限前置）由 SyncUiCoordinator 处理，
        // 配置门禁消费 SaveSyncCoordinator.shouldAutoSync。
        await SyncUiCoordinator(
          context,
        ).requestAutoSyncIfConfigured(syncProvider);
        if (!mounted) return;
        SkeuomorphicToast.success(context, '生成成功，正在跳转...');

        // Auto navigate to Writer
        if (!mounted) return;
        Navigator.of(context).pushReplacement(AppRoutes.diaryList());
      } catch (e) {
        if (mounted) SkeuomorphicToast.error(context, '生成失败: $e');
      }
    }
  }

  Future<void> _loadData() async {
    await _momentService.init();
    final moments = await _momentService.getMoments();
    final index = MomentIndex.build(moments);
    if (mounted) {
      setState(() {
        _index = index;
        _momentsRevision++;
        _cachedSearchRevision = -1;
        _baseDir = _momentService.dataDir;
      });
    }
  }

  Future<void> _handleMomentDeleted(
    String uuid, {
    bool showToast = false,
  }) async {
    await _momentService.deleteMoment(uuid);
    await _loadData();

    if (!mounted) return;

    final syncProvider = context.read<SyncProvider>();
    await syncProvider.refreshTrustSnapshot();

    if (!mounted) return;

    if (showToast) {
      SkeuomorphicToast.success(context, '已移入回收站');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;

    // 主题颜色统一由 ThemeRegistry.get(theme).moments 管理
    final tc = ThemeRegistry.get(theme).moments;

    final Color appBarIconColor = tc.appBarIconColor;
    final Color appBarTextColor = tc.appBarTextColor;

    final Color rulerAccent = AppTheme.getAccentColor(theme);

    // Ruler Colors Configuration
    final Color rulerBg = tc.rulerBg;
    final Color rulerTextColor = tc.rulerTextColor;
    final Color rulerInactiveTextColor = tc.rulerInactiveTextColor;
    final Color rulerSubTextColor = tc.rulerSubTextColor;
    final Color rulerInactiveSubTextColor = tc.rulerInactiveSubTextColor;
    final Color rulerIndicatorColor = tc.rulerIndicatorColor;
    final Color rulerShadowColor = tc.rulerShadowColor;
    final Color rulerBorderColor = tc.rulerBorderColor;

    // Search Integration
    final String searchQuery = context.select<DiaryProvider, String>(
      (provider) => provider.momentsSearchQuery,
    );
    final bool isSearchActive = searchQuery.isNotEmpty;
    final List<Moment> filteredMoments = isSearchActive
        ? _getFilteredMoments(searchQuery)
        : const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 800;
        final canUse = context.select<PaymentService, bool>(
          (payment) => payment.canUseProFeatures,
        );
        final showLimitBanner =
            !canUse &&
            _index.momentsForDate(DateTime.now()).length >=
                MomentSendPipeline.freeDailyLimit;

        // 简化 content 结构：直接使用 SafeArea + Column，避免嵌套 Stack 导致的渲染问题
        final Widget content = SafeArea(
          top: !isDesktop,
          bottom: isDesktop,
          child: Column(
            children: [
              // On Desktop, we need a Header (replacement for AppBar)
              if (isDesktop)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MomentsDesktopHeader(
                      selectedDate: _timeline.selectedDate,
                      imageCount: _index.imageCountForDate(
                        _timeline.selectedDate,
                      ),
                      textColor: appBarTextColor,
                      iconColor: appBarIconColor,
                      onGenerate: _handleAggregation,
                    ),
                    // 恢复尺子
                    SizedBox(
                      height: 85,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            // 仅处理尺子自身的滚动，不与列表联动(因为列表是全量的)
                            // 这里主要依靠 RulerDatePicker 内部或者 controller 变动来触发 _onDateChanged
                            // 但原逻辑是靠 PageView 驱动 Ruler，或 Ruler 驱动 PageView
                            // 这里我们让 Ruler 独立工作，只改变 _selectedDate
                            return false;
                          }
                          return false;
                        },
                        child: RulerDatePicker(
                          selectedDate: _timeline.selectedDate,
                          onDateChanged: (d) =>
                              _onDateChanged(d, animate: false), // 不驱动 PageView
                          controller: _timeline.rulerController,
                          accentColor: rulerAccent,
                          backgroundColor: rulerBg,
                          textColor: rulerTextColor,
                          inactiveTextColor: rulerInactiveTextColor,
                          subTextColor: rulerSubTextColor,
                          inactiveSubTextColor: rulerInactiveSubTextColor,
                          indicatorColor: rulerIndicatorColor,
                          shadowColor: rulerShadowColor,
                          borderColor: rulerBorderColor,
                        ),
                      ),
                    ),
                  ],
                ),

              // If searching, show result list. Else show regular layout.
              if (isSearchActive)
                Expanded(
                  child: MomentsSearchResults(
                    moments: filteredMoments,
                    baseDir: _baseDir,
                    textColor: rulerTextColor,
                    bottomPadding: _inputHeight + 20,
                    onDelete: (moment) => _handleMomentDeleted(moment.uuid),
                  ),
                )
              else if (isDesktop)
                // Desktop Waterfall Layout
                Expanded(
                  child: Stack(
                    children: [
                      // Grid - 联动尺子日期
                      _index.momentsForDate(_timeline.selectedDate).isEmpty
                          ? MomentsEmptyState(
                              date: DateTime.now(),
                              theme: theme,
                            )
                          : MomentsWaterfall(
                              moments: _index.momentsForDate(
                                _timeline.selectedDate,
                              ),
                              baseDir: _baseDir,
                              onDelete: (moment) =>
                                  _handleMomentDeleted(moment.uuid),
                            ),

                      // Floating Input (Bottom Center) - 拟物化悬浮岛设计
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showLimitBanner)
                                MomentsLimitBanner(
                                  onUpgrade: _openPremiumMembership,
                                ),
                              Container(
                                width: 600,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ), // Deep shadow
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ), // Ambient shadow
                                      blurRadius: 5,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    24,
                                  ), // Rounded corners for the widget
                                  child: MomentInputWidget(onSend: _handleSend),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // Mobile Layout (Ruler + List)
                // Ruler with Sync Listener
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0 &&
                        notification is ScrollUpdateNotification) {
                      if (!_timeline.shouldProcessRulerScroll()) return false;
                      if (_timeline.pageController.hasClients &&
                          _timeline.rulerController.hasClients) {
                        double rulerOffset = _timeline.rulerController.offset;
                        double page = _timeline.pageForRulerOffset(rulerOffset);
                        double pageWidth =
                            _timeline.pageController.position.viewportDimension;
                        _timeline.pageController.jumpTo(page * pageWidth);
                      }
                    } else if (notification is ScrollEndNotification) {
                      _timeline.rulerScrollEnded();
                    }
                    return false;
                  },
                  child: RulerDatePicker(
                    selectedDate: _timeline.selectedDate,
                    onDateChanged: (d) => _onDateChanged(d),
                    controller: _timeline.rulerController,
                    accentColor: rulerAccent,
                    backgroundColor: rulerBg,
                    textColor: rulerTextColor,
                    inactiveTextColor: rulerInactiveTextColor,
                    subTextColor: rulerSubTextColor,
                    inactiveSubTextColor: rulerInactiveSubTextColor,
                    indicatorColor: rulerIndicatorColor,
                    shadowColor: rulerShadowColor,
                    borderColor: rulerBorderColor,
                  ),
                ),

                // List (PageView)
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.depth == 0 &&
                          notification is ScrollUpdateNotification) {
                        if (!_timeline.shouldProcessPageScroll()) return false;
                        if (_timeline.pageController.hasClients &&
                            _timeline.rulerController.hasClients) {
                          double page = _timeline.pageController.page ?? 0;
                          double rulerOffset = _timeline.rulerOffsetForPage(
                            page,
                          );
                          _timeline.rulerController.jumpTo(rulerOffset);
                        }
                      } else if (notification is ScrollEndNotification) {
                        _timeline.pageScrollEnded();
                        if (!_timeline.isRulerActive &&
                            _timeline.pageController.hasClients) {
                          int pageIndex =
                              _timeline.pageController.page?.round() ?? 0;
                          DateTime targetDate = _timeline.dateForIndex(
                            pageIndex,
                          );
                          if (!_timeline.isSameDay(
                            targetDate,
                            _timeline.selectedDate,
                          )) {
                            _onDateChanged(targetDate, animate: false);
                          }
                        }
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _timeline.pageController,
                      itemCount: MomentsTimelineController.dayRange,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) {
                        // Optional: Could trigger haptic feedback here
                      },
                      itemBuilder: (context, index) {
                        DateTime date = _timeline.dateForIndex(index);
                        List<Moment> moments = _index.momentsForDate(date);

                        if (moments.isEmpty) {
                          return MomentsEmptyState(date: date, theme: theme);
                        }

                        return ListView.builder(
                          padding: EdgeInsets.only(
                            top: 20,
                            bottom: _inputHeight + 20,
                          ),
                          itemCount: moments.length,
                          itemBuilder: (context, i) {
                            return MomentCard(
                              moment: moments[i],
                              baseDir: _baseDir,
                              onDelete: () async {
                                await _handleMomentDeleted(
                                  moments[i].uuid,
                                  showToast: true,
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // 1. Background
                Container(decoration: AppTheme.getBackground(theme)),

                // 2. Visual Effects
                ...AppTheme.getBackgroundOverlays(theme),

                // 3. Main Layout
                Row(
                  children: [
                    const SizedBox(
                      width: 300,
                      child: SidebarWidget(
                        activeSection: SidebarSection.moments,
                      ),
                    ),
                    Expanded(child: content),
                  ],
                ),
              ],
            ),
          );
        }

        // Mobile Header Logic
        Widget headerTitle;
        if (_isSearching) {
          headerTitle = SkeuomorphicSearchBar(
            value: searchQuery,
            onChanged: (val) =>
                context.read<DiaryProvider>().setMomentsSearchQuery(val),
            autoFocus: true,
          );
        } else {
          final imageCount = _index.imageCountForDate(_timeline.selectedDate);
          headerTitle = Column(
            children: [
              Text(
                "${_timeline.selectedDate.year}年${_timeline.selectedDate.month}月",
                style: GoogleFonts.notoSerifSc(
                  color: appBarTextColor.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "随心记",
                    style: GoogleFonts.notoSerifSc(
                      color: appBarTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (imageCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: appBarIconColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, size: 10, color: appBarIconColor),
                          const SizedBox(width: 2),
                          Text(
                            '$imageCount',
                            style: GoogleFonts.notoSerifSc(
                              color: appBarIconColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          drawerScrimColor: tc.drawerScrimColor, // 统一遮罩逻辑
          drawer: const Drawer(
            width: 300,
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: SidebarWidget(activeSection: SidebarSection.moments),
          ),
          appBar: AppBar(
            backgroundColor: tc.appBarBg,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            scrolledUnderElevation: 0,
            systemOverlayStyle: AppTheme.getSystemUiOverlayStyle(theme),
            // 关闭横向滚动触发的 AppBar “scrolled under” 状态，保持首帧与切页后颜色一致
            notificationPredicate: (_) => false,
            leading: Builder(
              builder: (context) {
                if (_isSearching) {
                  return IconButton(
                    icon: Icon(Icons.arrow_back, color: appBarIconColor),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                      });
                      context.read<DiaryProvider>().setMomentsSearchQuery('');
                    },
                  );
                }
                return IconButton(
                  icon: Icon(Icons.menu, color: appBarIconColor),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                );
              },
            ),
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: headerTitle,
            ),
            centerTitle: true,
            actions: [
              if (!_isSearching)
                IconButton(
                  icon: Icon(Icons.search, color: appBarIconColor),
                  onPressed: () => setState(() => _isSearching = true),
                ),

              if (!_isSearching)
                IconButton(
                  key: const ValueKey('mobile_generate_btn'),
                  icon: Icon(
                    Icons.description_outlined,
                    color: appBarIconColor,
                  ),
                  tooltip: '生成今日日记',
                  onPressed: _handleAggregation,
                ),
            ],
          ),
          body: Builder(
            builder: (bodyContext) {
              final bottomInset = MediaQuery.of(bodyContext).viewInsets.bottom;
              final isKeyboardOpen = bottomInset > 0;

              return Stack(
                children: [
                  // 0. Background
                  Positioned.fill(
                    child: Container(decoration: AppTheme.getBackground(theme)),
                  ),

                  // 0.5. Visual Effects
                  ...AppTheme.getBackgroundOverlays(theme),

                  // 1. Main Content
                  // Use AnimatedPositioned for smooth resizing content area
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: isKeyboardOpen ? bottomInset : 0,
                    child: content,
                  ),

                  // 2. Dismiss Layer
                  if (isKeyboardOpen || _inputFocusNode.hasFocus)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _inputFocusNode.unfocus();
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                  // 3. Input Widget
                  // Use AnimatedPositioned to smooth out the jump if ViewInsets updates late
                  if (!isSearchActive)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      left: 0,
                      right: 0,
                      bottom: bottomInset, // Will animate to this target
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showLimitBanner)
                            MomentsLimitBanner(
                              onUpgrade: _openPremiumMembership,
                            ),
                          MomentInputWidget(
                            onSend: _handleSend,
                            focusNode: _inputFocusNode,
                            onHeightChanged: (h) {
                              if ((_inputHeight - h).abs() > 1) {
                                // Debounce/Throttling check
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) setState(() => _inputHeight = h);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
