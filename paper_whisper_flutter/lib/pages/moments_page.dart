import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/moment.dart';
import '../services/moment_service.dart';
import '../widgets/moment_card.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/ruler_date_picker.dart';
import '../widgets/moment_input_widget.dart';
import '../pages/diary_list_page.dart';
import '../providers/settings_provider.dart'; // Added
import '../providers/sync_provider.dart'; // Added
import '../config/app_theme.dart'; // Added
import '../widgets/skeuomorphic_toast.dart'; // Added
import '../features/sync/presentation/sync_ui_coordinator.dart';
import '../widgets/skeuomorphic_dialog.dart'; // Added

import '../providers/diary_provider.dart'; // Added
import '../widgets/skeuomorphic_search_bar.dart'; // Added
import '../services/payment_service.dart';
import '../pages/premium_membership_page.dart';
import '../widgets/slide_page_route.dart';
import '../services/update_service.dart'; // Added
import '../widgets/update_dialog.dart'; // Added

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  // 共享 MomentService（composition root 注入），避免页面维护写
  // Manifest 的独立实例。
  late final MomentService _momentService;
  List<Moment> _latestMoments = [];
  Map<String, List<Moment>> _momentsByDay = {};
  Map<String, int> _imageCountByDay = {};
  String _cachedSearchQuery = '';
  int _momentsRevision = 0;
  int _cachedSearchRevision = -1;
  List<Moment> _cachedFilteredMoments = const [];
  Directory? _baseDir;
  DateTime _selectedDate = DateTime.now();

  late PageController _pageController;
  late FixedExtentScrollController _rulerController;

  final int _dayRange = 3650;
  late DateTime _startDate;

  // Flags to prevent circular sync
  bool _isRulerActive = false;
  bool _isPageActive = false;

  // Search State
  bool _isSearching = false;

  // Focus Management
  final FocusNode _inputFocusNode = FocusNode();

  // Dynamic Input Height
  double _inputHeight = 80.0;

  // Static flag to ensure update check only happens once per app session
  static bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    _momentService = context.read<MomentService>();
    _initDates();
    _initControllers();
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

  Future<void> _checkUpdate() async {
    if (_hasCheckedUpdate) return;
    _hasCheckedUpdate = true;

    try {
      final updateService = UpdateService();
      // Add a small delay to not block UI rendering immediately
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final info = await updateService.checkForUpdate();
      if (info != null && mounted) {
        final currentVersion = await updateService.getCurrentVersion();
        if (mounted) {
          UpdateDialog.show(
            context,
            updateInfo: info,
            currentVersion: currentVersion,
          );
        }
      }
    } catch (e) {
      debugPrint('自动更新检查失败: $e');
    }
  }

  void _initDates() {
    // Same normalization logic as Ruler
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 365 * 5));

    // Initial Index
    final selectedNormalized = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    int initialIndex = selectedNormalized.difference(_startDate).inDays;
    if (initialIndex < 0) initialIndex = 0;

    _pageController = PageController(initialPage: initialIndex);
    _rulerController = FixedExtentScrollController(initialItem: initialIndex);
  }

  void _initControllers() {
    // Sync Ruler -> Page (When user scrolls ruler)
    // Note: ListWheelScrollView physics might fight if we jump too often?
    // Let's us notification listener on Ruler side or just listener on controller?
    // Controller listener doesn't tell us source.
    // RulerDatePicker exposes controller. We need to wrap RulerDatePicker in NotificationListener
    // to detect if user is touching it.

    // Actually simpler: In build method, wrap RulerDatePicker with NotificationListener.
  }

  @override
  void dispose() {
    _pageController.dispose();
    _rulerController.dispose();
    _inputFocusNode.dispose(); // Dispose focus node
    super.dispose();
  }

  String _dayKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  _MomentLookupCache _buildMomentLookupCache(List<Moment> moments) {
    final latestMoments = List<Moment>.from(moments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final momentsByDay = <String, List<Moment>>{};
    final imageCountByDay = <String, int>{};

    for (final moment in moments) {
      final key = _dayKey(moment.createdAt);
      momentsByDay.putIfAbsent(key, () => <Moment>[]).add(moment);
      imageCountByDay[key] = (imageCountByDay[key] ?? 0) + moment.images.length;
    }

    for (final dailyMoments in momentsByDay.values) {
      dailyMoments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return _MomentLookupCache(
      latestMoments: latestMoments,
      momentsByDay: momentsByDay,
      imageCountByDay: imageCountByDay,
    );
  }

  List<Moment> _getMomentsForDate(DateTime date) {
    return _momentsByDay[_dayKey(date)] ?? const [];
  }

  // 计算指定日期随心记中的图片总数
  int _getImageCountForDate(DateTime date) {
    return _imageCountByDay[_dayKey(date)] ?? 0;
  }

  List<Moment> _getFilteredMoments(String query) {
    if (query.isEmpty) return const [];

    if (_cachedSearchQuery == query &&
        _cachedSearchRevision == _momentsRevision) {
      return _cachedFilteredMoments;
    }

    final filteredMoments = _latestMoments
        .where((moment) => moment.content.contains(query))
        .toList(growable: false);

    _cachedSearchQuery = query;
    _cachedSearchRevision = _momentsRevision;
    _cachedFilteredMoments = filteredMoments;
    return filteredMoments;
  }

  void _onDateChanged(DateTime date, {bool animate = true}) {
    if (_isSameDay(date, _selectedDate)) return;

    setState(() {
      _selectedDate = date;
    });

    // If caused by explicit selection (e.g. tap on ruler item not implemented yet but if any), sync page
    if (animate) {
      int index = date.difference(_startDate).inDays;
      if (_pageController.hasClients &&
          _pageController.page?.round() != index) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      // Ruler auto-syncs via page listener? No, need to sync ruler too if page doesn't move ruler during animation?
      // Page animation will trigger scroll update, which syncs ruler. So just moving page is enough.
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _handleSend(
    String content,
    List<XFile> images, {
    String? audioPath,
    String? audioTitle,
    int? audioDuration,
  }) async {
    // 会员 / 试用：免费用户当日限 3 条
    final pay = Provider.of<PaymentService>(context, listen: false);
    if (!pay.canUseProFeatures) {
      final todayCount = _getMomentsForDate(DateTime.now()).length;
      if (todayCount >= 3) {
        if (!mounted) return;
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
          Navigator.push(
            context,
            SlidePageRoute(page: const PremiumMembershipPage()),
          );
        }
        return;
      }
    }

    // 1. Save images
    List<String> savedPaths = [];
    for (var img in images) {
      String path = await _momentService.saveImage(File(img.path));
      savedPaths.add(path);
    }

    // 2. Save Audio
    String? savedAudioPath;
    if (audioPath != null) {
      try {
        savedAudioPath = await _momentService.saveAudio(audioPath);
      } catch (e) {
        debugPrint("Error saving audio: $e");
      }
    }

    // 3. Create Moment
    // ...

    Moment newMoment = Moment.create(
      content: content,
      images: savedPaths,
      audioPath: savedAudioPath,
      audioTitle: audioTitle,
      audioDuration: audioDuration,
      // Default weather/mood for quick input? Or random? Or none.
    );
    // Adjust timestamp
    // Moment.create uses DateTime.now(). We should probably allow overriding.
    // Since Moment.create doesn't support custom date in my previous impl, check model.
    // If model has only 'create' factory, I might need to edit it manually or just let it be Now.
    // Let's stick to "Now" for simplicity, or if Moment model allows, set createdAt.
    // Checking previous context... Moment model has createdAt final.
    // I can't easily change it without refactoring Moment.
    // But since it's "Suixinji" (Spontaneous), "Now" makes sense.
    // If user is viewing yesterday and types, does it go to yesterday?
    // Flomo usually acts as Inbox, always Now.
    // BUT user wants typical journal backdating often.
    // Let's assume "Now" for this iteration to match Flomo behavior unless specified.

    await _momentService.saveMoment(newMoment);
    await _loadData(); // visual refresh

    if (mounted) {
      final syncProvider = context.read<SyncProvider>();
      // 保存后自动同步决策与即时 pending 提示统一由 SyncUiCoordinator 处理。
      await SyncUiCoordinator(context).handleSaveAutoSync(
        provider: syncProvider,
        savedToast: '记录已保存',
        preparingToast: '记录已保存，准备同步...',
        preparingToastAsInfo: true,
      );
    }
  }

  Future<void> _handleAggregation() async {
    // Show Dialog
    String title = "今日份的日记";
    String inputVal = "";

    // Prepare theme-aware colors
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final dialogTheme = AppTheme.getDialogInputTheme(theme);
    final inputBg = dialogTheme['backgroundColor']!;
    final inputBorder = dialogTheme['borderColor']!;
    final hintColor = dialogTheme['hintColor']!;
    final textColor = dialogTheme['textColor']!;
    final descColor = dialogTheme['descriptionColor']!;

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
          _selectedDate,
          customTitle: result,
        );

        if (!mounted) return;

        final syncProvider = context.read<SyncProvider>();
        await syncProvider.refreshTrustSnapshot();
        if (!mounted) return;
        // 聚合导出后的自动同步请求（权限前置）由 SyncUiCoordinator 处理。
        await SyncUiCoordinator(
          context,
        ).requestAutoSyncIfConfigured(syncProvider);
        if (!mounted) return;
        SkeuomorphicToast.success(context, '生成成功，正在跳转...');

        // Auto navigate to Writer
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const DiaryListPage(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, a, _, c) =>
                FadeTransition(opacity: a, child: c),
          ),
        );
      } catch (e) {
        if (mounted) SkeuomorphicToast.error(context, '生成失败: $e');
      }
    }
  }

  Future<void> _loadData() async {
    await _momentService.init();
    final moments = await _momentService.getMoments();
    final lookupCache = _buildMomentLookupCache(moments);
    if (mounted) {
      setState(() {
        _latestMoments = lookupCache.latestMoments;
        _momentsByDay = lookupCache.momentsByDay;
        _imageCountByDay = lookupCache.imageCountByDay;
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

    // 主题颜色统一由 AppTheme.getMomentsTheme 管理
    final tc = AppTheme.getMomentsTheme(theme);

    final Color appBarIconColor = tc['appBarIconColor'];
    final Color appBarTextColor = tc['appBarTextColor'];

    final Color rulerAccent = AppTheme.getAccentColor(theme);

    // Ruler Colors Configuration
    final Color? rulerBg = tc['rulerBg'];
    final Color? rulerTextColor = tc['rulerTextColor'];
    final Color? rulerInactiveTextColor = tc['rulerInactiveTextColor'];
    final Color? rulerSubTextColor = tc['rulerSubTextColor'];
    final Color? rulerInactiveSubTextColor = tc['rulerInactiveSubTextColor'];
    final Color? rulerIndicatorColor = tc['rulerIndicatorColor'];
    final Color? rulerShadowColor = tc['rulerShadowColor'];
    final Color? rulerBorderColor = tc['rulerBorderColor'];

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
            !canUse && _getMomentsForDate(DateTime.now()).length >= 3;

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
                    _buildDesktopHeader(appBarTextColor, appBarIconColor),
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
                          selectedDate: _selectedDate,
                          onDateChanged: (d) =>
                              _onDateChanged(d, animate: false), // 不驱动 PageView
                          controller: _rulerController,
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
                  child: _buildSearchResults(
                    filteredMoments,
                    textColor: rulerTextColor,
                  ),
                )
              else if (isDesktop)
                // Desktop Waterfall Layout
                Expanded(
                  child: Stack(
                    children: [
                      // Grid - 联动尺子日期
                      _buildDesktopWaterfall(
                        context,
                        _getMomentsForDate(_selectedDate),
                      ),

                      // Floating Input (Bottom Center) - 拟物化悬浮岛设计
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showLimitBanner) _buildLimitBanner(context),
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
                      if (_isPageActive) return false;
                      _isRulerActive = true;

                      if (_pageController.hasClients &&
                          _rulerController.hasClients) {
                        double rulerOffset = _rulerController.offset;
                        double page = rulerOffset / 70.0;
                        double pageWidth =
                            _pageController.position.viewportDimension;
                        _pageController.jumpTo(page * pageWidth);
                      }
                    } else if (notification is ScrollEndNotification) {
                      _isRulerActive = false;
                    }
                    return false;
                  },
                  child: RulerDatePicker(
                    selectedDate: _selectedDate,
                    onDateChanged: (d) => _onDateChanged(d),
                    controller: _rulerController,
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
                        if (_isRulerActive) return false;
                        _isPageActive = true;

                        if (_pageController.hasClients &&
                            _rulerController.hasClients) {
                          double page = _pageController.page ?? 0;
                          double rulerOffset = page * 70.0;
                          _rulerController.jumpTo(rulerOffset);
                        }
                      } else if (notification is ScrollEndNotification) {
                        _isPageActive = false;
                        if (!_isRulerActive && _pageController.hasClients) {
                          int pageIndex = _pageController.page?.round() ?? 0;
                          DateTime targetDate = _startDate.add(
                            Duration(days: pageIndex),
                          );
                          if (!_isSameDay(targetDate, _selectedDate)) {
                            _onDateChanged(targetDate, animate: false);
                          }
                        }
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _dayRange,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (index) {
                        // Optional: Could trigger haptic feedback here
                      },
                      itemBuilder: (context, index) {
                        DateTime date = _startDate.add(Duration(days: index));
                        List<Moment> moments = _getMomentsForDate(date);

                        if (moments.isEmpty) {
                          return _buildEmptyStateForDate(date);
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
          final imageCount = _getImageCountForDate(_selectedDate);
          headerTitle = Column(
            children: [
              Text(
                "${_selectedDate.year}年${_selectedDate.month}月",
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
          drawerScrimColor: tc['drawerScrimColor'], // 统一遮罩逻辑
          drawer: const Drawer(
            width: 300,
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: SidebarWidget(activeSection: SidebarSection.moments),
          ),
          appBar: AppBar(
            backgroundColor: tc['appBarBg'],
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
                          if (showLimitBanner) _buildLimitBanner(bodyContext),
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

  Widget _buildLimitBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8D6E63).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5D4037)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '今日随心记已用完 (3/3)，赞助后解锁无限创作',
              style: GoogleFonts.notoSerifSc(color: Colors.white, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              SlidePageRoute(page: const PremiumMembershipPage()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '去赞助',
                style: GoogleFonts.notoSerifSc(
                  color: const Color(0xFFFFE0B2),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Moment> filteredMoments, {Color? textColor}) {
    // 使用透明容器，确保背景可以穿透显示
    return Container(
      color: Colors.transparent, // 透明背景
      child: filteredMoments.isEmpty
          ? Center(
              child: Opacity(
                opacity: 0.7,
                child: Text(
                  '没有找到相关记忆...',
                  style: GoogleFonts.notoSerifSc(
                    color: textColor?.withValues(alpha: 0.7) ?? Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(top: 20, bottom: _inputHeight + 20),
              itemCount: filteredMoments.length,
              itemBuilder: (context, i) {
                return MomentCard(
                  moment: filteredMoments[i],
                  baseDir: _baseDir,
                  onDelete: () async {
                    await _handleMomentDeleted(filteredMoments[i].uuid);
                  },
                );
              },
            ),
    );
  }

  Widget _buildDesktopHeader(Color textColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // Subtle bg for header
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Leading (empty or back?) - No drawer icon needed
          const SizedBox(
            width: 48,
          ), // Spacer to center title if needed, or just let it adjust

          Expanded(
            child: Column(
              children: [
                Text(
                  "${_selectedDate.year}年${_selectedDate.month}月",
                  style: GoogleFonts.notoSerifSc(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final imageCount = _getImageCountForDate(_selectedDate);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "随心记",
                          style: GoogleFonts.notoSerifSc(
                            color: textColor,
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
                              color: iconColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.image, size: 10, color: iconColor),
                                const SizedBox(width: 2),
                                Text(
                                  '$imageCount',
                                  style: GoogleFonts.notoSerifSc(
                                    color: iconColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          IconButton(
            key: const ValueKey('desktop_generate_btn'),
            icon: Icon(Icons.description_outlined, color: iconColor),
            tooltip: '生成今日日记',
            onPressed: _handleAggregation,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateForDate(DateTime date) {
    final bool isToday = _isSameDay(date, DateTime.now());
    final theme = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).currentTheme;
    final themeConfig = AppTheme.getMomentsTheme(theme);
    final Color iconColor = themeConfig['emptyStateIconColor'] as Color;
    final Color textColor = themeConfig['emptyStateTextColor'] as Color;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isToday ? Icons.lightbulb_outline : Icons.edit_note,
            size: 80,
            color: iconColor,
          ),
          const SizedBox(height: 24),
          Text(
            isToday ? "这一天不仅是空白，更是无限可能" : "这天没有留下记录",
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 16,
              color: textColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWaterfall(BuildContext context, List<Moment> moments) {
    if (moments.isEmpty) {
      // Just pick a random date or today for empty state logic
      return _buildEmptyStateForDate(DateTime.now());
    }

    // Sort by latest first for waterfall (Spontaneous inputs matter most)
    final sortedMoments = List<Moment>.from(moments);
    sortedMoments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Logic from DiaryListPage
        int columnCount = 1;
        if (width > 1200) {
          // Slightly wider for moments card
          columnCount = 3;
        } else if (width > 750) {
          columnCount = 2;
        }

        // Masonry Logic
        List<List<Moment>> columns = List.generate(columnCount, (_) => []);
        for (int i = 0; i < sortedMoments.length; i++) {
          columns[i % columnCount].add(sortedMoments[i]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            40,
            20,
            40,
            100,
          ), // Bottom padding for input widget
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columnCount; i++)
                Expanded(
                  child: Padding(
                    padding: i < columnCount - 1
                        ? const EdgeInsets.only(right: 24)
                        : EdgeInsets.zero,
                    child: Column(
                      children: columns[i].map((moment) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: MomentCard(
                            moment: moment,
                            baseDir: _baseDir,
                            onDelete: () async {
                              await _handleMomentDeleted(moment.uuid);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MomentLookupCache {
  final List<Moment> latestMoments;
  final Map<String, List<Moment>> momentsByDay;
  final Map<String, int> imageCountByDay;

  const _MomentLookupCache({
    required this.latestMoments,
    required this.momentsByDay,
    required this.imageCountByDay,
  });
}
