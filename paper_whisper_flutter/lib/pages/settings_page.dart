import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../models/sync_trust_snapshot.dart';
import '../models/update_info.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/update_service.dart';
import '../services/moment_service.dart';
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
import 'premium_membership_page.dart'; // Import Premium Page
import 'about_page.dart';
import '../services/payment_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  bool _isCheckingUpdate = false;
  String? _currentVersion;
  String _storageInfo = '计算中...';
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
    final pPhotos =
        await Permission
            .photos
            .status; // Android 13+ specific usually, or generic
    final pNotification = await Permission.notification.status;

    setState(() {
      _permStatuses = {
        'storage': pStorage,
        'photos': pPhotos,
        'notification': pNotification,
      };

      _isAllGranted =
          pStorage.isGranted && pNotification.isGranted; // Storage is critical

      int grantedCount = 0;
      if (pStorage.isGranted) grantedCount++;
      if (pPhotos.isGranted || pPhotos.isLimited) grantedCount++;
      if (pNotification.isGranted) grantedCount++;

      _permSummary = "权限状态: $grantedCount / 3 已获取";
    });
  }

  // 共享 MomentService 注入 StorageService（不维护写 Manifest 的独立实例）
  StorageService get _storageService => StorageService(
    momentService: context.read<MomentService>(),
  );

  Future<void> _loadStorageInfo() async {
    final service = _storageService;
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
    bool usingExternal = path.contains(
      '/storage/emulated/0',
    ); // Simple heuristic
    bool hasClutter =
        usingExternal && clutterSize > 1024 * 1024; // >1MB clutter only

    if (mounted) {
      setState(() {
        _storageInfo =
            "内容占用: ${_formatSize(total)} (缓存: ${_formatSize(cacheSize)})";
        _internalStats =
            "Doc: ${_formatSize(docSize)} / Support: ${_formatSize(supportSize)}";
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
    final themeConfig = AppTheme.getSettingsTheme(theme);
    final Color titleColor = themeConfig['titleColor'] as Color;
    final Shadow titleShadow = themeConfig['titleShadow'] as Shadow;

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
        systemOverlayStyle: AppTheme.getSystemUiOverlayStyle(theme),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildList(context, themeConfig, settings),
    );

    // 返回带背景和特效的 Stack
    return Stack(
      children: [
        // 1. 背景
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),

        // 2. Visual Effects
        if (themeConfig['showPetalRain'] as bool)
          Positioned.fill(child: const PetalRainWidget()),
        if (themeConfig['showStarrySky'] as bool)
          Positioned.fill(child: const StarrySkyWidget()),

        // 3. 内容
        Positioned.fill(child: content),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    Map<String, dynamic> themeConfig,
    SettingsProvider settings,
  ) {
    final Color textColor = themeConfig['textColor'] as Color;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. 核心服务 (Core)
        _buildSectionHeader('账号与会员', textColor),
        _buildGroupContainer(
          themeConfig,
          children: [
            // [NEW] Premium Membership Entry
            Consumer<PaymentService>(
              builder: (ctx, pay, _) {
                return _buildSettingsItem(
                  context: context,
                  icon: pay.isSponsor ? Icons.favorite : Icons.coffee,
                  title: pay.isSponsor ? '特别支持者' : '支持开发者',
                  subtitle: pay.isSponsor ? '已点亮勋章 - 感谢有你' : '用爱发电，请我喝杯咖啡',
                  textColor: textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      SlidePageRoute(page: const PremiumMembershipPage()),
                    );
                  },
                );
              },
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon: Icons.cloud_sync_outlined,
              title: '数据同步',
              subtitle: _getSyncStatusText(context),
              textColor: textColor,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(page: SyncSettingsPage()),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. 外观与体验 (Appearance & Experience)
        _buildSectionHeader('外观与体验', textColor),
        _buildGroupContainer(
          themeConfig,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.palette_outlined,
              title: '主题风格',
              subtitle: _getThemeName(settings.currentTheme),
              textColor: textColor,
              onTap: () => _showThemePicker(context, settings),
            ),
            _buildDivider(themeConfig),
            _buildSwitchItem(
              context: context,
              icon: Icons.brightness_auto_outlined,
              title: '跟随系统深色模式',
              subtitle: '开启后，深色模式自动使用午夜星尘主题',
              value: settings.followSystemTheme,
              onChanged: (val) => settings.setFollowSystemTheme(val),
              themeConfig: themeConfig,
              textColor: textColor,
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon: Icons.start_outlined,
              title: '启动页',
              subtitle: _getStartupPageName(settings.startupPage),
              textColor: textColor,
              onTap: () => _showStartupPagePicker(context, settings),
            ),
            _buildDivider(themeConfig),
            // Compatibility Mode Switch
            _buildSwitchItem(
              context: context,
              icon: Icons.layers_clear_outlined,
              title: '兼容模式',
              subtitle: '隐藏信纸横线，仅显示文字',
              value: settings.compatibilityMode,
              onChanged: (val) => settings.setCompatibilityMode(val),
              themeConfig: themeConfig,
              textColor: textColor,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 3. 数据与隐私 (Data & Privacy)
        _buildSectionHeader('数据与隐私', textColor),
        _buildGroupContainer(
          themeConfig,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.lock_outline,
              title: '密码锁',
              subtitle: '生物识别与密码保护',
              textColor: textColor,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(page: const SecuritySettingsPage()),
                );
              },
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon:
                  _isAllGranted
                      ? Icons.verified_user_outlined
                      : Icons.gpp_maybe_outlined,
              title: '系统权限管理',
              subtitle: _permSummary,
              textColor: textColor,
              onTap: () => _showPermissionManager(context),
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon: Icons.sd_storage_outlined,
              title: '存储空间管理',
              subtitle: _storageInfo,
              textColor: textColor,
              onTap: () => _showStorageManager(context, themeConfig),
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon: Icons.delete_outline,
              title: '回收站',
              subtitle: '找回误删的日记',
              textColor: textColor,
              onTap: () {
                Navigator.push(context, SlidePageRoute(page: TrashPage()));
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 4. 帮助与反馈 (Help & Feedback)
        _buildSectionHeader('帮助与反馈', textColor),
        _buildGroupContainer(
          themeConfig,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.help_outline,
              title: '常见问题',
              subtitle: '查看使用指南与疑问解答',
              textColor: textColor,
              onTap:
                  () => _launchUrl(
                    'https://lingshichat.feishu.cn/docx/JvzDdhLXEo3OVaxWEc9cygDqnMc?from=from_copylink',
                  ),
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon: Icons.feedback_outlined,
              title: '意见反馈',
              subtitle: '提交Bug或功能建议',
              textColor: textColor,
              onTap:
                  () => _launchUrl(
                    'https://lingshichat.feishu.cn/share/base/form/shrcnx9xnwJU6cxmz6F5tLNQzi2',
                  ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 5. 关于 (About)
        _buildSectionHeader('关于', textColor),
        _buildGroupContainer(
          themeConfig,
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.system_update_outlined,
              title: '检测更新',
              subtitle:
                  _isCheckingUpdate
                      ? '检测中...'
                      : (_currentVersion != null
                          ? 'v$_currentVersion'
                          : '点击检查新版本'),
              textColor: textColor,
              isLoading: _isCheckingUpdate,
              onTap: _isCheckingUpdate ? () {} : () => _checkForUpdate(context),
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon: Icons.description_outlined,
              title: '用户协议',
              subtitle: '查阅用户服务协议',
              textColor: textColor,
              onTap:
                  () => _launchUrl(
                    'https://lingshichat.feishu.cn/docx/ODY0dLSF4okfuzximQuctlMon7g?from=from_copylink',
                  ),
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon: Icons.privacy_tip_outlined,
              title: '隐私政策',
              subtitle: '了解不仅限于数据的隐私保护',
              textColor: textColor,
              onTap:
                  () => _launchUrl(
                    'https://lingshichat.feishu.cn/docx/Gd6sdvdmRonHO9x6fMccUr3qnXg?from=from_copylink',
                  ),
            ),
            _buildDivider(themeConfig),
            _buildSettingsItem(
              context: context,
              icon: Icons.info_outline,
              title: '关于纸语PaperWhisper',
              subtitle: '纸本无言，因你而语',
              textColor: textColor,
              onTap: () {
                Navigator.push(
                  context,
                  SlidePageRoute(page: const AboutPage()),
                );
              },
            ),
            if (kDebugMode) ...[
              _buildDivider(themeConfig),
              _buildSettingsItem(
                context: context,
                icon: Icons.science_outlined,
                title: '开发测试：更新弹窗',
                subtitle: '仅调试构建可见，快速验证更新流程',
                textColor: textColor,
                onTap: () => _showDebugUpdateTestPanel(context),
              ),
            ],
          ],
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
          color: textColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildGroupContainer(
    Map<String, dynamic> themeConfig, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: themeConfig['groupDecoration'] as BoxDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider(Map<String, dynamic> themeConfig) {
    return Divider(
      height: 1,
      thickness: 1,
      color: themeConfig['dividerColor'] as Color,
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
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
              Icon(icon, color: textColor.withValues(alpha: 0.8), size: 24),
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
                        color: textColor.withValues(alpha: 0.6),
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      textColor.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  color: textColor.withValues(alpha: 0.4),
                  size: 14,
                ),
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
    required Map<String, dynamic> themeConfig,
    required Color textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: textColor.withValues(alpha: 0.8), size: 24),
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
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: themeConfig['activeSwitchColor'] as Color,
              activeTrackColor: themeConfig['activeTrackColor'] as Color,
            ),
          ],
        ),
      ),
    );
  }

  // --- Existing View Logic ---

  void _showPermissionManager(BuildContext context) {
    final theme =
        Provider.of<SettingsProvider>(context, listen: false).currentTheme;
    final themeConfig = AppTheme.getSettingsTheme(theme);
    final Color sheetDividerColor =
        themeConfig['sheetInfoDividerColor'] as Color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _buildSkeuomorphicBottomSheet(
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
              Divider(color: sheetDividerColor, height: 1),
              _buildPermissionRow(
                context,
                '相册访问',
                '用于在日记中插入图片',
                Icons.photo_library_outlined,
                _permStatuses['photos'],
                Permission.photos,
              ),
              Divider(color: sheetDividerColor, height: 1),
              _buildPermissionRow(
                context,
                '通知提醒',
                '显示数据同步进度与状态',
                Icons.notifications_outlined,
                _permStatuses['notification'],
                Permission.notification,
              ),
              const SizedBox(height: 20),
              SkeuomorphicDialogButton(
                label: '前往系统设置页',
                isPrimary: false,
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
              ),
            ],
          ),
    );
  }

  Widget _buildPermissionRow(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    PermissionStatus? status,
    Permission perm, {
    bool isCritical = false,
  }) {
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final themeConfig = AppTheme.getSettingsTheme(theme);
    final textColor = themeConfig['sheetTextColor'] as Color;

    bool isGranted = status?.isGranted == true;
    bool isLimited = status?.isLimited == true;

    Color statusColor =
        isGranted
            ? Colors.green
            : (isCritical ? Colors.red : Colors.orange.shade800);
    String statusText = isGranted ? '已获取' : (isLimited ? '部分允许' : '未获取');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: textColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.notoSerifSc(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.notoSerifSc(
          color: textColor.withValues(alpha: 0.6),
          fontSize: 11,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGranted)
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                Navigator.pop(context);

                final isHarmony = await PlatformUtils.isHarmonyOS();
                if (!context.mounted) return;

                if (isHarmony) {
                  SkeuomorphicToast.info(context, '正在跳转设置页...');
                  await openAppSettings();
                } else {
                  final newStatus = await perm.request();
                  if (!context.mounted) return;

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
                  if (!mounted) return;
                  _checkAllPermissions();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '去授权',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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
      if (!context.mounted) return;
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
      if (!context.mounted) return;
      SkeuomorphicToast.error(context, '检测更新失败，请检查网络');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  /// 显示开发态更新测试面板
  Future<void> _showDebugUpdateTestPanel(BuildContext context) async {
    final updateService = UpdateService();
    final currentVersion = await updateService.getCurrentVersion();
    final localInfo =
        await updateService.getLocalUpdateInfo() ??
        UpdateInfo(
          latestVersion: currentVersion,
          isForceUpdate: false,
          changelog: const ['开发测试入口：本地更新配置缺失时的回退数据'],
          downloadUrl: const {
            'android': 'https://pwdl.lingshichat.cn/Android/latest.apk',
            'windows': 'https://pwdl.lingshichat.cn/Windows/latest.exe',
          },
          backupUrl: const {'android': '', 'windows': ''},
        );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return SkeuomorphicDialog(
          title: '开发测试：更新弹窗',
          headerIcon: Icons.science_outlined,
          content: Text(
            '选择一个预设测试场景。\n'
            '本入口仅在 Debug 构建显示，不会进入正式版本。',
          ),
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeuomorphicDialogButton(
                label: '普通更新弹窗',
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openDebugUpdateDialog(
                    context,
                    currentVersion: currentVersion,
                    updateInfo: _copyUpdateInfo(
                      localInfo,
                      isForceUpdate: false,
                      changelog: [...localInfo.changelog, '【开发测试】普通更新弹窗'],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              SkeuomorphicDialogButton(
                label: '下载失败场景',
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openDebugUpdateDialog(
                    context,
                    currentVersion: currentVersion,
                    updateInfo: _copyUpdateInfo(
                      localInfo,
                      isForceUpdate: false,
                      downloadUrl: _buildDebugFailUrls(localInfo),
                      changelog: [
                        ...localInfo.changelog,
                        '【开发测试】使用无效地址，验证下载失败提示',
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              SkeuomorphicDialogButton(
                label: '强制更新弹窗',
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openDebugUpdateDialog(
                    context,
                    currentVersion: currentVersion,
                    updateInfo: _copyUpdateInfo(
                      localInfo,
                      isForceUpdate: true,
                      changelog: [...localInfo.changelog, '【开发测试】验证强制更新不可关闭'],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              SkeuomorphicDialogButton(
                label: '取消',
                isPrimary: false,
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 打开测试用更新弹窗
  void _openDebugUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required UpdateInfo updateInfo,
  }) {
    UpdateDialog.show(
      context,
      updateInfo: updateInfo,
      currentVersion: currentVersion,
    );
  }

  /// 复制更新信息并覆盖测试场景字段
  UpdateInfo _copyUpdateInfo(
    UpdateInfo source, {
    bool? isForceUpdate,
    Map<String, String>? downloadUrl,
    Map<String, String>? backupUrl,
    List<String>? changelog,
  }) {
    return UpdateInfo(
      latestVersion: source.latestVersion,
      buildNumber: source.buildNumber,
      releaseDate: source.releaseDate,
      title: source.title,
      isForceUpdate: isForceUpdate ?? source.isForceUpdate,
      changelog: changelog ?? source.changelog,
      downloadUrl: downloadUrl ?? source.downloadUrl,
      backupUrl: backupUrl ?? source.backupUrl,
      minSupportedVersion: source.minSupportedVersion,
    );
  }

  /// 构造下载失败测试地址
  Map<String, String> _buildDebugFailUrls(UpdateInfo source) {
    final result = <String, String>{...?source.downloadUrl};
    result['android'] = 'http://127.0.0.1:9/debug-fail.apk';
    result['windows'] = 'http://127.0.0.1:9/debug-fail.exe';
    return result;
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
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );

      if (!launched) {
        // 2. 尝试使用 WebView 模式 (传统 WebView)
        // 保证在 App 内部打开
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        return;
      }

      if (!launched) {
        // 3. 最后降级去系统浏览器
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (!mounted) return;
          SkeuomorphicToast.error(context, '无法打开链接');
        }
      }
    } catch (e) {
      if (!mounted) return;

      // 尝试降级打开
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {}

      if (!mounted) return;
      SkeuomorphicToast.error(context, '无法打开链接: $e');
    }
  }

  String _getSyncStatusText(BuildContext context) {
    final syncProvider = Provider.of<SyncProvider>(context);
    final snapshot = syncProvider.trustSnapshot;

    if (snapshot.state == SyncTrustState.notEnabled) return '未启用';
    if (snapshot.state == SyncTrustState.syncing) return '同步中...';
    if (snapshot.state == SyncTrustState.localChangesPending) {
      return '尚有 ${snapshot.totalPendingCount} 项待同步';
    }
    if (snapshot.state == SyncTrustState.syncFailed) {
      return snapshot.failureReason ?? '同步失败，内容仍保留在本地';
    }
    if (snapshot.state == SyncTrustState.needsAttention) {
      return snapshot.failureReason ?? '需要检查同步配置';
    }
    if (snapshot.lastSuccessfulSyncAt != null) {
      final platform = _formatSyncPlatform(snapshot.lastSuccessfulSyncPlatform);
      return '最近一次成功同步：${_formatTime(snapshot.lastSuccessfulSyncAt!)}${platform == null ? '' : '（$platform）'}';
    }
    return '已启用';
  }

  String? _formatSyncPlatform(String? platform) {
    switch (platform) {
      case 'webdav':
        return 'WebDAV';
      case 's3':
        return 'S3';
      default:
        return null;
    }
  }

  String _formatTime(DateTime time) {
    return "${time.year}-${time.month}-${time.day} ${time.hour}:${time.minute}";
  }

  // --- Theme & Storage Helpers (Unchanged Logic, just helper methods) ---

  String _getThemeName(String theme) {
    switch (theme) {
      case AppTheme.themeSeaFlower:
        return '海底花海';
      case AppTheme.themeMidnight:
        return '午夜星尘';
      case AppTheme.themeAmberLens:
        return '琥珀光圈';
      case AppTheme.themeAfterRain:
        return '雨后天空';
      case AppTheme.themeTwilight:
        return '黄昏之时';
      case AppTheme.themeGardenOfWords:
        return '言叶之庭';
      default:
        return '复古纸张';
    }
  }

  String _getStartupPageName(String page) {
    switch (page) {
      case 'moments':
        return '随心记';
      case 'writer':
        return '专注书写';
      case 'last':
        return '恢复上次状态';
      default:
        return '专注书写';
    }
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _buildSkeuomorphicBottomSheet(
            context,
            title: '选择主题',
            children: [
              _buildRadioItem(
                ctx,
                '复古纸张',
                'default',
                settings.currentTheme,
                (val) => settings.setTheme(val),
                closeOnSelect: false,
              ),
              _buildRadioItem(
                ctx,
                '海底花海',
                'sea_flower',
                settings.currentTheme,
                (val) => settings.setTheme(val),
                closeOnSelect: false,
              ),
              _buildRadioItem(
                ctx,
                '午夜星尘',
                'midnight',
                settings.currentTheme,
                (val) => settings.setTheme(val),
                closeOnSelect: false,
              ),
              _buildRadioItem(
                ctx,
                '琥珀光圈',
                'amber_lens',
                settings.currentTheme,
                (val) => settings.setTheme(val),
                closeOnSelect: false,
              ),
              _buildRadioItem(
                ctx,
                '雨后天空',
                'after_rain',
                settings.currentTheme,
                (val) => settings.setTheme(val),
                closeOnSelect: false,
              ),
              _buildRadioItem(
                ctx,
                '黄昏之时',
                'twilight',
                settings.currentTheme,
                (val) => settings.setTheme(val),
                closeOnSelect: false,
              ),
              _buildRadioItem(
                ctx,
                '言叶之庭',
                'garden_of_words',
                settings.currentTheme,
                (val) => settings.setTheme(val),
                closeOnSelect: false,
              ),
            ],
          ),
    );
  }

  void _showStartupPagePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _buildSkeuomorphicBottomSheet(
            context,
            title: '选择启动页',
            children: [
              _buildRadioItem(
                ctx,
                '专注书写',
                'writer',
                settings.startupPage,
                (val) => settings.setStartupPage(val),
              ),
              _buildRadioItem(
                ctx,
                '随心记',
                'moments',
                settings.startupPage,
                (val) => settings.setStartupPage(val),
              ),
            ],
          ),
    );
  }

  void _showStorageManager(
    BuildContext context,
    Map<String, dynamic> themeConfig,
  ) {
    final Color sheetTextColor = themeConfig['sheetTextColor'] as Color;
    final Color infoBgColor = themeConfig['sheetInfoBackgroundColor'] as Color;
    final Color infoBorderColor = themeConfig['sheetInfoBorderColor'] as Color;
    final Color infoDividerColor =
        themeConfig['sheetInfoDividerColor'] as Color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _buildSkeuomorphicBottomSheet(
            context,
            title: '用户数据管理',
            children: [
              ListTile(
                leading: Icon(Icons.delete_sweep, color: sheetTextColor),
                title: Text(
                  '清理无用图片 (深度清理)',
                  style: GoogleFonts.notoSerifSc(color: sheetTextColor),
                ),
                subtitle: Text(
                  '扫描并删除未被任何随心记引用的冗余图片',
                  style: GoogleFonts.notoSerifSc(
                    color: sheetTextColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  SkeuomorphicToast.info(context, '正在深度清理...');
                  int freed = await _storageService.cleanOrphanImages();
                  await _loadStorageInfo(); // Refresh
                  if (context.mounted) {
                    SkeuomorphicToast.success(
                      context,
                      '清理完成，释放 ${_formatSize(freed)} 空间',
                    );
                  }
                },
              ),
              Divider(color: sheetTextColor.withValues(alpha: 0.1)),
              ListTile(
                leading: Icon(Icons.cleaning_services, color: sheetTextColor),
                title: Text(
                  '立即清理缓存',
                  style: GoogleFonts.notoSerifSc(color: sheetTextColor),
                ),
                subtitle: Text(
                  '清理产生的临时文件 (不影响数据)',
                  style: GoogleFonts.notoSerifSc(
                    color: sheetTextColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _storageService.cleanTemporaryCache();
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
                  color: infoBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: infoBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.perm_device_information,
                          size: 16,
                          color: sheetTextColor.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '系统运行数据 (App必须)',
                          style: GoogleFonts.notoSerifSc(
                            color: sheetTextColor.withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '包含字体缓存 (Support) 及 App 资源文件 (Doc)。\n此部分数据维持 App 正常运行，无需清理。',
                      style: GoogleFonts.notoSerifSc(
                        color: sheetTextColor.withValues(alpha: 0.6),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: infoDividerColor, height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '占用空间: $_internalStats',
                          style: GoogleFonts.notoSerifSc(
                            color: sheetTextColor.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    if (_hasInternalClutter)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(ctx);
                            SkeuomorphicToast.info(context, '正在清理私有残留...');
                            int freed =
                                await _storageService.cleanInternalClutter();
                            await _loadStorageInfo();
                            if (context.mounted) {
                              SkeuomorphicToast.success(
                                context,
                                '清理了 ${_formatSize(freed)} 旧数据',
                              );
                            }
                          },
                          child: Text(
                            '>> 发现残留数据，点击清理',
                            style: GoogleFonts.notoSerifSc(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    if (_internalStats.contains('Support') &&
                        !(_internalStats.contains('0 B')))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InkWell(
                          onTap: () async {
                            Navigator.pop(ctx);
                            SkeuomorphicToast.info(context, '正在清理字体缓存...');
                            await _storageService.cleanFontCache();
                            await _loadStorageInfo();
                            if (context.mounted) {
                              SkeuomorphicToast.success(
                                context,
                                '字体缓存已清除 (下次启动将自动重新下载)',
                              );
                            }
                          },
                          child: Text(
                            '>> 强制清除字体缓存 (修复显示异常)',
                            style: GoogleFonts.notoSerifSc(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
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

  Widget _buildSkeuomorphicBottomSheet(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final themeConfig = AppTheme.getSettingsTheme(settings.currentTheme);
    final bgColor = themeConfig['sheetBackgroundColor'] as Color;
    final titleColor = themeConfig['sheetTitleColor'] as Color;
    final tapeColor = themeConfig['sheetTapeColor'] as Color;
    final List<BoxShadow> shadows = List<BoxShadow>.from(
      themeConfig['sheetShadows'] as List<dynamic>,
    );
    final BoxBorder? border = themeConfig['sheetBorder'] as BoxBorder?;
    final bool showTape = themeConfig['sheetShowTape'] as bool;

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
          if (showTape)
            Positioned(
              top: -15,
              child: Transform.rotate(
                angle: -0.02,
                child: Container(
                  width: 80,
                  height: 25,
                  decoration: BoxDecoration(
                    color: tapeColor,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Handle for other themes
          if (!showTape)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: titleColor.withValues(alpha: 0.2),
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
                    color: titleColor,
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

  Widget _buildRadioItem(
    BuildContext context,
    String label,
    String value,
    String groupValue,
    Function(String) onChanged, {
    bool closeOnSelect = true,
  }) {
    return _buildOptionTile(
      context,
      label,
      value,
      groupValue,
      onChanged,
      closeOnSelect: closeOnSelect,
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    String label,
    String value,
    String groupValue,
    Function(String) onChanged, {
    bool closeOnSelect = true,
  }) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final themeConfig = AppTheme.getSettingsTheme(settings.currentTheme);
    final isSelected = value == groupValue;

    final Color bgColor =
        isSelected
            ? themeConfig['optionSelectedBgColor'] as Color
            : themeConfig['optionUnselectedBgColor'] as Color;
    final Color textColor =
        isSelected
            ? themeConfig['optionSelectedTextColor'] as Color
            : themeConfig['optionUnselectedTextColor'] as Color;
    final BoxShadow? shadow =
        isSelected
            ? themeConfig['optionSelectedShadow'] as BoxShadow?
            : themeConfig['optionUnselectedShadow'] as BoxShadow?;
    final Border? border =
        isSelected ? null : themeConfig['optionUnselectedBorder'] as Border?;

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
          mainAxisAlignment:
              MainAxisAlignment.center, // Center text like a button
          children: [
            Text(
              label,
              style: GoogleFonts.notoSerifSc(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.bold, // Always bold like buttons
              ),
            ),
            // Optional: Add Check icon if selected?
            // Dialog buttons usually don't have check icons, just distinct style.
            // But for selection, a check might be nice.
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check,
                size: 18,
                color: textColor.withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
