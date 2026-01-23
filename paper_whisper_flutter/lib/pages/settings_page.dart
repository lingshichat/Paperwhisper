import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException if any
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/update_service.dart';
import '../utils/platform_utils.dart';
import '../widgets/update_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/slide_page_route.dart';
import '../widgets/visual_effects.dart';
import '../pages/trash_page.dart';
import '../services/storage_service.dart';
import 'sync_settings_page.dart';
import 'security_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  bool _isCheckingUpdate = false;
  String? _currentVersion;
  String _storageInfo = '计算中...';
  String _currentDataPath = '';
  String _internalStats = '';
  bool _hasInternalClutter = false;
  
  // Permission State
  Map<String, PermissionStatus> _permStatuses = {};
  String _permSummary = '检测中...';
  bool _isAllGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStorageInfo();
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
       _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    // Check key permissions
    final pStorage = await Permission.manageExternalStorage.status;
    final pPhotos = await Permission.photos.status; // Android 13+ specific usually, or generic
    final pNotification = await Permission.notification.status;
    
    setState(() {
      _permStatuses = {
        'storage': pStorage,
        'photos': pPhotos,
        'notification': pNotification,
      };
      
      _isAllGranted = pStorage.isGranted && pNotification.isGranted; // Storage is critical
      
      int grantedCount = 0;
      if (pStorage.isGranted) grantedCount++;
      if (pPhotos.isGranted || pPhotos.isLimited) grantedCount++;
      if (pNotification.isGranted) grantedCount++;
      
      _permSummary = "权限状态: $grantedCount / 3 已获取";
    });
  }

  Future<void> _loadStorageInfo() async {
    final service = StorageService();
    final cacheSize = await service.getCacheSize();
    final dataSize = await service.getUserDataSize();
    final path = await service.getDataPath();
    final total = cacheSize + dataSize;
    
    // Internal Check
    final internal = await service.getInternalStorageStats();
    final docSize = internal['doc'] as int? ?? 0;
    final supportSize = internal['support'] as int? ?? 0;
    final clutterSize = internal['clutter'] as int? ?? 0;
    
    // Check clutter: if using External path, but Internal has > 1MB *clutter* data (excl system files)
    bool usingExternal = path.contains('/storage/emulated/0'); // Simple heuristic
    bool hasClutter = usingExternal && clutterSize > 1024 * 1024; // >1MB clutter only

    if (mounted) {
      setState(() {
         _storageInfo = "内容占用: ${_formatSize(total)} (缓存: ${_formatSize(cacheSize)})";
         _currentDataPath = path;
         _internalStats = "Doc: ${_formatSize(docSize)} / Support: ${_formatSize(supportSize)}";
         _hasInternalClutter = hasClutter;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    // 获取主题信息，保持与 Sidebar 一致的设计语言
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;

    // 颜色定义 (参考 SidebarWidget)
    final Color titleColor = isSeaFlower
        ? const Color(0xFF880E4F)
        : (isMidnight ? const Color(0xFFe6edf3) : const Color(0xFFEEFFEB));
        
    final Color textColor = isSeaFlower
        ? const Color(0xFFAD1457)
        : (isMidnight ? const Color(0xFFc9d1d9) : const Color(0xFFD7CCC8));

    final Shadow titleShadow = isSeaFlower
        ? const Shadow(
            color: Color.fromRGBO(255, 255, 255, 0.5),
            offset: Offset(0, 1),
            blurRadius: 2,
          )
        : const Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            offset: Offset(0, 2),
            blurRadius: 4,
          );

    // Scaffold 内容
    Widget content = Scaffold(
      backgroundColor: Colors.transparent, // 让底层背景透出来
      appBar: AppBar(
        title: Text(
          '设置',
          style: GoogleFonts.notoSerifSc(
            color: titleColor,
            fontWeight: FontWeight.bold,
            shadows: [titleShadow],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildList(context, isSeaFlower, isMidnight, textColor, settings),
    );
    
    // 返回带背景和特效的 Stack
    return Stack(
      children: [
        // 1. 背景
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),
        
        // 2. Visual Effects
        if (isSeaFlower) Positioned.fill(child: const PetalRainWidget()),
        if (isMidnight) Positioned.fill(child: const StarrySkyWidget()),
        
        // 3. 内容
        Positioned.fill(child: content),
      ],
    );
  }

  Widget _buildList(BuildContext context, bool isSeaFlower, bool isMidnight, Color textColor, SettingsProvider settings) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. 核心服务 (Core)
        _buildSectionHeader('账号与云同步', textColor),
        _buildGroupContainer(
          isSeaFlower, isMidnight,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.cloud_sync_outlined,
              title: '数据同步',
              subtitle: _getSyncStatusText(context),
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(page: SyncSettingsPage()),
                );
              },
            ),
          ]
        ),
        const SizedBox(height: 24),

        // 2. 外观与体验 (Appearance & Experience)
        _buildSectionHeader('外观与体验', textColor),
        _buildGroupContainer(
          isSeaFlower, isMidnight,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.palette_outlined,
              title: '主题风格',
              subtitle: _getThemeName(settings.currentTheme),
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () => _showThemePicker(context, settings),
            ),
             _buildDivider(isSeaFlower, isMidnight),
             _buildSwitchItem(
               context: context,
               icon: Icons.brightness_auto_outlined,
               title: '跟随系统深色模式',
               subtitle: '开启后，深色模式自动使用午夜星尘主题',
               value: settings.followSystemTheme,
               onChanged: (val) => settings.setFollowSystemTheme(val),
               isSeaFlower: isSeaFlower,
               isMidnight: isMidnight,
               textColor: textColor,
             ),
            _buildDivider(isSeaFlower, isMidnight),
            _buildSettingsItem(
              context: context,
              icon: Icons.start_outlined,
              title: '启动页',
              subtitle: _getStartupPageName(settings.startupPage),
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () => _showStartupPagePicker(context, settings),
            ),
             _buildDivider(isSeaFlower, isMidnight),
             // Compatibility Mode Switch
             _buildSwitchItem(
               context: context,
               icon: Icons.layers_clear_outlined,
               title: '兼容模式',
               subtitle: '隐藏信纸横线，仅显示文字',
               value: settings.compatibilityMode,
               onChanged: (val) => settings.setCompatibilityMode(val),
               isSeaFlower: isSeaFlower,
               isMidnight: isMidnight,
               textColor: textColor,
             )
          ]
        ),
        const SizedBox(height: 24),

        // 3. 数据与隐私 (Data & Privacy)
        _buildSectionHeader('数据与隐私', textColor),
        _buildGroupContainer(
          isSeaFlower, isMidnight,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.lock_outline,
              title: '密码锁',
              subtitle: '指纹与密码保护',
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(page: const SecuritySettingsPage()),
                );
              },
            ),
            _buildDivider(isSeaFlower, isMidnight),
            _buildSettingsItem(
              context: context,
              icon: _isAllGranted ? Icons.verified_user_outlined : Icons.gpp_maybe_outlined,
              title: '系统权限管理',
              subtitle: _permSummary,
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () => _showPermissionManager(context),
            ),
            _buildDivider(isSeaFlower, isMidnight),
            _buildSettingsItem(
               context: context,
               icon: Icons.sd_storage_outlined,
               title: '存储空间管理',
               subtitle: _storageInfo, 
               isSeaFlower: isSeaFlower,
               isMidnight: isMidnight,
               textColor: textColor,
               onTap: () => _showStorageManager(context, isSeaFlower, isMidnight, textColor),
            ),
            _buildDivider(isSeaFlower, isMidnight),
            _buildSettingsItem(
              context: context,
              icon: Icons.delete_outline,
              title: '回收站',
              subtitle: '找回误删的日记',
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(page: TrashPage()),
                );
              },
            ),
          ]
        ),
        const SizedBox(height: 24),

        // 4. 帮助与反馈 (Help & Feedback)
        _buildSectionHeader('帮助与反馈', textColor),
        _buildGroupContainer(
          isSeaFlower, isMidnight,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.help_outline,
              title: '常见问题',
              subtitle: '查看使用指南与疑问解答',
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () => _launchUrl('https://lingshichat.feishu.cn/docx/JvzDdhLXEo3OVaxWEc9cygDqnMc?from=from_copylink'),
            ),
            _buildDivider(isSeaFlower, isMidnight),
            _buildSettingsItem(
              context: context,
              icon: Icons.feedback_outlined,
              title: '意见反馈',
              subtitle: '提交Bug或功能建议',
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () => _launchUrl('https://lingshichat.feishu.cn/share/base/form/shrcnx9xnwJU6cxmz6F5tLNQzi2'),
            ),
          ]
        ),
        const SizedBox(height: 24),

        // 5. 关于 (About)
        _buildSectionHeader('关于', textColor),
        _buildGroupContainer(
          isSeaFlower, isMidnight,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.system_update_outlined,
              title: '检测更新',
              subtitle: _isCheckingUpdate ? '检测中...' : (_currentVersion != null ? 'v$_currentVersion' : '点击检查新版本'),
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              isLoading: _isCheckingUpdate,
              onTap: _isCheckingUpdate ? () {} : () => _checkForUpdate(context),
            ),
            _buildDivider(isSeaFlower, isMidnight),
            _buildSettingsItem(
              context: context,
              icon: Icons.description_outlined,
              title: '用户协议',
              subtitle: '查阅用户服务协议',
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () => _launchUrl('https://lingshichat.feishu.cn/docx/ODY0dLSF4okfuzximQuctlMon7g?from=from_copylink'),
            ),
            _buildDivider(isSeaFlower, isMidnight),
            _buildSettingsItem(
              context: context,
              icon: Icons.privacy_tip_outlined,
              title: '隐私政策',
              subtitle: '了解不仅限于数据的隐私保护',
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () => _launchUrl('https://lingshichat.feishu.cn/docx/Gd6sdvdmRonHO9x6fMccUr3qnXg?from=from_copylink'),
            ),
            _buildDivider(isSeaFlower, isMidnight),
            _buildSettingsItem(
              context: context,
              icon: Icons.info_outline,
              title: '关于纸语PaperWhisper',
              subtitle: '纸本无言，因你而语',
              isSeaFlower: isSeaFlower,
              isMidnight: isMidnight,
              textColor: textColor,
              onTap: () {
                // TODO: Show About Dialog
              },
            ),
          ]
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- Helpers ---

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.notoSerifSc(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildGroupContainer(bool isSeaFlower, bool isMidnight, {required List<Widget> children}) {
     final BoxDecoration decoration = BoxDecoration(
      color: isSeaFlower 
          ? Colors.white.withValues(alpha: 0.3) 
          : (isMidnight ? const Color(0xFF161b22).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.03)),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isSeaFlower 
            ? Colors.white.withValues(alpha: 0.4) 
            : (isMidnight ? const Color(0xFF30363d) : Colors.white.withValues(alpha: 0.1)),
      ),
      boxShadow: [
        BoxShadow(
          color: isSeaFlower ? const Color(0xFFF48FB1).withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ],
    );

    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias, // Ensure children don't overflow rounded corners
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider(bool isSeaFlower, bool isMidnight) {
    return Divider(
      height: 1, 
      thickness: 1, 
      color: isSeaFlower 
         ? Colors.white.withOpacity(0.3) 
         : (isMidnight ? const Color(0xFF30363d) : Colors.grey.withOpacity(0.1)),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSeaFlower,
    required bool isMidnight,
    required Color textColor,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    // Note: Background is now handled by Group Container. Inner items are transparent.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: textColor.withOpacity(0.8), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 16,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 13,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor.withOpacity(0.6)),
                  ),
                )
              else
                Icon(Icons.arrow_forward_ios, color: textColor.withOpacity(0.4), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isSeaFlower,
    required bool isMidnight,
    required Color textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: textColor.withOpacity(0.8), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 16,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 13,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: isSeaFlower ? const Color(0xFFEC407A) : (isMidnight ? const Color(0xFF7986cb) : const Color(0xFF8D6E63)),
              activeTrackColor: isSeaFlower ? const Color(0xFFF48FB1).withOpacity(0.3) : const Color(0xFFD7CCC8).withOpacity(0.3),
            )
          ],
        ),
      ),
    );
  }

  // --- Existing View Logic ---

  void _showPermissionManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildSkeuomorphicBottomSheet(
        context,
        title: '应用权限管理',
        children: [
           _buildPermissionRow(
             context, 
             '文件存储 (核心)', 
             '用于日记数据的读取与备份', 
             Icons.folder_copy_outlined,
             _permStatuses['storage'], 
             Permission.manageExternalStorage,
             isCritical: true,
           ),
           Divider(color: const Color(0xFF5D4037).withOpacity(0.1), height: 1),
           _buildPermissionRow(
             context, 
             '相册访问', 
             '用于在日记中插入图片', 
             Icons.photo_library_outlined, 
             _permStatuses['photos'], 
             Permission.photos
           ),
           Divider(color: const Color(0xFF5D4037).withOpacity(0.1), height: 1),
           _buildPermissionRow(
             context, 
             '通知提醒', 
             '显示数据同步进度与状态', 
             Icons.notifications_outlined, 
             _permStatuses['notification'], 
             Permission.notification
           ),
           const SizedBox(height: 20),
           SkeuomorphicDialogButton(
             label: '前往系统设置页',
             isPrimary: false,
             onPressed: () {
               Navigator.pop(ctx);
               openAppSettings();
             },
           )
        ],
      )
    );
  }

  Widget _buildPermissionRow(BuildContext context, String title, String subtitle, IconData icon, PermissionStatus? status, Permission perm, {bool isCritical = false}) {
     bool isGranted = status?.isGranted == true;
     bool isLimited = status?.isLimited == true; 
     
     Color statusColor = isGranted ? Colors.green : (isCritical ? Colors.red : Colors.orange.shade800);
     String statusText = isGranted ? '已获取' : (isLimited ? '部分允许' : '未获取');
     
     return ListTile(
       contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
       leading: Container(
         padding: const EdgeInsets.all(8),
         decoration: BoxDecoration(
           color: const Color(0xFF5D4037).withOpacity(0.05),
           borderRadius: BorderRadius.circular(8),
         ),
         child: Icon(icon, color: const Color(0xFF5D4037), size: 20),
       ),
       title: Text(title, style: GoogleFonts.notoSerifSc(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold, fontSize: 15)),
       subtitle: Text(subtitle, style: GoogleFonts.notoSerifSc(color: const Color(0xFF5D4037).withOpacity(0.6), fontSize: 11)),
       trailing: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           if (isGranted)
              Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold))
           else
             TextButton(
               style: TextButton.styleFrom(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                 backgroundColor: statusColor.withOpacity(0.1),
                 minimumSize: const Size(60, 28),
                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
               ),
               onPressed: () async {
                 Navigator.pop(context);
                 
                 final isHarmony = await PlatformUtils.isHarmonyOS();
                 if (isHarmony) {
                    SkeuomorphicToast.info(context, '正在跳转设置页...');
                    await openAppSettings();
                 } else {
                    final newStatus = await perm.request();
                    if (context.mounted) {
                       if (newStatus.isGranted) {
                         SkeuomorphicToast.success(context, '授权成功');
                       } else if (newStatus.isPermanentlyDenied) {
                         SkeuomorphicToast.warning(context, '请在设置中手动开启');
                         openAppSettings();
                       } else {
                         SkeuomorphicToast.info(context, '权限未授予');
                       }
                       // Check again
                       await Future.delayed(const Duration(milliseconds: 500));
                       _checkAllPermissions();
                    }
                 }
               },
               child: Text('去授权', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
             )
         ],
       ),
     );
  }

  /// 手动检测更新
  Future<void> _checkForUpdate(BuildContext context) async {
    setState(() => _isCheckingUpdate = true);
    try {
      final updateService = UpdateService();
      final currentVersion = await updateService.getCurrentVersion();
      setState(() => _currentVersion = currentVersion);
      final updateInfo = await updateService.checkForUpdate();
      if (!mounted) return;
      if (updateInfo != null) {
        UpdateDialog.show(
          context,
          updateInfo: updateInfo,
          currentVersion: currentVersion,
        );
      } else {
        SkeuomorphicToast.success(context, '已是最新版本 ✔');
      }
    } catch (e) {
      if (!mounted) return;
      SkeuomorphicToast.error(context, '检测更新失败，请检查网络');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      // 1. 优先尝试 "应用内浏览器" (Chrome Custom Tabs / Safari View Controller)
      // 这通常提供最佳体验（共享 Cookie，支持上传等）
      // 但其表现依赖于系统默认浏览器（如 Chrome, Edge 等支持较好；部分国产浏览器可能会直接跳出）
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(
          showTitle: true,
        ),
      );

      if (!launched) {
        // 2. 尝试使用 WebView 模式 (传统 WebView)
        // 保证在 App 内部打开
        launched = await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(enableJavaScript: true, enableDomStorage: true)
        );
      } else {
         return; 
      }
      
      if (!launched) {
        // 3. 最后降级去系统浏览器
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (mounted) {
             SkeuomorphicToast.error(context, '无法打开链接');
          }
        }
      }
    } catch (e) {
      if (mounted) {
         // 尝试降级打开
         try {
           await launchUrl(uri, mode: LaunchMode.externalApplication);
         } catch (e2) {
           SkeuomorphicToast.error(context, '无法打开链接: $e');
         }
      }
    }
  }

  String _getSyncStatusText(BuildContext context) {
    // 监听 SyncProvider 状态
    final syncProvider = Provider.of<SyncProvider>(context);
    if (!syncProvider.isConfigured) return '未配置';
    if (syncProvider.status == SyncStatus.syncing) return '同步中...';
    if (syncProvider.status == SyncStatus.failed) return '同步失败';
    if (syncProvider.lastSyncTime != null) {
      return '上次同步: ${_formatTime(syncProvider.lastSyncTime!)}';
    }
    return '已开启';
  }

  String _formatTime(DateTime time) {
    return "${time.year}-${time.month}-${time.day} ${time.hour}:${time.minute}";
  }

  // --- Theme & Storage Helpers (Unchanged Logic, just helper methods) ---

  String _getThemeName(String theme) {
    switch (theme) {
      case AppTheme.themeSeaFlower: return '海底花海';
      case AppTheme.themeMidnight: return '午夜星尘';
      case AppTheme.themeAmberLens: return '琥珀光圈';
      default: return '复古纸张';
    }
  }

  String _getStartupPageName(String page) {
    switch (page) {
      case 'moments': return '随心记';
      case 'writer': return '专注书写';
      case 'last': return '恢复上次状态';
      default: return '专注书写';
    }
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildSkeuomorphicBottomSheet(
        context,
        title: '选择主题',
        children: [
          _buildRadioItem(ctx, '复古纸张', 'default', settings.currentTheme, (val) => settings.setTheme(val), closeOnSelect: false),
          _buildRadioItem(ctx, '海底花海', 'sea_flower', settings.currentTheme, (val) => settings.setTheme(val), closeOnSelect: false),
          _buildRadioItem(ctx, '午夜星尘', 'midnight', settings.currentTheme, (val) => settings.setTheme(val), closeOnSelect: false),
          _buildRadioItem(ctx, '琥珀光圈', 'amber_lens', settings.currentTheme, (val) => settings.setTheme(val), closeOnSelect: false),
        ]
      )
    );
  }

  void _showStartupPagePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildSkeuomorphicBottomSheet(
        context,
        title: '选择启动页',
        children: [
          _buildRadioItem(ctx, '专注书写', 'writer', settings.startupPage, (val) => settings.setStartupPage(val)),
          _buildRadioItem(ctx, '随心记', 'moments', settings.startupPage, (val) => settings.setStartupPage(val)),
        ]
      )
    );
  }

  void _showStorageManager(BuildContext context, bool isSeaFlower, bool isMidnight, Color ignoredTextColor) {
    const Color sheetTextColor = Color(0xFF5D4037);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildSkeuomorphicBottomSheet(
        context,
        title: '用户数据管理',
        children: [
           ListTile(
             leading: const Icon(Icons.delete_sweep, color: sheetTextColor),
             title: Text('清理无用图片 (深度清理)', style: GoogleFonts.notoSerifSc(color: sheetTextColor)),
             subtitle: Text('扫描并删除未被任何随心记引用的冗余图片', style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.6), fontSize: 12)),
             onTap: () async {
               Navigator.pop(ctx);
               SkeuomorphicToast.info(context, '正在深度清理...');
               int freed = await StorageService().cleanOrphanImages();
               await _loadStorageInfo(); // Refresh
               if (context.mounted) {
                   SkeuomorphicToast.success(context, '清理完成，释放 ${_formatSize(freed)} 空间');
               }
             },
           ),
           Divider(color: sheetTextColor.withOpacity(0.1)),
           ListTile(
             leading: const Icon(Icons.cleaning_services, color: sheetTextColor),
             title: Text('立即清理缓存', style: GoogleFonts.notoSerifSc(color: sheetTextColor)),
             subtitle: Text('清理产生的临时文件 (不影响数据)', style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.6), fontSize: 12)),
             onTap: () async {
               Navigator.pop(ctx);
               await StorageService().cleanTemporaryCache();
               await _loadStorageInfo(); // Refresh
               if (context.mounted) {
                   SkeuomorphicToast.success(context, '缓存已清理');
               }
             },
           ),
           const SizedBox(height: 10),
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.black.withOpacity(0.05),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.black.withOpacity(0.05)),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                      Icon(Icons.perm_device_information, size: 16, color: sheetTextColor.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text('系统运行数据 (App必须)', style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 13)),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Text(
                   '包含字体缓存 (Support) 及 App 资源文件 (Doc)。\n此部分数据维持 App 正常运行，无需清理。',
                   style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.6), fontSize: 11, height: 1.4),
                 ),
                 const SizedBox(height: 8),
                 Divider(color: Colors.black.withOpacity(0.05), height: 1),
                 const SizedBox(height: 8),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('占用空间: $_internalStats', style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.5), fontSize: 10)),
                   ],
                 ),
                   if (_hasInternalClutter)
                     Padding(
                       padding: const EdgeInsets.only(top: 8),
                       child: InkWell(
                         onTap: () async {
                            Navigator.pop(ctx);
                            SkeuomorphicToast.info(context, '正在清理私有残留...');
                            int freed = await StorageService().cleanInternalClutter();
                            await _loadStorageInfo();
                            if (context.mounted) SkeuomorphicToast.success(context, '清理了 ${_formatSize(freed)} 旧数据');
                         },
                         child: Text('>> 发现残留数据，点击清理', style: GoogleFonts.notoSerifSc(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                       ),
                     ),
                   if (_internalStats.contains('Support') && !(_internalStats.contains('0 B')))
                     Padding(
                       padding: const EdgeInsets.only(top: 8),
                       child: InkWell(
                         onTap: () async {
                            Navigator.pop(ctx);
                            SkeuomorphicToast.info(context, '正在清理字体缓存...');
                            int freed = await StorageService().cleanFontCache();
                            await _loadStorageInfo();
                            if (context.mounted) SkeuomorphicToast.success(context, '字体缓存已清除 (下次启动将自动重新下载)'); 
                         },
                         child: Text('>> 强制清除字体缓存 (修复显示异常)', style: GoogleFonts.notoSerifSc(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 10)),
                       ),
                     )
               ],
             ),
           )
        ]
      )
    );
  }
  
  Widget _buildSkeuomorphicBottomSheet(BuildContext context, {required String title, required List<Widget> children}) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;

    // --- Dialog Style Colors (Directly matching SkeuomorphicDialog) ---
    Color bgColor;
    Color titleColor;
    Color tapeColor;
    List<BoxShadow> shadows;
    BoxBorder? border;

    if (theme == AppTheme.themeSeaFlower) {
      // Sea Flower: Solid Pink Paper
      bgColor = const Color(0xFFFCE4EC);
      titleColor = const Color(0xFF880E4F);
      tapeColor = const Color(0xFFF8BBD0);
      shadows = [const BoxShadow(color: Color.fromRGBO(173, 20, 87, 0.25), blurRadius: 20, offset: Offset(0, -5))];
      border = Border.all(color: const Color(0xFFF48FB1), width: 1);
    } else if (theme == AppTheme.themeMidnight) {
      // Midnight: Solid Dark Gray
      bgColor = const Color(0xFF161b22);
      titleColor = const Color(0xFFe6edf3);
      tapeColor = const Color(0xFF30363d);
      shadows = [const BoxShadow(color: Colors.black, blurRadius: 20, offset: Offset(0, -5))];
      border = Border.all(color: const Color(0xFF30363d), width: 1);
    } else if (theme == AppTheme.themeAmberLens) {
        // Amber: Solid Black/Gray
        bgColor = const Color(0xFF1E1E1E);
        titleColor = const Color(0xFFE0E0E0);
        tapeColor = const Color(0xFFFF9800).withOpacity(0.5);
        shadows = [const BoxShadow(color: Colors.black, blurRadius: 20, offset: Offset(0, -5))];
        border = Border.all(color: const Color(0xFFFF9800).withOpacity(0.3), width: 1);
    } else {
      // Vintage: Solid Paper + Tape
      bgColor = const Color(0xFFF4ECD8);
      titleColor = const Color(0xFF5D4037);
      tapeColor = const Color(0xD9E0E0E0);
      shadows = [const BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.2), blurRadius: 20, offset: Offset(0, -5))];
      border = null; // No border for vintage paper look
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: shadows,
        border: border,
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Tape Decoration (Top Center)
          if (theme == AppTheme.themeDefault)
            Positioned(
              top: -15,
              child: Transform.rotate(
                angle: -0.02,
                child: Container(
                  width: 80,
                  height: 25,
                  decoration: BoxDecoration(
                    color: tapeColor,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ),
            
          // Handle for other themes
           if (theme != AppTheme.themeDefault)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: titleColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(top: 40), // Space for tape/handle
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch items
              children: [
                Text(
                  title, 
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: titleColor
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRadioItem(BuildContext context, String label, String value, String groupValue, Function(String) onChanged, {bool closeOnSelect = true}) {
    return _buildOptionTile(context, label, value, groupValue, onChanged, closeOnSelect: closeOnSelect);
  }

  Widget _buildOptionTile(BuildContext context, String label, String value, String groupValue, Function(String) onChanged, {bool closeOnSelect = true}) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final isSelected = value == groupValue;

    // --- Button Style Colors (Matching SkeuomorphicDialogButton) ---
    Color bgColor;
    Color textColor;
    BoxShadow? shadow;
    Border? border;

    if (theme == AppTheme.themeSeaFlower) {
      if (isSelected) {
        bgColor = const Color(0xFFEC407A); // Primary Pink
        textColor = Colors.white;
        shadow = const BoxShadow(color: Color.fromRGBO(236, 64, 122, 0.4), offset: Offset(0, 4), blurRadius: 8);
      } else {
        bgColor = Colors.white.withOpacity(0.5);
        textColor = const Color(0xFFAD1457);
        border = Border.all(color: const Color(0xFFF48FB1).withOpacity(0.5));
      }
    } else if (theme == AppTheme.themeMidnight) {
      if (isSelected) {
        bgColor = const Color(0xFF5C6BC0); // Primary Indigo
        textColor = const Color(0xFFe6edf3);
        shadow = const BoxShadow(color: Color.fromRGBO(92, 107, 192, 0.4), offset: Offset(0, 4), blurRadius: 8);
      } else {
        bgColor = const Color(0xFF21262d);
        textColor = const Color(0xFF8b949e);
        border = Border.all(color: const Color(0xFF30363d));
      }
    } else if (theme == AppTheme.themeAmberLens) {
        if (isSelected) {
            bgColor = const Color(0xFFFF9800);
            textColor = const Color(0xFFE0E0E0);
             shadow = const BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8);
        } else {
            bgColor = const Color(0xFF2C2C2C);
            textColor = const Color(0xFF9E9E9E);
             border = Border.all(color: const Color(0xFFFF9800).withOpacity(0.3));
        }
    } else {
      // Vintage
      if (isSelected) {
        bgColor = const Color(0xFF5D4037); // Primary Brown
        textColor = const Color(0xFFF4ECD8);
        shadow = const BoxShadow(color: Color.fromRGBO(93, 64, 55, 0.4), offset: Offset(0, 4), blurRadius: 8);
      } else {
        bgColor = const Color(0xFFEFEBE9);
        textColor = const Color(0xFF8D6E63);
        shadow = const BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), offset: Offset(0, 2), blurRadius: 4);
      }
    }

    return GestureDetector(
      onTap: () {
        onChanged(value);
        if (closeOnSelect) {
           Navigator.pop(context);
        }
        // Play click sound?
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4), // Dialog style small radius
          boxShadow: shadow != null ? [shadow] : null,
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center text like a button
          children: [
             Text(
               label, 
               style: GoogleFonts.notoSerifSc(
                 fontSize: 16, 
                 color: textColor, 
                 fontWeight: FontWeight.bold // Always bold like buttons
               )
             ),
             // Optional: Add Check icon if selected? 
             // Dialog buttons usually don't have check icons, just distinct style.
             // But for selection, a check might be nice.
             if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, size: 18, color: textColor.withOpacity(0.8)),
             ]
          ],
        ),
      ),
    );
  }
}
