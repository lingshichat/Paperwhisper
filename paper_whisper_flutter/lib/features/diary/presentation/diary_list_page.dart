import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_announcement_coordinator.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_list_filter.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_timeline_layout_builder.dart';
import 'package:paper_whisper_flutter/features/permissions/application/permission_coordinator.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_ui_coordinator.dart';
import 'package:paper_whisper_flutter/features/update/application/update_check_coordinator.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/models/update_info.dart';
import 'package:paper_whisper_flutter/providers/diary_provider.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/services/update_service.dart';
import 'package:paper_whisper_flutter/app/shell/sidebar_widget.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_dialog.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_search_bar.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_toast.dart';

import 'widgets/book_flip_refresh_widget.dart';
import 'widgets/diary_card.dart';
import 'widgets/diary_empty_state.dart';
import 'widgets/diary_update_dialog.dart';
import 'widgets/month_divider.dart';

class DiaryListPage extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;

  const DiaryListPage({super.key, this.initialYear, this.initialMonth});

  @override
  State<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends State<DiaryListPage>
    with WidgetsBindingObserver {
  bool _isSearching = false;

  // Filter and Navigation
  int _displayYear = DateTime.now().year; // For AppBar display
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Cache for responsive layout
  List<Widget> _uiItems = [];
  Map<String, int> _monthTargetMap = {};
  List<int> _itemYearMap = []; // Map UI item index to Year
  String _lastLayoutCacheKey = ''; // 布局缓存 key，避免重复计算

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayYear = widget.initialYear ?? DateTime.now().year;

    _itemPositionsListener.itemPositions.addListener(_onScrollChanged);

    _checkAndroidPermissions();
    _checkAndShowAnnouncement();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRemoteUpdate();
      context.read<DiaryProvider>().ensureEntriesLoaded().then((_) {
        if (!mounted) return;

        if (widget.initialYear != null && widget.initialMonth != null) {
          _scrollToMonth(widget.initialYear!, widget.initialMonth!);
        } else if (widget.initialYear != null) {
          // Scroll to the first month of that year if only year is provided
          // Finding the "first" (which might be Dec or Jan depending on sort) month logic can be complex
          // Simpler: Scroll to the start of that year's block
          _scrollToYear(widget.initialYear!);
        }
      });
    });
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onScrollChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onScrollChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Find top-most visible item
    // items are not always sorted by index in the 'positions' iterable
    final sorted = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final firstIndex = sorted.first.index;

    if (firstIndex >= 0 && firstIndex < _itemYearMap.length) {
      final year = _itemYearMap[firstIndex];
      if (year != _displayYear) {
        setState(() {
          _displayYear = year;
        });
      }
    }
  }

  // 横切协调器（context-free）
  final UpdateCheckCoordinator _updateCheckCoordinator =
      UpdateCheckCoordinator();
  final PermissionCoordinator _permissionCoordinator = PermissionCoordinator();
  final DiaryAnnouncementCoordinator _announcementCoordinator =
      DiaryAnnouncementCoordinator();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndReload();
    }
  }

  Future<void> _checkPermissionAndReload() async {
    // 非 Android 直接重载；Android 需存储权限已授予。
    if (!Platform.isAndroid ||
        await _permissionCoordinator.isStorageGranted()) {
      if (mounted) {
        await Provider.of<DiaryProvider>(context, listen: false).loadEntries();
      }
    }
  }

  void _scrollToMonth(int year, int month) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_itemScrollController.isAttached) return; // Safety check

      final key = '${year}_$month';
      if (_monthTargetMap.containsKey(key)) {
        final index = _monthTargetMap[key]!;
        _itemScrollController.jumpTo(index: index, alignment: 0.0);
      } else {
        debugPrint('Navigation Warning: Key $key not found. Fallback to year.');
        _scrollToYear(year);
      }
    });
  }

  void _scrollToYear(int year) {
    // Find the first occurrence of this year in _itemYearMap
    // Since map is sorted (descending/ascending), fast scan is okay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _itemYearMap.indexOf(year);
      if (index != -1) {
        _itemScrollController.jumpTo(index: index, alignment: 0.0);
      }
    });
  }

  Future<void> _openDirectory() async {
    int targetYear = _displayYear;
    while (true) {
      if (!mounted) break;
      final result = await Navigator.push(
        context,
        AppRoutes.bookDirectory(year: targetYear),
      );

      if (result == null) break; // Back button pressed

      // AppRoutes.bookDirectory 返回 Route<int>：非空结果已保证为 int，
      // 移除旧 dynamic 时代的 `result is int` 类型守卫。
      debugPrint('Navigation Debug: Directory returned result: $result');
      if (result <= 12) {
        // It's a month
        debugPrint(
          'Navigation Debug: Recognized as month $result for year $targetYear',
        );

        // Wait for transition to finish
        await Future.delayed(const Duration(milliseconds: 300));

        _scrollToMonth(targetYear, result);
        break;
      } else {
        // It's a year (from Bookshelf)
        targetYear = result;
        debugPrint(
          'Navigation Debug: Recognized as new year $targetYear. Looping...',
        );

        // Wait for transition/rebuild
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollToYear(targetYear);
        // Loop continues -> Re-opens directory with new year
      }
    }
  }

  Future<void> _checkAndroidPermissions() async {
    if (!Platform.isAndroid) return;

    // 1. Check current status（委托 PermissionCoordinator）
    if (await _permissionCoordinator.isStorageGranted()) return;

    // 2. Determine if dialog should be shown (Simplified: always show if not granted)
    // We wait for the first frame to render before showing dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPermissionRationale();
    });
  }

  Future<void> _checkAndShowAnnouncement() async {
    // 两阶段 typed 协议：prepare 只读版本（不写 key）；页面 await 后
    // 先 mounted 检查，仅版本变更（Pending）时才 resolve 写 key 并加载
    // 本地公告，保证「版本读取完成后仍 mounted 才写 key」的旧版语义。
    final prepared = await _announcementCoordinator.prepare();
    if (!mounted) return;
    if (prepared is! DiaryAnnouncementPending) return;
    final outcome = await _announcementCoordinator.resolve(prepared);
    if (!mounted) return;
    if (outcome is DiaryAnnouncementShow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showUnifiedDialog(outcome.info, isAnnouncement: true);
      });
    }
  }

  Future<void> _checkRemoteUpdate() async {
    // 只有在非web平台检测
    if (kIsWeb) return;

    // 自动检查委托 UpdateCheckCoordinator（purpose 级会话去重：进程内
    // 首次成功检查后不再重复，避免主页每次进入都发请求；每次启动
    // 新进程仍会检查，保证更新提示不漏）。
    final outcome = await _updateCheckCoordinator.checkAuto(
      purpose: 'diary-list',
    );
    if (!mounted) return;
    if (outcome is UpdateCheckAvailable) {
      _showUnifiedDialog(outcome.info, isAnnouncement: false);
    }
  }

  void _showUnifiedDialog(UpdateInfo info, {required bool isAnnouncement}) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    // 从 typed 主题获取对话框副文本颜色
    final dlpTheme = ThemeRegistry.get(theme).diaryListPage;
    final secondaryColor = dlpTheme.updateDialogSecondaryColor;

    showDialog(
      context: context,
      barrierDismissible: !info.isForceUpdate,
      barrierColor: Colors.black.withValues(alpha: 0.6), // Consistent opacity
      builder: (context) => DiaryUpdateDialog(
        info: info,
        isAnnouncement: isAnnouncement,
        secondaryColor: secondaryColor,
        // 平台与 URL 决策留在页面；组件只消费 hasBackup 布尔与回调
        hasBackup: info.hasBackupUrl(UpdateService().currentPlatform),
        onBackup: () => UpdateService().openDownloadUrl(info, useBackup: true),
        onUpdate: () => UpdateService().openDownloadUrl(info),
      ),
    );
  }

  void _showPermissionRationale() async {
    // 0. Check preference: Don't ask again
    final prefs = await SharedPreferences.getInstance();
    final bool? dontAskAgain = prefs.getBool('permission_dont_ask_again');
    if (dontAskAgain == true) return;

    // 检测是否为鸿蒙系统（委托 PermissionCoordinator）
    final isHarmony = await _permissionCoordinator.isHarmonyOS();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SkeuomorphicDialog(
        title: '存储权限说明',
        headerIcon: Icons.folder_special,
        content: Text(
          '为了防止卸载应用后日记丢失，我们需要将数据保存在手机的【文档】目录中。\n\n请在接下来的系统提示中允许 “授予所有文件的管理权限”。',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerifSc(
            fontSize: 15,
            height: 1.6,
            color: const Color(0xFF5D4037),
          ),
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '不再提醒',
            isPrimary: false,
            // Use a subtle color or style if possible, or just standard secondary
            onPressed: () async {
              await prefs.setBool('permission_dont_ask_again', true);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                SkeuomorphicToast.info(context, '已设为不再自动提示，可在设置中手动开启');
              }
            },
          ),
          SkeuomorphicDialogButton(
            label: '暂不授权',
            isPrimary: false,
            onPressed: () {
              Navigator.pop(ctx);
              SkeuomorphicToast.info(context, '已拒绝权限，将在应用私有目录下运行');
            },
          ),
          SkeuomorphicDialogButton(
            label: '去授权',
            isPrimary: true,
            onPressed: () async {
              Navigator.pop(ctx);

              if (isHarmony) {
                // 鸿蒙系统：跳转到应用设置页
                final opened = await openAppSettings();
                if (opened) {
                  if (mounted) {
                    SkeuomorphicToast.info(context, '请在设置页开启存储权限后返回');
                  }
                  _schedulePermissionRecheck();
                } else {
                  if (mounted) {
                    SkeuomorphicToast.warning(context, '无法打开设置页，请手动前往设置');
                  }
                }
              } else {
                // 标准 Android：请求委托 PermissionCoordinator，typed 结果
                // 由页面翻译为 reload / Toast。
                final outcome = await _permissionCoordinator.requestPermission(
                  Permission.manageExternalStorage,
                );
                if (outcome == PermissionRequestOutcome.granted) {
                  if (mounted) {
                    await Provider.of<DiaryProvider>(
                      context,
                      listen: false,
                    ).reloadAfterPermission();
                  }
                } else {
                  if (mounted) {
                    SkeuomorphicToast.warning(context, '权限未授予，无法读取公共目录');
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  /// 延迟检查权限状态（用于鸿蒙系统从设置页返回后）
  void _schedulePermissionRecheck() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;

      if (await _permissionCoordinator.isStorageGranted()) {
        if (!mounted) return;
        await Provider.of<DiaryProvider>(
          context,
          listen: false,
        ).reloadAfterPermission();
        if (mounted) {
          SkeuomorphicToast.success(context, '存储权限已获取');
        }
      }
    });
  }

  /// 显示 WebDAV 配置提示
  void _showWebDavConfigPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: '尚未配置同步',
        headerIcon: Icons.cloud_off_outlined,
        content: Text(
          '您还没有配置 WebDAV 同步服务。\n\n配置后，日记将自动同步到云端，随时随地访问。',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerifSc(
            fontSize: 15,
            height: 1.6,
            color: const Color(0xFF5D4037),
          ),
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '稍后再说',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          SkeuomorphicDialogButton(
            label: '去配置',
            isPrimary: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, AppRoutes.syncSettings());
            },
          ),
        ],
      ),
    );
  }

  void _openEditor(DiaryEntry? entry, [Rect? cardRect]) {
    if (entry == null) {
      // 新建日记：使用信纸对折动画
      Navigator.push(
        context,
        AppRoutes.editor(transition: AppRouteTransition.letterFold),
      );
    } else if (cardRect != null) {
      // 智能分级：超过 300 字符启用性能模式，优化长日记体验
      final bool isLongDiary = (entry.content.length > 300);

      // 这里的闭包变量用于连接 UnfoldPageRoute 的动画结束事件和 EditorPage 的状态更新
      VoidCallback? showFullContent;

      // 点击卡片：使用展开动画
      Navigator.push(
        context,
        AppRoutes.editor(
          entry: entry,
          usePreviewMode: isLongDiary, // 开启首屏渲染优化
          onContentReady: (callback) {
            showFullContent = callback; // 捕获编辑器的刷新方法
          },
          transition: AppRouteTransition.unfold,
          sourceRect: cardRect,
          // 关键恢复：虽然是长日记，但因为我们有了数据截断优化，
          // 所以可以放心使用完整的 800ms 动态圆角动画，无需性能降级！
          usePerformanceMode: false,
          onAnimationComplete: () {
            // 动画结束后，通知编辑器加载完整内容
            showFullContent?.call();
          },
        ),
      );
    } else {
      // 降级：使用平滑动画
      Navigator.push(context, AppRoutes.editor(entry: entry));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 800;

        // 内容区（瀑布流布局）
        final Widget contentArea = _buildContentArea(
          context,
          theme,
          !isDesktop,
          constraints.maxWidth,
        );

        if (isDesktop) {
          // Desktop: Fixed Sidebar + Content
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
                        activeSection: SidebarSection.writer,
                      ),
                    ),
                    Expanded(child: contentArea),
                  ],
                ),
              ],
            ),
          );
        } else {
          // Mobile: Drawer + Content
          final dlpThemeMobile = ThemeRegistry.get(theme).diaryListPage;

          return Scaffold(
            backgroundColor: Colors.transparent,
            drawerScrimColor: dlpThemeMobile.drawerScrimColor,
            drawer: const Drawer(
              width: 300,
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: SidebarWidget(activeSection: SidebarSection.writer),
            ),
            // Mobile Body
            body: Stack(
              children: [
                // 1. Background
                Container(decoration: AppTheme.getBackground(theme)),

                // 2. Visual Effects
                ...AppTheme.getBackgroundOverlays(theme),

                // 3. Content
                contentArea,
              ],
            ),
            floatingActionButton: Builder(
              builder: (ctx) {
                final fabConfig = ThemeRegistry.get(theme).fab;
                final gradient = fabConfig.backgroundGradient;
                final isCustom = gradient != null;

                return FloatingActionButton(
                  backgroundColor: isCustom
                      ? Colors.transparent
                      : fabConfig.backgroundColor,
                  elevation: isCustom ? 0 : 6,
                  focusElevation: isCustom ? 0 : 6,
                  hoverElevation: isCustom ? 0 : 8,
                  highlightElevation: isCustom ? 0 : 12,
                  onPressed: () => _openEditor(null),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: isCustom
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: gradient,
                            boxShadow: [fabConfig.shadow],
                          )
                        : null,
                    child: Icon(
                      Icons.edit,
                      color: fabConfig.iconColor,
                      size: isCustom ? 28 : 24,
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildContentArea(
    BuildContext context,
    String theme,
    bool isMobile,
    double availableWidth,
  ) {
    final diaryProvider = Provider.of<DiaryProvider>(context);
    // 空态取色：页面从七主题 typed 数据取色后显式传给组件 props
    final dlpThemeEmpty = ThemeRegistry.get(theme).diaryListPage;

    // Prepare Data
    List<dynamic> rawFlatEntries = [];

    if (diaryProvider.diarySearchQuery.isNotEmpty) {
      // Search Mode（过滤语义委托纯函数 DiaryListFilter）
      rawFlatEntries = DiaryListFilter.filter(
        entries: diaryProvider.entries,
        query: diaryProvider.diarySearchQuery,
      );
    } else {
      // Continuous Flow Mode
      // CURRENT: Use Provider's flat entries directly (sorted descending/Mixed)
      rawFlatEntries = diaryProvider.flatEntries;
    }

    // 布局缓存检测：仅当数据、视口宽度或主题变化时才重新计算
    // 加入 provider.lastUpdateTick 确保日记内容修改后（即使长度不变）也能触发刷新
    final cacheKey =
        '${rawFlatEntries.length}_${availableWidth.toInt()}_${theme}_${diaryProvider.lastUpdateTick}_${diaryProvider.diarySearchQuery}';
    if (_lastLayoutCacheKey != cacheKey) {
      _generateResponsiveLayout(
        rawFlatEntries,
        availableWidth,
        theme,
        diaryProvider,
      );
      _lastLayoutCacheKey = cacheKey;
    }

    return Column(
      children: [
        // Mobile Header (Now also for Desktop, but without Menu button)
        Builder(
          builder: (scaffoldContext) {
            final themeData = ThemeRegistry.get(theme);
            final headerColors = themeData.mobileHeader;
            final dlpThemeHeader = themeData.diaryListPage;

            Widget headerContent = Container(
              height: 56 + MediaQuery.of(scaffoldContext).padding.top,
              padding: EdgeInsets.only(
                top: MediaQuery.of(scaffoldContext).padding.top,
              ),
              decoration: BoxDecoration(
                color: headerColors.background,
                border: Border(
                  bottom: BorderSide(color: headerColors.border, width: 1),
                ),
                boxShadow: dlpThemeHeader.headerBoxShadow,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSearching
                    ? Row(
                        key: const ValueKey('search_bar'),
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: headerColors.iconColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                diaryProvider.setSearchQuery('');
                              });
                            },
                          ),
                          Expanded(
                            child: SkeuomorphicSearchBar(
                              value: diaryProvider.searchQuery,
                              autoFocus: true,
                              hintText: '搜索日记...',
                              onChanged: (val) {
                                diaryProvider.setSearchQuery(val);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      )
                    : Row(
                        key: const ValueKey('title_bar'),
                        children: [
                          if (isMobile)
                            IconButton(
                              icon: Icon(
                                Icons.menu,
                                color: headerColors.iconColor,
                              ),
                              onPressed: () =>
                                  Scaffold.of(scaffoldContext).openDrawer(),
                            )
                          else
                            const SizedBox(width: 16), // Desktop spacer

                          Expanded(
                            child: GestureDetector(
                              onTap: _openDirectory,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    diaryProvider.getBookTitle(_displayYear),
                                    style: GoogleFonts.notoSerifSc(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: headerColors.titleColor,
                                      shadows: const [
                                        Shadow(
                                          color: Color.fromRGBO(0, 0, 0, 0.1),
                                          offset: Offset(0, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '点击翻阅目录',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: headerColors.subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isMobile) // Hide search icon on Desktop (Sidebar has one)
                            IconButton(
                              icon: Icon(
                                Icons.search,
                                color: headerColors.iconColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSearching = true;
                                });
                              },
                            ),
                          const SizedBox(width: 4),
                        ],
                      ),
              ),
            );

            // Apply Blur for themes that need it
            if (dlpThemeHeader.headerApplyBlur) {
              return ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: headerContent,
                ),
              );
            }

            return headerContent;
          },
        ),

        // List with Continuous Flow
        Expanded(
          child: BookFlipRefreshWidget(
            theme: theme,
            onLongRefreshTap: () {
              Navigator.push(context, AppRoutes.syncSettings());
            },
            onRefresh: () async {
              final syncProvider = Provider.of<SyncProvider>(
                context,
                listen: false,
              );
              if (!syncProvider.isConfigured) {
                if (mounted) {
                  _showWebDavConfigPrompt();
                }
                return;
              }
              // 手动同步的权限前置与结果 Toast 反馈由 SyncUiCoordinator 处理。
              await SyncUiCoordinator(context).runManualSync(syncProvider);
            },
            child: _uiItems.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: DiaryEmptyState(
                        query: diaryProvider.diarySearchQuery,
                        searchTextColor: AppTheme.getTextColor(
                          theme,
                        ).withValues(alpha: 0.7),
                        iconColor: dlpThemeEmpty.emptyStateIconColor,
                        textColor: dlpThemeEmpty.emptyStateTextColor,
                        linkColor: dlpThemeEmpty.emptyStateLinkColor,
                        onCreate: () => _openEditor(null),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: ScrollablePositionedList.builder(
                      itemCount: _uiItems.length,
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      itemBuilder: (context, index) => _uiItems[index],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiaryCard(BuildContext context, DiaryEntry entry, String theme) {
    return DiaryCard(
      entry: entry,
      theme: theme,
      onTapWithRect: (rect) => _openEditor(entry, rect),
    );
  }

  void _generateResponsiveLayout(
    List<dynamic> rawItems,
    double width,
    String theme,
    DiaryProvider provider,
  ) {
    // 适配：页面扁平列表（MonthHeader / DiaryEntry 混合）→ 纯数据输入。
    final inputs = rawItems
        .map(
          (item) => item is MonthHeader
              ? DiaryMonthInput(year: item.year, month: item.month)
              : DiaryEntryInput(item as DiaryEntry),
        )
        .toList();

    // 列数 / contentWidth / 分组缓冲算法委托纯计算，返回 typed plan。
    final layout = DiaryTimelineLayoutBuilder.build(
      items: inputs,
      width: width,
    );

    _uiItems = [];
    _monthTargetMap = layout.monthTargetMap;
    _itemYearMap = layout.itemYearMap;

    for (final unit in layout.units) {
      switch (unit) {
        case DiaryMonthUnit(:final year, :final month):
          _uiItems.add(
            MonthDivider(
              year: year,
              month: month,
              title: provider.getMonthTitle(year, month),
              theme: theme,
            ),
          );
        case DiaryEntryRowUnit(:final entries):
          _uiItems.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in entries)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: _buildDiaryCard(context, e, theme),
                      ),
                    ),
                  ...List.generate(
                    layout.columnCount - entries.length,
                    (_) => const Expanded(child: SizedBox()),
                  ),
                ],
              ),
            ),
          );
      }
    }
  }
}
