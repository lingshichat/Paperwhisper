import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/components/settings_theme_data.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/permissions/application/permission_coordinator.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_status_formatter.dart';
import 'package:paper_whisper_flutter/features/update/presentation/update_dialog.dart';
import 'package:paper_whisper_flutter/features/update/data/update_info.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/features/premium/data/payment_service.dart';
import 'package:paper_whisper_flutter/core/storage/storage_service.dart';
import 'package:paper_whisper_flutter/features/update/data/update_service.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_dialog.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_toast.dart';
import 'package:paper_whisper_flutter/core/theme/widgets/visual_effects.dart';

import '../application/settings_permission_controller.dart';
import '../application/settings_storage_controller.dart';
import '../application/settings_update_controller.dart';
import 'widgets/settings_choice_sheet.dart';
import 'widgets/settings_permission_content.dart';
import 'widgets/settings_primitives.dart';
import 'widgets/settings_storage_content.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  // 设置页控制器（context-free，页面只翻译 typed outcome 为 UI）
  SettingsPermissionController? _permissionController;
  SettingsStorageController? _storageController;
  SettingsUpdateController? _updateController;
  bool _controllersReady = false;

  static const _themePickerOrder = <String>[
    AppTheme.themeDefault,
    AppTheme.themeSeaFlower,
    AppTheme.themeMidnight,
    AppTheme.themeAmberLens,
    AppTheme.themeAfterRain,
    AppTheme.themeTwilight,
    AppTheme.themeGardenOfWords,
  ];

  // 未加载时的权限兜底快照：保持原 null status 视觉（三行均「未获取」）。
  static const PermissionSnapshot _kDeniedPermissionFallback =
      PermissionSnapshot(
        storage: PermissionStatus.denied,
        photos: PermissionStatus.denied,
        notification: PermissionStatus.denied,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 控制器依赖 context 提供的 MomentService（构造 StorageService 一次），
    // 在依赖可用后创建；初始 load 只在首次触发。
    if (_controllersReady) return;
    _controllersReady = true;
    // 共享 MomentService 构造 StorageService（只一次，页面不每次 new）。
    _storageController = SettingsStorageController(
      gateway: SettingsStorageGatewayAdapter(
        StorageService(momentService: context.read<MomentService>()),
      ),
    );
    _permissionController = SettingsPermissionController();
    _updateController = SettingsUpdateController();
    _loadStorageInfo();
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionController?.dispose();
    _storageController?.dispose();
    _updateController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    final controller = _permissionController;
    if (controller == null) return;
    try {
      await controller.load();
    } on StateError {
      return; // dispose 后不再更新
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadStorageInfo() async {
    final controller = _storageController;
    if (controller == null) return;
    try {
      await controller.load();
    } on StateError {
      return; // dispose 后不再更新
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 获取主题信息，保持与 Sidebar 一致的设计语言
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final themeConfig = ThemeRegistry.get(theme).settings;
    final Color titleColor = themeConfig.titleColor;
    final Shadow titleShadow = themeConfig.titleShadow;

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
        if (themeConfig.showPetalRain)
          Positioned.fill(child: const PetalRainWidget()),
        if (themeConfig.showStarrySky)
          Positioned.fill(child: const StarrySkyWidget()),

        // 3. 内容
        Positioned.fill(child: content),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    SettingsThemeData themeConfig,
    SettingsProvider settings,
  ) {
    final Color textColor = themeConfig.textColor;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. 核心服务 (Core)
        SettingsSectionHeader(title: '账号与会员', textColor: textColor),
        SettingsGroupContainer(
          decoration: themeConfig.groupDecoration,
          children: [
            // [NEW] Premium Membership Entry
            Consumer<PaymentService>(
              builder: (ctx, pay, _) {
                return SettingsItem(
                  icon: pay.isSponsor ? Icons.favorite : Icons.coffee,
                  title: pay.isSponsor ? '特别支持者' : '支持开发者',
                  subtitle: pay.isSponsor ? '已点亮勋章 - 感谢有你' : '用爱发电，请我喝杯咖啡',
                  textColor: textColor,
                  onTap: () {
                    Navigator.push(context, AppRoutes.premium());
                  },
                );
              },
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: Icons.cloud_sync_outlined,
              title: '数据同步',
              subtitle: _getSyncStatusText(context),
              textColor: textColor,
              onTap: () {
                Navigator.push(context, AppRoutes.syncSettings());
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. 外观与体验 (Appearance & Experience)
        SettingsSectionHeader(title: '外观与体验', textColor: textColor),
        SettingsGroupContainer(
          decoration: themeConfig.groupDecoration,
          children: [
            SettingsItem(
              icon: Icons.palette_outlined,
              title: '主题风格',
              subtitle: _getThemeName(settings.currentTheme),
              textColor: textColor,
              onTap: () => _showThemePicker(context),
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsSwitchItem(
              icon: Icons.brightness_auto_outlined,
              title: '跟随系统深色模式',
              subtitle: '开启后，深色模式自动使用午夜星尘主题',
              value: settings.followSystemTheme,
              onChanged: (val) => settings.setFollowSystemTheme(val),
              textColor: textColor,
              activeThumbColor: themeConfig.activeSwitchColor,
              activeTrackColor: themeConfig.activeTrackColor,
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: Icons.start_outlined,
              title: '启动页',
              subtitle: _getStartupPageName(settings.startupPage),
              textColor: textColor,
              onTap: () => _showStartupPagePicker(context, settings),
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            // Compatibility Mode Switch
            SettingsSwitchItem(
              icon: Icons.layers_clear_outlined,
              title: '兼容模式',
              subtitle: '隐藏信纸横线，仅显示文字',
              value: settings.compatibilityMode,
              onChanged: (val) => settings.setCompatibilityMode(val),
              textColor: textColor,
              activeThumbColor: themeConfig.activeSwitchColor,
              activeTrackColor: themeConfig.activeTrackColor,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 3. 数据与隐私 (Data & Privacy)
        SettingsSectionHeader(title: '数据与隐私', textColor: textColor),
        SettingsGroupContainer(
          decoration: themeConfig.groupDecoration,
          children: [
            SettingsItem(
              icon: Icons.lock_outline,
              title: '密码锁',
              subtitle: '生物识别与密码保护',
              textColor: textColor,
              onTap: () {
                Navigator.push(context, AppRoutes.securitySettings());
              },
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: (_permissionController?.snapshot?.isAllGranted ?? false)
                  ? Icons.verified_user_outlined
                  : Icons.gpp_maybe_outlined,
              title: '系统权限管理',
              subtitle: _permissionController?.snapshot?.summary ?? '检测中...',
              textColor: textColor,
              onTap: () => _showPermissionManager(context),
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: Icons.sd_storage_outlined,
              title: '存储空间管理',
              subtitle: _storageController?.snapshot?.summary ?? '计算中...',
              textColor: textColor,
              onTap: () => _showStorageManager(context, themeConfig),
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: Icons.delete_outline,
              title: '回收站',
              subtitle: '找回误删的日记',
              textColor: textColor,
              onTap: () {
                Navigator.push(context, AppRoutes.trash());
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 4. 帮助与反馈 (Help & Feedback)
        SettingsSectionHeader(title: '帮助与反馈', textColor: textColor),
        SettingsGroupContainer(
          decoration: themeConfig.groupDecoration,
          children: [
            SettingsItem(
              icon: Icons.help_outline,
              title: '常见问题',
              subtitle: '查看使用指南与疑问解答',
              textColor: textColor,
              onTap: () => _launchUrl(
                'https://lingshichat.feishu.cn/docx/JvzDdhLXEo3OVaxWEc9cygDqnMc?from=from_copylink',
              ),
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: Icons.feedback_outlined,
              title: '意见反馈',
              subtitle: '提交Bug或功能建议',
              textColor: textColor,
              onTap: () => _launchUrl(
                'https://lingshichat.feishu.cn/share/base/form/shrcnx9xnwJU6cxmz6F5tLNQzi2',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 5. 关于 (About)
        SettingsSectionHeader(title: '关于', textColor: textColor),
        SettingsGroupContainer(
          decoration: themeConfig.groupDecoration,
          children: [
            SettingsItem(
              icon: Icons.system_update_outlined,
              title: '检测更新',
              subtitle: (_updateController?.checking ?? false)
                  ? '检测中...'
                  : ((_updateController?.currentVersion) != null
                        ? 'v${_updateController?.currentVersion}'
                        : '点击检查新版本'),
              textColor: textColor,
              isLoading: _updateController?.checking ?? false,
              onTap: (_updateController?.checking ?? false)
                  ? () {}
                  : _checkForUpdate,
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: Icons.description_outlined,
              title: '用户协议',
              subtitle: '查阅用户服务协议',
              textColor: textColor,
              onTap: () => _launchUrl(
                'https://lingshichat.feishu.cn/docx/ODY0dLSF4okfuzximQuctlMon7g?from=from_copylink',
              ),
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: Icons.privacy_tip_outlined,
              title: '隐私政策',
              subtitle: '了解不仅限于数据的隐私保护',
              textColor: textColor,
              onTap: () => _launchUrl(
                'https://lingshichat.feishu.cn/docx/Gd6sdvdmRonHO9x6fMccUr3qnXg?from=from_copylink',
              ),
            ),
            SettingsDivider(color: themeConfig.dividerColor),
            SettingsItem(
              icon: Icons.info_outline,
              title: '关于纸语PaperWhisper',
              subtitle: '纸本无言，因你而语',
              textColor: textColor,
              onTap: () {
                Navigator.push(context, AppRoutes.about());
              },
            ),
            if (kDebugMode) ...[
              SettingsDivider(color: themeConfig.dividerColor),
              SettingsItem(
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

  // --- S2a 展示组件适配（typed theme→props 转发，不复制 Widget 树） ---

  Widget _sheetFrame(
    SettingsThemeData themeConfig,
    String title,
    List<Widget> children,
  ) {
    return SettingsBottomSheetFrame(
      title: title,
      titleColor: themeConfig.sheetTitleColor,
      backgroundColor: themeConfig.sheetBackgroundColor,
      tapeColor: themeConfig.sheetTapeColor,
      shadows: themeConfig.sheetShadows,
      border: themeConfig.sheetBorder,
      showTape: themeConfig.sheetShowTape,
      children: children,
    );
  }

  /// 选择弹层样式：主题/启动页共用同一组 option 主题键，一次适配。
  SettingsChoiceSheetStyle _choiceStyle(SettingsThemeData tc) {
    return SettingsChoiceSheetStyle(
      backgroundColor: tc.sheetBackgroundColor,
      titleColor: tc.sheetTitleColor,
      tapeColor: tc.sheetTapeColor,
      shadows: tc.sheetShadows,
      border: tc.sheetBorder,
      showTape: tc.sheetShowTape,
      selectedBackgroundColor: tc.optionSelectedBgColor,
      unselectedBackgroundColor: tc.optionUnselectedBgColor,
      selectedTextColor: tc.optionSelectedTextColor,
      unselectedTextColor: tc.optionUnselectedTextColor,
      selectedShadow: tc.optionSelectedShadow,
      unselectedShadow: tc.optionUnselectedShadow,
      unselectedBorder: tc.optionUnselectedBorder,
    );
  }

  // --- Existing View Logic ---

  void _showPermissionManager(BuildContext context) {
    final theme = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).currentTheme;
    final themeConfig = ThemeRegistry.get(theme).settings;
    final Color sheetDividerColor = themeConfig.sheetInfoDividerColor;
    final Color sheetTextColor = themeConfig.sheetTextColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetFrame(themeConfig, '应用权限管理', [
        SettingsPermissionContent(
          // 未加载时用兜底快照保持原 null status 视觉（三行均「未获取」）。
          snapshot:
              _permissionController?.snapshot ?? _kDeniedPermissionFallback,
          textColor: sheetTextColor,
          dividerColor: sheetDividerColor,
          onRequest: (kind) => _handlePermissionRequest(ctx, kind),
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
      ]),
    );
  }

  /// 权限请求编排（页面职责）：pop → 鸿蒙判定 → toast / openAppSettings →
  /// 500ms 后重新加载状态；请求与判定委托 context-free 的 PermissionController。
  Future<void> _handlePermissionRequest(
    BuildContext ctx,
    SettingsPermissionKind kind,
  ) async {
    Navigator.pop(ctx);
    final controller = _permissionController;
    if (controller == null) return;

    // 鸿蒙判定与权限请求委托 PermissionController；
    // 说明 Toast / openAppSettings 留在页面。
    try {
      final isHarmony = await controller.isHarmonyOS();
      if (!mounted) return;

      if (isHarmony) {
        SkeuomorphicToast.info(context, '正在跳转设置页...');
        await openAppSettings();
      } else {
        final outcome = await controller.request(kind);
        if (!mounted) return;

        switch (outcome) {
          case PermissionRequestOutcome.granted:
            SkeuomorphicToast.success(context, '授权成功');
          case PermissionRequestOutcome.permanentlyDenied:
            SkeuomorphicToast.warning(context, '请在设置中手动开启');
            openAppSettings();
          case PermissionRequestOutcome.denied:
            SkeuomorphicToast.info(context, '权限未授予');
        }

        // Check again
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        await _checkAllPermissions();
      }
    } on StateError {
      // 仅 dispose 生命周期取消（isHarmonyOS / request / 500ms reload 全程）：
      // 静默返回，不再触碰 UI / Toast。
      return;
    }
  }

  /// 手动检测更新：经 SettingsUpdateController 的 typed outcome 穷尽翻译；
  /// checking 禁用语义与 finally 复位由控制器内部保证，页面只做 UI 反馈。
  Future<void> _checkForUpdate() async {
    final controller = _updateController;
    if (controller == null) return;
    // manualCheck 同步置 checking=true：立即刷新，让「检测中...」、loading
    // 与禁用态跨网络等待渲染，而不是等结果返回后才一次性更新。
    final future = controller.manualCheck();
    if (mounted) setState(() {});
    final SettingsUpdateCheckOutcome outcome;
    try {
      outcome = await future;
    } on StateError {
      // 仅 dispose 生命周期取消：静默返回，不再触碰 UI，不重复 Toast。
      return;
    }
    if (!mounted) return;
    // 刷新 checking / currentVersion 展示（controller 非 ChangeNotifier）。
    setState(() {});
    switch (outcome) {
      case SettingsUpdateAvailable(:final info, :final currentVersion):
        UpdateDialog.show(
          context,
          updateInfo: info,
          currentVersion: currentVersion,
        );
      case SettingsUpdateUpToDate():
        SkeuomorphicToast.success(context, '已是最新版本 ✔');
      case SettingsUpdateFailure():
        SkeuomorphicToast.error(context, '检测更新失败，请检查网络');
      case SettingsUpdateBusy():
        // 已有检查进行中：保持禁用语义，不重复提示。
        break;
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
    // 状态文案逐字委托 SyncStatusFormatter（settings 风格：分钟不补零）。
    return const SyncStatusFormatter().formatCompactStatus(
      syncProvider.trustSnapshot,
    );
  }

  // --- Theme & Storage Helpers (Unchanged Logic, just helper methods) ---

  String _getThemeName(String theme) => ThemeRegistry.get(theme).name;

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

  void _showThemePicker(BuildContext context) {
    final themesById = {
      for (final theme in ThemeRegistry.allThemes) theme.id: theme,
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Selector<SettingsProvider, String>(
        selector: (_, settings) => settings.currentTheme,
        builder: (ctx, currentTheme, _) => SettingsChoiceSheet<String>(
          title: '选择主题',
          // Registry 提供名称；显式 ID 列表只固定既有展示顺序。
          options: [
            for (final id in _themePickerOrder)
              SettingsChoiceOption(label: themesById[id]!.name, value: id),
          ],
          selected: currentTheme,
          onSelected: (val) => ctx.read<SettingsProvider>().setTheme(val),
          closeOnSelect: false,
          style: _choiceStyle(ThemeRegistry.get(currentTheme).settings),
        ),
      ),
    );
  }

  void _showStartupPagePicker(BuildContext context, SettingsProvider settings) {
    final style = _choiceStyle(
      ThemeRegistry.get(settings.currentTheme).settings,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SettingsChoiceSheet<String>(
        title: '选择启动页',
        options: const [
          SettingsChoiceOption(label: '专注书写', value: 'writer'),
          SettingsChoiceOption(label: '随心记', value: 'moments'),
        ],
        selected: settings.startupPage,
        onSelected: (val) => settings.setStartupPage(val),
        style: style,
      ),
    );
  }

  void _showStorageManager(
    BuildContext context,
    SettingsThemeData themeConfig,
  ) {
    final Color sheetTextColor = themeConfig.sheetTextColor;
    final Color infoBgColor = themeConfig.sheetInfoBackgroundColor;
    final Color infoBorderColor = themeConfig.sheetInfoBorderColor;
    final Color infoDividerColor = themeConfig.sheetInfoDividerColor;

    final snap = _storageController?.snapshot;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetFrame(themeConfig, '用户数据管理', [
        SettingsStorageContent(
          // 未加载时保持原默认视觉（internalStats 空串 / 无残留入口）。
          internalStats: snap?.internalStats ?? '',
          hasInternalClutter: snap?.hasInternalClutter ?? false,
          textColor: sheetTextColor,
          infoBackgroundColor: infoBgColor,
          infoBorderColor: infoBorderColor,
          infoDividerColor: infoDividerColor,
          onCleanOrphanImages: () => _cleanOrphanImages(ctx),
          onCleanTemporaryCache: () => _cleanTemporaryCache(ctx),
          onCleanInternalClutter: () => _cleanInternalClutter(ctx),
          onCleanFontCache: () => _cleanFontCache(ctx),
        ),
      ]),
    );
  }

  /// 清理无用图片（编排留在页面：pop → toast → IO → 重载 → toast）。
  Future<void> _cleanOrphanImages(BuildContext ctx) async {
    Navigator.pop(ctx);
    SkeuomorphicToast.info(context, '正在深度清理...');
    final controller = _storageController;
    if (controller == null) return;
    final freed = await controller.cleanOrphanImages();
    await _loadStorageInfo(); // Refresh
    if (mounted) {
      SkeuomorphicToast.success(
        context,
        '清理完成，释放 ${SettingsStorageController.formatSize(freed)} 空间',
      );
    }
  }

  /// 立即清理缓存。
  Future<void> _cleanTemporaryCache(BuildContext ctx) async {
    Navigator.pop(ctx);
    final controller = _storageController;
    if (controller == null) return;
    await controller.cleanTemporaryCache();
    await _loadStorageInfo(); // Refresh
    if (mounted) {
      SkeuomorphicToast.success(context, '缓存已清理');
    }
  }

  /// 清理内部私有残留（仅发现残留时可达）。
  Future<void> _cleanInternalClutter(BuildContext ctx) async {
    Navigator.pop(ctx);
    SkeuomorphicToast.info(context, '正在清理私有残留...');
    final controller = _storageController;
    if (controller == null) return;
    final freed = await controller.cleanInternalClutter();
    await _loadStorageInfo();
    if (mounted) {
      SkeuomorphicToast.success(
        context,
        '清理了 ${SettingsStorageController.formatSize(freed)} 旧数据',
      );
    }
  }

  /// 强制清除字体缓存（仅 Support 占用非 0 时可达）。
  Future<void> _cleanFontCache(BuildContext ctx) async {
    Navigator.pop(ctx);
    SkeuomorphicToast.info(context, '正在清理字体缓存...');
    final controller = _storageController;
    if (controller == null) return;
    await controller.cleanFontCache();
    await _loadStorageInfo();
    if (mounted) {
      SkeuomorphicToast.success(context, '字体缓存已清除 (下次启动将自动重新下载)');
    }
  }
}
