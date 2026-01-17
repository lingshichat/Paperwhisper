import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';
import '../models/diary_entry.dart';
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
import '../widgets/skeuomorphic_search_bar.dart'; // Added
import '../widgets/skeuomorphic_toast.dart';
import 'editor_page.dart';
import 'diary_card.dart';
import 'sync_settings_page.dart';
import '../widgets/slide_page_route.dart';
import '../widgets/unfold_page_route.dart';
import '../widgets/paper_fold_page_route.dart'; // LetterFoldPageRoute
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';
import '../models/update_info.dart';
import '../services/update_service.dart';
import '../utils/platform_utils.dart';

class DiaryListPage extends StatefulWidget {
  const DiaryListPage({super.key});

  @override
  State<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends State<DiaryListPage> {
  String _searchQuery = '';
  bool _isSearching = false; // Added search state
  // Removed duplicate declaration
  
  @override
  void initState() {
    super.initState();
    _checkAndroidPermissions();
    _checkAndShowAnnouncement(); // Check for version update and show announcement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRemoteUpdate();
      // Ensure data is refreshed whenever this page is initialized (e.g. after pushReplacement from Moments)
      Provider.of<DiaryProvider>(context, listen: false).loadEntries();
    });
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
            : const Color(0xFF8D6E63)); // Vintage/Default Secondary

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
      // 点击卡片：使用展开动画
      Navigator.push(
        context, 
        UnfoldPageRoute(page: EditorPage(entry: entry), sourceRect: cardRect),
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
        final Widget contentArea = _buildContentArea(context, theme, !isDesktop);

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
            drawerScrimColor: isSeaFlower ? Colors.transparent : Colors.black54, // 海底花海去遮罩，透出背景
            drawer: const Drawer(
              width: 300,
              elevation: 0, 
              backgroundColor: Colors.transparent, 
              child: SidebarWidget(),
            ),
            // Mobile Body
            body: Stack(
              children: [
                Container(decoration: AppTheme.getBackground(theme)),
                if (theme == AppTheme.themeSeaFlower) const PetalRainWidget(),
                if (theme == AppTheme.themeMidnight) const StarrySkyWidget(),
                contentArea,
              ],
            ),
             floatingActionButton: FloatingActionButton(
               backgroundColor: isSeaFlower || theme == AppTheme.themeMidnight || theme == AppTheme.themeAmberLens ? Colors.transparent : const Color(0xFFC0392B),
               elevation: (isSeaFlower || theme == AppTheme.themeMidnight) ? 0 : 6, 
               focusElevation: (isSeaFlower || theme == AppTheme.themeMidnight) ? 0 : 6,
               hoverElevation: (isSeaFlower || theme == AppTheme.themeMidnight) ? 0 : 8,
               highlightElevation: (isSeaFlower || theme == AppTheme.themeMidnight) ? 0 : 12,
               onPressed: () => _openEditor(null),
               child: Container(
                 width: 56, 
                 height: 56,
                 decoration: isSeaFlower 
                   ? const BoxDecoration(
                       shape: BoxShape.circle,
                       gradient: LinearGradient(
                         begin: Alignment.topLeft,
                         end: Alignment.bottomRight,
                         colors: [Color(0xFFF8BBD0), Color(0xFFF06292)],
                       ),
                       boxShadow: [
                         BoxShadow(
                           color: Color.fromRGBO(240, 98, 146, 0.5),
                           blurRadius: 12,
                           offset: Offset(0, 4),
                         )
                       ]
                     )
                   : (theme == AppTheme.themeMidnight 
                       ? const BoxDecoration(
                           shape: BoxShape.circle,
                           gradient: LinearGradient(
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                             colors: [Color(0xFF7986cb), Color(0xFF303f9f)],
                           ),
                           boxShadow: [
                             BoxShadow(
                               color: Color.fromRGBO(121, 134, 203, 0.5), // Indigo Glow
                               blurRadius: 15,
                               offset: Offset(0, 0),
                               spreadRadius: 2,
                             )
                           ]
                         )
                       : (theme == AppTheme.themeAmberLens
                           ? const BoxDecoration(
                               shape: BoxShape.circle, // 确保按圆形渲染
                               gradient: LinearGradient(
                                 begin: Alignment.topLeft,
                                 end: Alignment.bottomRight,
                                 colors: [Color(0xFFFFB74D), Color(0xFFF57C00)], // Amber Light to Dark
                               ),
                               boxShadow: [
                                 BoxShadow(
                                   color: Color.fromRGBO(255, 152, 0, 0.5), // Amber Glow
                                   blurRadius: 15,
                                   offset: Offset(0, 0),
                                   spreadRadius: 2,
                                 )
                               ]
                             )
                           : null)),
                 child: Icon(Icons.edit, color: Colors.white, size: (isSeaFlower || theme == AppTheme.themeMidnight) ? 28 : 24),
               ),
             ),
          );
        }
      },
    );
  }
  
  Widget _buildContentArea(BuildContext context, String theme, bool isMobile) {
    final diaryProvider = Provider.of<DiaryProvider>(context);
    
    // Filter
    final list = diaryProvider.entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.title.contains(_searchQuery) || e.content.contains(_searchQuery) || e.dateString.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Mobile Header
        if (isMobile)
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
                               IconButton(
                                 icon: Icon(Icons.menu, color: headerColors['iconColor']),
                                 onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                               ),
                               Expanded(
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   crossAxisAlignment: CrossAxisAlignment.baseline,
                                   textBaseline: TextBaseline.alphabetic,
                                   children: [
                                     Text(
                                       '纸语',
                                       style: GoogleFonts.notoSerifSc(
                                         fontSize: 18,
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
                                     const SizedBox(width: 6),
                                     Text(
                                       'PaperWhisper',
                                       style: GoogleFonts.notoSerifSc(
                                         fontSize: 10,
                                         color: headerColors['subtitleColor'],
                                       ),
                                     ),
                                   ],
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

        
        // Waterfall List with Book Flip Refresh
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
              
              // 检查 WebDAV 是否已配置
              if (!syncProvider.isConfigured) {
                // 显示提示并引导用户配置
                if (mounted) {
                  _showWebDavConfigPrompt();
                }
                return;
              }
              
              // 触发同步
              await syncProvider.sync(context: context);
            },
            child: list.isEmpty 
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: _buildEmptyState(theme),
                    ),
                  )
                : _buildWaterfallGrid(context, list, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String theme) {
    // 使用侧栏文字颜色 - 在深色背景上可见的浅色
    // 参考 web端 CSS: --sidebar-text: #d7ccc8 (浅米色)
    final Color emptyTextColor;
    final Color accentColor;
    
    switch (theme) {
      case AppTheme.themeMidnight:
        emptyTextColor = const Color(0xFFc9d1d9); // 浅灰白色
        accentColor = const Color(0xFF7986cb);    // 靛蓝色
        break;
      case AppTheme.themeSeaFlower:
        emptyTextColor = const Color(0xFFC2185B); // 洋红色
        accentColor = const Color(0xFFF50057);    // 玫瑰红
        break;
      case AppTheme.themeAmberLens:
        emptyTextColor = const Color(0xFF9E9E9E); // Grey
        accentColor = const Color(0xFFFF9800);    // Amber
        break;
      default: // vintage/default
        emptyTextColor = const Color(0xFFd7ccc8); // 浅米色 (与侧栏文字一致)
        accentColor = const Color(0xFFc0392b);    // 红色
    }
    
    return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           // 图标
           Opacity(
             opacity: 0.5,
             child: Text(
               '🕸️', 
               style: TextStyle(
                 fontSize: 64,
                 color: emptyTextColor,
               ),
             ),
           ),
           const SizedBox(height: 20),
           // 提示文字 - 使用浅色以在深色背景上可见
           Opacity(
             opacity: 0.8,
             child: Text(
               _searchQuery.isNotEmpty 
                 ? '没有找到关于"$_searchQuery"的回忆呢...'
                 : '这里似乎落了一层灰，等待你来翻阅',
               textAlign: TextAlign.center,
               style: GoogleFonts.notoSerifSc(
                 color: emptyTextColor,
                 fontSize: 16,
                 fontStyle: FontStyle.italic,
                 letterSpacing: 2,
               ),
             ),
           ),
           // 只在非搜索模式下显示"写一篇"按钮
           if (_searchQuery.isEmpty) ...[
             const SizedBox(height: 30),
             // "去写一篇"按钮 - 参考web端: 底部虚线边框样式
             GestureDetector(
               onTap: () => _openEditor(null),
               child: MouseRegion(
                 cursor: SystemMouseCursors.click,
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           '去擦拭灰尘 (写一篇)',
                           style: GoogleFonts.notoSerifSc(
                             color: accentColor,
                             fontSize: 14,
                           ),
                         ),
                         const SizedBox(width: 4),
                         Text(
                           '→',
                           style: TextStyle(
                             color: accentColor,
                             fontSize: 14,
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 2),
                     // 虚线边框
                     CustomPaint(
                       size: const Size(150, 1),
                       painter: DashedLinePainter(color: accentColor),
                     ),
                   ],
                 ),
               ),
             ),
           ],
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
}
