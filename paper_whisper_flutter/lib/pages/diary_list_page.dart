import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../providers/settings_provider.dart';
import '../models/diary_entry.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_theme.dart';
import '../widgets/skeuomorphic_container.dart';
import '../widgets/sidebar_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/diary_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/visual_effects.dart';
import '../widgets/book_flip_refresh_widget.dart';
import '../widgets/dashed_line_painter.dart';
import '../widgets/skeuomorphic_dialog.dart'; // Updated import
import '../widgets/skeuomorphic_search_bar.dart';
import '../widgets/month_divider.dart';
import '../widgets/skeuomorphic_toast.dart';
import 'editor_page.dart';
import 'diary_card.dart';
import 'sync_settings_page.dart';
import '../widgets/slide_page_route.dart';
import '../widgets/unfold_page_route.dart';
import '../widgets/paper_fold_page_route.dart'; // LetterFoldPageRoute
import '../widgets/book_flip_page_route.dart'; // BookFlipPageRoute
import '../widgets/smooth_cover_page_route.dart'; // SmoothCoverPageRoute
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';
import '../utils/platform_utils.dart';
import 'bookshelf_page.dart';
import 'book_directory_page.dart';

class DiaryListPage extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;

  const DiaryListPage({super.key, this.initialYear, this.initialMonth});

  @override
  State<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends State<DiaryListPage> with WidgetsBindingObserver {
  String _searchQuery = '';
  bool _isSearching = false;
  
  // Filter and Navigation
  // Filter and Navigation
  // late int _filterYear; // Removed strict filter
  int _displayYear = DateTime.now().year; // For AppBar display
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  
  // Cache for responsive layout
  List<Widget> _uiItems = [];
  Map<String, int> _monthTargetMap = {};
  List<int> _itemYearMap = []; // Map UI item index to Year
  String _lastLayoutCacheKey = ''; // 布局缓存 key，避免重复计算
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // _filterYear = widget.initialYear ?? DateTime.now().year; 
    _displayYear = widget.initialYear ?? DateTime.now().year;

    _itemPositionsListener.itemPositions.addListener(_onScrollChanged);
    
    _checkAndroidPermissions();
    _checkAndShowAnnouncement();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRemoteUpdate();
      Provider.of<DiaryProvider>(context, listen: false).loadEntries().then((_) {
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
    final sorted = positions.toList()..sort((a,b) => a.index.compareTo(b.index));
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
       _checkPermissionAndReload();
    }
  }

  Future<void> _checkPermissionAndReload() async {
     if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
           if (mounted) {
              await Provider.of<DiaryProvider>(context, listen: false).loadEntries();
           }
        }
     } else {
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
       final result = await Navigator.push(
          context,
          SmoothCoverPageRoute(page: BookDirectoryPage(year: targetYear)),
       );
       
       if (result == null) break; // Back button pressed
       
       if (result is int) {
          debugPrint('Navigation Debug: Directory returned result: $result');
          if (result <= 12) {
             // It's a month
             debugPrint('Navigation Debug: Recognized as month $result for year $targetYear');
             
             // Wait for transition to finish
             await Future.delayed(const Duration(milliseconds: 300));
             
             _scrollToMonth(targetYear, result);
             break; 
          } else {
             // It's a year (from Bookshelf)
             targetYear = result;
             debugPrint('Navigation Debug: Recognized as new year $targetYear. Looping...');
             
             // Wait for transition/rebuild
             await Future.delayed(const Duration(milliseconds: 100));
             _scrollToYear(targetYear);
             // Loop continues -> Re-opens directory with new year
          }
       }
    }
  }

  Future<void> _checkAndroidPermissions() async {
    if (!Platform.isAndroid) return;

    // 1. Check current status
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return;

    // 2. Determine if dialog should be shown (Simplified: always show if not granted)
    // We wait for the first frame to render before showing dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _showPermissionRationale();
    });
  }

  Future<void> _checkAndShowAnnouncement() async {
    final prefs = await SharedPreferences.getInstance();
    final updateService = UpdateService();
    
    // 1. Get Current Version Dynamically
    final currentVersion = await updateService.getCurrentVersion();
    final lastVersion = prefs.getString('last_run_version');

    // 2. Compare Version
    if (lastVersion != currentVersion) {
      if (mounted) {
        // Update stored version
        await prefs.setString('last_run_version', currentVersion);
        
        // 3. Load Local Announcement (assets/version.json)
        final localInfo = await updateService.getLocalUpdateInfo();
        
        if (localInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             _showUnifiedDialog(localInfo, isAnnouncement: true);
          });
        }
      }
    }
  }

  Future<void> _checkRemoteUpdate() async {
    // 只有在非web平台检测
    if (kIsWeb) return;
    
    try {
      final updateInfo = await UpdateService().checkForUpdate();
      if (updateInfo != null && mounted) {
        _showUnifiedDialog(updateInfo, isAnnouncement: false);
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  void _showUnifiedDialog(UpdateInfo info, {required bool isAnnouncement}) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    // Determine secondary text color based on theme
    final secondaryColor = (theme == AppTheme.themeMidnight) 
        ? const Color(0xFF8b949e) // Midnight Secondary
        : (theme == AppTheme.themeSeaFlower 
            ? const Color(0xFFC2185B) // SeaFlower Secondary
            : (theme == AppTheme.themeGardenOfWords 
                ? const Color(0xFF5A6B72) // Garden Secondary
                : const Color(0xFF8D6E63))); // Vintage/Default Secondary

    showDialog(
      context: context,
      barrierDismissible: !info.isForceUpdate,
      barrierColor: Colors.black.withOpacity(0.6), // Consistent opacity
      builder: (context) => SkeuomorphicDialog(
        title: isAnnouncement 
            ? (info.title ?? '版本更新 ${info.latestVersion}') 
            : '发现新版本 ${info.latestVersion}',
        headerIcon: isAnnouncement ? Icons.auto_awesome : Icons.system_update,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (info.releaseDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '发布日期：${info.releaseDate}',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 12,
                    color: secondaryColor,
                  ),
                ),
              ),
            // Changelog List
            ...info.changelog.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Icon color will be handled by DefaultTextStyle unless specified, 
                   // but let's keep it simple or use secondaryColor for bullet if needed.
                   // Since _getBulletIcon returns empty string now, this Text is just empty.
                  Text(
                     _getBulletIcon(line), 
                     style: TextStyle(fontSize: 14, height: 1.4, color: secondaryColor) 
                  ), 
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _cleanLine(line),
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 15,
                        height: 1.6,
                        // Remove hardcoded color: const Color(0xFF5D4037),
                        // so it inherits from SkeuomorphicDialog's DefaultTextStyle
                      ),
                    ),
                  ),
                ],
              ),
            )),
            if (isAnnouncement) ...[
               const SizedBox(height: 16),
               Text(
                 "感谢您与纸语一同成长。", 
                 style: GoogleFonts.notoSerifSc(
                    fontSize: 13, 
                    color: secondaryColor,
                    fontStyle: FontStyle.italic,
                 )
               )
            ]
          ],
        ),
        actions: [
          if (isAnnouncement)
             SkeuomorphicDialogButton(
               label: '开启体验', 
               isPrimary: true, 
               onPressed: () => Navigator.pop(context)
             )
          else ...[
             if (!info.isForceUpdate)
               SkeuomorphicDialogButton(
                 label: '暂不更新', 
                 isPrimary: false, 
                 onPressed: () => Navigator.pop(context)
               ),
             // 备用下载按钮
             if (info.hasBackupUrl(UpdateService().currentPlatform))
               SkeuomorphicDialogButton(
                 label: '备用下载',
                 isPrimary: false,
                 onPressed: () {
                   Navigator.pop(context);
                   UpdateService().openDownloadUrl(info, useBackup: true);
                 },
               ),
             SkeuomorphicDialogButton(
               label: '立即更新', 
               isPrimary: true, 
               onPressed: () {
                 if (info.downloadUrl != null) {
                    Navigator.pop(context);
                    UpdateService().openDownloadUrl(info);
                 }
               }
             ),
          ]
        ],
      )
    );
  }

  String _getBulletIcon(String line) {
    // Basic heuristic: check if line starts with specific emojis
    // Or just return dot if simple.
    // The version.json lines already have emojis like "✨ [新增]".
    // We can just return empty string if the line handles it, or standardized bullet.
    // The user's requested style had emoji separately.
    // Let's rely on the text itself having the emoji for now as per version.json content.
    // But to align with previous code logic '• ', let's see.
    // version.json: "✨ [新增] ..."
    // So we don't need extra bullet.
    return ''; 
  }

  String _cleanLine(String line) {
     return line;
  }



  void _showPermissionRationale() async {
    // 0. Check preference: Don't ask again
    final prefs = await SharedPreferences.getInstance();
    final bool? dontAskAgain = prefs.getBool('permission_dont_ask_again');
    if (dontAskAgain == true) return;

    // 检测是否为鸿蒙系统
    final isHarmony = await PlatformUtils.isHarmonyOS();
    
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
                // 标准 Android：使用 permission_handler 请求
                final status = await Permission.manageExternalStorage.request();
                if (status.isGranted) {
                  if (mounted) {
                    await Provider.of<DiaryProvider>(context, listen: false).reloadAfterPermission();
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
      
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) {
        await Provider.of<DiaryProvider>(context, listen: false).reloadAfterPermission();
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
              Navigator.push(
                context,
                SlidePageRoute(page: const SyncSettingsPage()),
              );
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
        LetterFoldPageRoute(page: EditorPage(entry: null)),
      );
    } else if (cardRect != null) {
      // 智能分级：超过 300 字符启用性能模式，优化长日记体验
      final bool isLongDiary = (entry.content.length > 300);
      
      // 这里的闭包变量用于连接 UnfoldPageRoute 的动画结束事件和 EditorPage 的状态更新
      VoidCallback? showFullContent;

      // 点击卡片：使用展开动画
      Navigator.push(
        context, 
        UnfoldPageRoute(
          // 传递 EditorPage，并注入状态回调
          page: EditorPage(
            entry: entry,
            usePreviewMode: isLongDiary, // 开启首屏渲染优化
            onContentReady: (callback) {
              showFullContent = callback; // 捕获编辑器的刷新方法
            },
          ), 
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
      Navigator.push(
        context,
        SlidePageRoute(page: EditorPage(entry: entry)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We access settings just to trigger rebuilds on theme change if needed
    // But mostly AppTheme handles the static logic or we use Consumer below
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop breakpoint: > 800px (Matches "Tablet/Desktop" logic from plan)
        final bool isDesktop = constraints.maxWidth > 800;

        // Content Area (The Waterfall Layout)
        // We will put this in a Widget to reuse
        // Pass width to generate layout
        final Widget contentArea = _buildContentArea(context, theme, !isDesktop, constraints.maxWidth);

        if (isDesktop) {
          // Desktop: Fixed Sidebar + Content
          return Scaffold(
             backgroundColor: Colors.transparent, 
             body: Stack(
               children: [
                 // 1. Background
                 Container(decoration: AppTheme.getBackground(theme)),
                 
                 // 2. Visual Effects
                 if (theme == AppTheme.themeSeaFlower) const PetalRainWidget(),
                 if (theme == AppTheme.themeMidnight) const StarrySkyWidget(),
                 if (theme == AppTheme.themeAfterRain) const AfterRainVisuals(),

                 // 3. Main Layout
                 Row(
                    children: [
                       const SizedBox(
                         width: 300, 
                         child: SidebarWidget(),
                       ),
                       Expanded(
                         child: contentArea,
                       ),
                    ],
                 ),
               ],
             ),
          );
        } else {
          // Mobile: Drawer + Content
          final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
          
          return Scaffold(
            backgroundColor: Colors.transparent,
            drawerScrimColor: (isSeaFlower || theme == AppTheme.themeAfterRain) ? Colors.transparent : Colors.black54, // 海底花海/雨后天空去遮罩，透出背景
            drawer: const Drawer(
              width: 300,
              elevation: 0, 
              backgroundColor: Colors.transparent, 
              child: SidebarWidget(),
            ),
            // Mobile Body
            body: Stack(
              children: [
                // 1. Background
                Container(decoration: AppTheme.getBackground(theme)),
                
                // 2. Visual Effects
                if (theme == AppTheme.themeSeaFlower) const PetalRainWidget(),
                if (theme == AppTheme.themeMidnight) const StarrySkyWidget(),
                if (theme == AppTheme.themeAfterRain) const AfterRainVisuals(),
                
                // 3. Content
                contentArea,
              ],
            ),
             floatingActionButton: Builder(
               builder: (ctx) {
                 final fabConfig = AppTheme.getFabTheme(theme);
                 final isCustom = fabConfig['bg'] is Gradient;
                 
                 return FloatingActionButton(
                   backgroundColor: isCustom ? Colors.transparent : fabConfig['bg'],
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
                             gradient: fabConfig['bg'],
                             boxShadow: [fabConfig['shadow']],
                           )
                         : null,
                     child: Icon(Icons.edit, color: fabConfig['iconColor'], size: isCustom ? 28 : 24),
                   ),
                 );
               }
             ),
          );
        }
      },
    );
  }
  
  Widget _buildContentArea(BuildContext context, String theme, bool isMobile, double availableWidth) {
    final diaryProvider = Provider.of<DiaryProvider>(context);
    
    // Prepare Data
    List<dynamic> rawFlatEntries = [];
    
    if (_searchQuery.isNotEmpty) {
      // Search Mode
      rawFlatEntries = diaryProvider.entries.where((e) => 
         e.title.contains(_searchQuery) || e.content.contains(_searchQuery) || e.dateString.contains(_searchQuery)
      ).toList();
    } else {

      // Continuous Flow Mode
      // CURRENT: Use Provider's flat entries directly (sorted descending/Mixed)
      rawFlatEntries = diaryProvider.flatEntries;
    }

    // 布局缓存检测：仅当数据变化时才重新计算
    final cacheKey = '${rawFlatEntries.length}_${availableWidth.toInt()}_$theme';
    if (_lastLayoutCacheKey != cacheKey) {
      _generateResponsiveLayout(rawFlatEntries, availableWidth, theme, diaryProvider);
      _lastLayoutCacheKey = cacheKey;
    }

    return Column(
      children: [
        // Mobile Header (Now also for Desktop, but without Menu button)
           Builder(
             builder: (scaffoldContext) {
               final headerColors = AppTheme.getMobileHeaderColors(theme);
               final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
               
               Widget headerContent = Container(
                     height: 56 + MediaQuery.of(scaffoldContext).padding.top,
                     padding: EdgeInsets.only(top: MediaQuery.of(scaffoldContext).padding.top),
                     decoration: BoxDecoration(
                       color: headerColors['background'],
                       border: Border(
                         bottom: BorderSide(color: headerColors['border']!, width: 1),
                       ),
                       boxShadow: isSeaFlower ? [] : [
                         BoxShadow(
                           color: Colors.black.withValues(alpha: 0.1), // Lighter shadow
                           blurRadius: 4,
                           offset: const Offset(0, 2),
                         ),
                       ],
                     ),
                     child: AnimatedSwitcher(
                       duration: const Duration(milliseconds: 300),
                       child: _isSearching
                         ? Row(
                             key: const ValueKey('search_bar'),
                             children: [
                               IconButton(
                                 icon: Icon(Icons.arrow_back, color: headerColors['iconColor']),
                                 onPressed: () {
                                   setState(() {
                                     _isSearching = false;
                                     _searchQuery = '';
                                   });
                                 },
                               ),
                               Expanded(
                                 child: SkeuomorphicSearchBar(
                                   value: _searchQuery,
                                   autoFocus: true,
                                   hintText: '搜索日记...',
                                   onChanged: (val) {
                                     setState(() {
                                       _searchQuery = val;
                                     });
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
                                   icon: Icon(Icons.menu, color: headerColors['iconColor']),
                                   onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
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
                                            color: headerColors['titleColor'],
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
                                            color: headerColors['subtitleColor'],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                               IconButton(
                                 icon: Icon(Icons.search, color: headerColors['iconColor']),
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

               // Apply Blur for Sea Flower
               if (isSeaFlower) {
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
               Navigator.push(
                 context,
                 SlidePageRoute(page: const SyncSettingsPage()),
               );
            },
            onRefresh: () async {
              final syncProvider = Provider.of<SyncProvider>(context, listen: false);
              if (!syncProvider.isConfigured) {
                if (mounted) {
                  _showWebDavConfigPrompt();
                }
                return;
              }
              await syncProvider.sync(context: context);
            },
            child: _uiItems.isEmpty 
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: _buildEmptyState(theme),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
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

  Widget _buildEmptyState(String theme) {
    if (_searchQuery.isNotEmpty) {
      // 搜索无结果状态
      final Color emptyTextColor = AppTheme.getTextColor(theme).withOpacity(0.7);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Icon(Icons.search_off, size: 80, color: emptyTextColor),
             const SizedBox(height: 24),
             Text(
               '没有找到关于"$_searchQuery"的篇章...',
               style: GoogleFonts.notoSerifSc(
                 color: emptyTextColor,
                 fontSize: 16,
                 fontStyle: FontStyle.italic,
               ),
             ),
          ],
        ),
      );
    }

    // 获取主题适配的颜色
    Color iconColor;
    Color textColor;
    Color linkColor;
    
    if (theme == AppTheme.themeAfterRain) {
      iconColor = AppTheme.getTextSecondaryColor(theme).withValues(alpha: 0.6);
      textColor = AppTheme.getTextSecondaryColor(theme).withValues(alpha: 0.8);
      linkColor = AppTheme.getAccentColor(theme);
    } else if (theme == AppTheme.themeGardenOfWords) {
      iconColor = AppTheme.getTextSecondaryColor(theme).withValues(alpha: 0.6);
      textColor = AppTheme.getTextSecondaryColor(theme).withValues(alpha: 0.8);
      linkColor = AppTheme.getAccentColor(theme);
    } else if (theme == AppTheme.themeSeaFlower) {
        // 浅色背景，使用深色图标和文字
        iconColor = const Color(0xFF6D5D5D).withValues(alpha: 0.6);
        textColor = const Color(0xFF6D5D5D).withValues(alpha: 0.8);
        linkColor = const Color(0xFFC2185B); // 粉红强调色
    } else if (theme == AppTheme.themeTwilight) {
        // Twilight Style
        iconColor = AppTheme.getAccentColor(theme).withValues(alpha: 0.5);
        textColor = AppTheme.getTextSecondaryColor(theme).withValues(alpha: 0.8);
        linkColor = AppTheme.getAccentColor(theme);
    } else if (theme == AppTheme.themeMidnight || theme == AppTheme.themeAmberLens) {
        // 深色背景，使用灰色图标和文字
        iconColor = Colors.grey.shade500.withValues(alpha: 0.7);
        textColor = Colors.grey.shade400;
        linkColor = AppTheme.getAccentColor(theme);
    } else {
        // 复古纸张
        iconColor = const Color(0xFFD7CCC8).withValues(alpha: 0.5);
        textColor = const Color(0xFFD7CCC8).withValues(alpha: 0.8);
        linkColor = const Color(0xFFFF5252);
    }
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 蜘蛛网图标 - 使用 CustomPaint 绘制
          CustomPaint(
            size: const Size(64, 64), // 设计图中图标不需要太大
            painter: _SpiderWebIconPainter(color: iconColor),
          ),
          const SizedBox(height: 32),
          Text(
            '这里似乎落了一层灰，等待你来翻阅',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 16,
              color: textColor,
              height: 1.5,
              fontStyle: FontStyle.italic, // 恢复斜体
            ),
          ),
          const SizedBox(height: 48), // 增加间距
          
          // "去擦拭灰尘（写一篇）→" 按钮 - 带虚线
          GestureDetector(
            onTap: () => _openEditor(null),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '去擦拭灰尘 (写一篇) →',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 15,
                    color: linkColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4), // 文字和虚线的间距
                SizedBox(
                  width: 180, // 根据文字长度估算，确保虚线覆盖文字
                  height: 1,
                  child: CustomPaint(
                    painter: DashedLinePainter(color: linkColor.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterfallGrid(BuildContext context, List<DiaryEntry> list, String theme) {
    // Determine column count based on width
    // We use LayoutBuilder again for the inner content width
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columnCount = 1;
        if (width > 1100) {
          columnCount = 3;
        } else if (width > 700) {
          columnCount = 2;
        }

        // Masonry Logic: Distribute items into columns
        List<List<DiaryEntry>> columns = List.generate(columnCount, (_) => []);
        for (int i = 0; i < list.length; i++) {
          columns[i % columnCount].add(list[i]);
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columnCount; i++)
                Expanded(
                  child: Padding(
                    padding: i < columnCount - 1 
                        ? const EdgeInsets.only(right: 30) // Column Gap
                        : EdgeInsets.zero,
                    child: Column(
                      children: columns[i].map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 30), // Item Gap
                          child: _buildDiaryCard(context, entry, theme),
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

  /// 不带 ScrollView 的瀑布流内容（供 BookFlipRefreshWidget 使用）
  Widget _buildWaterfallGridContent(BuildContext context, List<DiaryEntry> list, String theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columnCount = 1;
        if (width > 1100) {
          columnCount = 3;
        } else if (width > 700) {
          columnCount = 2;
        }

        List<List<DiaryEntry>> columns = List.generate(columnCount, (_) => []);
        for (int i = 0; i < list.length; i++) {
          columns[i % columnCount].add(list[i]);
        }

        return Padding(
          padding: const EdgeInsets.all(40),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columnCount; i++)
                Expanded(
                  child: Padding(
                    padding: i < columnCount - 1 
                        ? const EdgeInsets.only(right: 30)
                        : EdgeInsets.zero,
                    child: Column(
                      children: columns[i].map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: _buildDiaryCard(context, entry, theme),
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

  Widget _buildDiaryCard(BuildContext context, DiaryEntry entry, String theme) {
    return DiaryCard(
      entry: entry, 
      theme: theme,
      onTapWithRect: (rect) => _openEditor(entry, rect),
    );
  }

  void _generateResponsiveLayout(List<dynamic> rawItems, double width, String theme, DiaryProvider provider) {
    _uiItems = [];
    _monthTargetMap = {};
    _itemYearMap = [];
    
    double contentWidth = width;
    if (width > 800) contentWidth -= 300;
    
    int columnCount = 1;
    if (contentWidth > 1100) columnCount = 3;
    else if (contentWidth > 700) columnCount = 2;
    
    List<DiaryEntry> buffer = [];

    // Helper to determine year of items in buffer
    // All items in buffer should belong to one "block" typically, but let's be safe
    // Actually, we can just use the year of the first item in buffer
    
    void flushBuffer() {
       if (buffer.isNotEmpty) {
          // Determine year for this row (use first item's year)
          int rowYear = 0;
          final parts = buffer.first.dateString.split('-');
          if (parts.isNotEmpty) rowYear = int.tryParse(parts[0]) ?? 0;

          _uiItems.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: buffer.map((e) => Expanded(
                    child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 15),
                       child: _buildDiaryCard(context, e, theme),
                    )
                 )).toList()
                   ..addAll(List.generate(columnCount - buffer.length, (_) => const Expanded(child: SizedBox()))),
              ),
            )
          );
          _itemYearMap.add(rowYear);
          buffer = [];
       }
    }

    for (var item in rawItems) {
       if (item is MonthHeader) {
          flushBuffer();
          _monthTargetMap['${item.year}_${item.month}'] = _uiItems.length;
          _uiItems.add(
             MonthDivider(
                year: item.year, 
                month: item.month, 
                title: provider.getMonthTitle(item.year, item.month),
                theme: theme,
             )
          );
          _itemYearMap.add(item.year);
       } else if (item is DiaryEntry) {
          buffer.add(item);
          if (buffer.length == columnCount) flushBuffer();
       }
    }
    flushBuffer();
  }
}

class RuledPaperPainter extends CustomPainter {
  final Color lineColor;
  RuledPaperPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth =1;
    
    double y = 40;
    while (y < size.height - 20) {
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), paint);
      y += 28;
    }
    
    final marginPaint = Paint()
      ..color = Colors.red.withOpacity(0.05)
      ..strokeWidth = 1;
    
    canvas.drawLine(Offset(40, 0), Offset(40, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 蜘蛛网图标绘制器 - 用于空状态显示
/// 设计：六边形框架 + 内部蜘蛛网线条，体现"落灰"的意象
class _SpiderWebIconPainter extends CustomPainter {
  final Color color;
  
  _SpiderWebIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 // 加粗外框
      ..strokeJoin = StrokeJoin.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // 六边形顶点（从顶部开始顺时针）
    final double radius = size.width * 0.45;
    final List<Offset> hexPoints = [];
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180; // 从顶部开始
      hexPoints.add(Offset(
        centerX + radius * math.cos(angle),
        centerY + radius * math.sin(angle),
      ));
    }
    
    // 绘制六边形外框（拟物化：使用贝塞尔曲线向内凹陷）
    final hexPath = Path();
    hexPath.moveTo(hexPoints[0].dx, hexPoints[0].dy);
    for (int i = 0; i < 6; i++) {
        // 当前点
        final p1 = hexPoints[i];
        // 下一个点
        final p2 = hexPoints[(i + 1) % 6];
        
        // 计算中点
        final midX = (p1.dx + p2.dx) / 2;
        final midY = (p1.dy + p2.dy) / 2;
        
        // 计算控制点：向中心凹陷
        const curveFactor = 0.12; // 外框稍微绷紧一点
        final controlX = midX + (centerX - midX) * curveFactor;
        final controlY = midY + (centerY - midY) * curveFactor;
        
        hexPath.quadraticBezierTo(controlX, controlY, p2.dx, p2.dy);
    }
    // hexPath.close(); // Closed by loop logic
    canvas.drawPath(hexPath, paint);
    
    // 绘制从中心到六个顶点的辐射线
    final thinPaint = Paint()
      ..color = color.withValues(alpha: 0.8) // 稍微加深
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0; // 加粗线条
      
    final center = Offset(centerX, centerY);
    for (final point in hexPoints) {
      canvas.drawLine(center, point, thinPaint);
    }
    
    // 绘制内部蜘蛛网同心六边形（2层）
    final webPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    for (double scale in [0.33, 0.66]) {
      final innerPath = Path();
      // 计算这一层的顶点
      final List<Offset> layerPoints = [];
      for (int i = 0; i < 6; i++) {
        layerPoints.add(Offset(
          centerX + (hexPoints[i].dx - centerX) * scale,
          centerY + (hexPoints[i].dy - centerY) * scale,
        ));
      }

      innerPath.moveTo(layerPoints[0].dx, layerPoints[0].dy);
      
      for (int i = 0; i < 6; i++) {
        // 当前点
        final p1 = layerPoints[i];
        // 下一个点
        final p2 = layerPoints[(i + 1) % 6];
        
        // 计算中点
        final midX = (p1.dx + p2.dx) / 2;
        final midY = (p1.dy + p2.dy) / 2;
        
        // 计算控制点：向中心凹陷
        // 简单的做法是取中点和中心的连线上的某一点
        // 凹陷程度因子 (0.0 = 直线, 1.0 = 到中心)
        const curveFactor = 0.15; 
        final controlX = midX + (centerX - midX) * curveFactor;
        final controlY = midY + (centerY - midY) * curveFactor;
        
        innerPath.quadraticBezierTo(controlX, controlY, p2.dx, p2.dy);
      }
      // innerPath.close(); // quadraticBezierTo 已经闭合回去了（最后一个点连回第一个点）
      canvas.drawPath(innerPath, webPaint);
    }
    
    // 中心小圆点
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SpiderWebIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

