import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/components/sync_settings_theme_data.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_status_formatter.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_ui_coordinator.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/features/premium/data/payment_service.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_toast.dart';

import '../application/sync_settings_form_controller.dart';
import 'widgets/sync_settings_widgets.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  /// 表单控制器：持有 8 个输入控制器与 autoSync/compressImages/syncType 草稿状态。
  late final SyncSettingsFormController controller;

  bool _isLoading = false;
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    final config = Provider.of<SyncProvider>(context, listen: false).config;
    controller = SyncSettingsFormController(config: config);
    Future<void>.microtask(_loadInitialConfig);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    if (_isBootstrapping) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final provider = Provider.of<SyncProvider>(context, listen: false);
    final outcome = await controller.saveAndTest(
      SyncProviderGatewayImpl(provider),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    switch (outcome) {
      case SyncFormActionSaved():
        SkeuomorphicToast.success(context, '连接成功，配置已保存');
      case SyncFormActionTestFailed(:final lastError):
        SkeuomorphicToast.error(
          context,
          lastError.isEmpty ? '连接失败，请检查配置' : lastError,
        );
      case SyncFormActionInvalid():
        break;
      case SyncFormActionError():
        SkeuomorphicToast.error(context, '保存失败，请稍后重试');
    }
  }

  Future<void> _syncNow() async {
    if (_isBootstrapping) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final provider = Provider.of<SyncProvider>(context, listen: false);
    try {
      await provider.saveConfig(
        controller.buildConfig(base: provider.config, enabled: true),
      );
      if (!mounted) return;
      // 手动同步的权限前置与结果 Toast 反馈由 SyncUiCoordinator 处理。
      await SyncUiCoordinator(context).runManualSync(provider);
    } catch (e) {
      // 仅意外异常走此路径；连接失败等已由协调器按 typed result 反馈。
      if (mounted) {
        SkeuomorphicToast.error(context, '同步启动失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disableSync() async {
    if (_isBootstrapping) return;
    setState(() => _isLoading = true);
    final provider = Provider.of<SyncProvider>(context, listen: false);
    final outcome = await controller.disableSync(
      SyncProviderGatewayImpl(provider),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    switch (outcome) {
      case SyncFormActionSaved():
        SkeuomorphicToast.info(context, '已停用同步，内容将继续保留在本地');
      case SyncFormActionInvalid():
      case SyncFormActionTestFailed():
      case SyncFormActionError():
        SkeuomorphicToast.error(context, '停用同步失败，请稍后重试');
    }
  }

  Future<void> _loadInitialConfig() async {
    final provider = Provider.of<SyncProvider>(context, listen: false);
    try {
      await provider.waitUntilReady();
    } catch (e) {
      debugPrint('Sync settings bootstrap skipped: $e');
    }
    if (!mounted) return;
    setState(() {
      controller.hydrate(provider.config);
      _isBootstrapping = false;
    });
  }

  Widget _buildLockCard(BuildContext context, SyncSettingsThemeData tc) {
    final textColor = tc.textColor;
    final lockBtnColor = tc.lockBtnColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: textColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              '需要赞助才能使用数据同步',
              style: GoogleFonts.notoSerifSc(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '赞助后即可多端同步日记与随心记',
              style: GoogleFonts.notoSerifSc(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: lockBtnColor,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => Navigator.push(context, AppRoutes.premium()),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: Text(
                    '去赞助',
                    style: GoogleFonts.notoSerifSc(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final provider = Provider.of<SyncProvider>(context);
    final canUse = Provider.of<PaymentService>(
      context,
      listen: true,
    ).canUseProFeatures;
    final theme = settings.currentTheme;

    // 统一配置获取
    final themeData = ThemeRegistry.get(theme);
    final themeConfig = themeData.settings;
    final tc = themeData.syncSettings;
    // SettingsThemeData 在七主题中均完整，保持原 isNotEmpty 恒真分支。
    final activeThumbColor = themeConfig.activeSwitchColor;
    final activeTrackColor = themeConfig.activeTrackColor;

    final titleColor = tc.titleColor;
    final textColor = tc.textColor;
    // 输入域描边与填充继续使用 settings groupDecoration。
    final borderColor = themeConfig.groupDecoration.border!.top.color;
    final fillColor = themeConfig.groupDecoration.color;

    return Stack(
      children: [
        // 1. 背景
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),

        // 2. Visual Effects
        ...AppTheme.getBackgroundOverlays(theme),
        // 3. 内容
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              '数据同步',
              style: GoogleFonts.notoSerifSc(
                color: titleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: AppTheme.getSystemUiOverlayStyle(theme),
            iconTheme: IconThemeData(color: titleColor),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: canUse
              ? (_isBootstrapping
                    ? Center(
                        child: CircularProgressIndicator(color: tc.accentColor),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 协议选择器 (拟物化滑块)
                              _buildSlidingSwitch(tc),

                              SyncTrustStatusCard(
                                cardText: const SyncStatusFormatter()
                                    .buildStatusCard(provider.trustSnapshot),
                                icon: switch (provider.trustSnapshot.state) {
                                  SyncTrustState.notEnabled =>
                                    Icons.cloud_off_outlined,
                                  SyncTrustState.localChangesPending =>
                                    Icons.schedule_outlined,
                                  SyncTrustState.syncing => Icons.sync,
                                  SyncTrustState.syncedSuccessfully =>
                                    Icons.verified_outlined,
                                  SyncTrustState.syncFailed =>
                                    Icons.error_outline,
                                  SyncTrustState.needsAttention =>
                                    Icons.warning_amber_rounded,
                                },
                                accentColor: tc.accentColor,
                                backgroundColor: tc.switchBgColor,
                                borderColor: textColor.withValues(alpha: 0.12),
                                textColor: textColor,
                              ),
                              const SizedBox(height: 24),

                              if (controller.syncType == SyncType.webdav) ...[
                                SyncSettingsSectionTitle(
                                  title: 'WebDAV 服务器配置',
                                  color: textColor,
                                ),
                                const SizedBox(height: 16),
                                SyncSettingsTextField(
                                  controller: controller.serverController,
                                  label: '服务器地址',
                                  hint: '例如: https://dav.jianguoyun.com/dav/',
                                  icon: Icons.link,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  fillColor: fillColor,
                                  validator: controller.validateServerUrl,
                                ),
                                const SizedBox(height: 16),
                                SyncSettingsTextField(
                                  controller: controller.usernameController,
                                  label: '账号 (Email)',
                                  hint: '您的 WebDAV 账号邮箱',
                                  icon: Icons.person_outline,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  fillColor: fillColor,
                                  validator: (value) => controller
                                      .validateRequired(value, '请输入账号'),
                                ),
                                const SizedBox(height: 16),
                                SyncSettingsTextField(
                                  controller: controller.passwordController,
                                  label: '密码 / 应用授权码',
                                  hint: '坚果云请使用"第三方应用密码"',
                                  icon: Icons.lock_outline,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  fillColor: fillColor,
                                  obscureText: true,
                                  validator: (value) => controller
                                      .validateRequired(value, '请输入密码或应用授权码'),
                                ),
                              ] else ...[
                                SyncSettingsSectionTitle(
                                  title: 'S3 对象存储配置',
                                  color: textColor,
                                ),
                                const SizedBox(height: 16),
                                SyncSettingsTextField(
                                  controller: controller.s3EndPointController,
                                  label: 'Endpoint (API 地址)',
                                  hint:
                                      '例如: play.min.io 或 oss-cn-hangzhou.aliyuncs.com',
                                  icon: Icons.dns_outlined,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  fillColor: fillColor,
                                  validator: (value) =>
                                      controller.validateRequired(
                                        value,
                                        '请输入 Endpoint 地址',
                                      ),
                                ),
                                const SizedBox(height: 16),
                                SyncSettingsTextField(
                                  controller: controller.s3BucketController,
                                  label: 'Bucket (存储桶名称)',
                                  hint: '例如: paper-whisper-backup',
                                  icon: Icons.folder_open_outlined,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  fillColor: fillColor,
                                  validator: (value) => controller
                                      .validateRequired(value, '请输入 Bucket 名称'),
                                ),
                                const SizedBox(height: 16),
                                SyncSettingsTextField(
                                  controller: controller.s3AccessKeyController,
                                  label: 'Access Key (访问密钥)',
                                  hint: 'AK...',
                                  icon: Icons.vpn_key_outlined,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  fillColor: fillColor,
                                  validator: (value) =>
                                      controller.validateRequired(
                                        value,
                                        '请输入 Access Key',
                                      ),
                                ),
                                const SizedBox(height: 16),
                                SyncSettingsTextField(
                                  controller: controller.s3SecretKeyController,
                                  label: 'Secret Key (私有密钥)',
                                  hint: 'SK...',
                                  icon: Icons.password_outlined,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  fillColor: fillColor,
                                  obscureText: true,
                                  validator: (value) =>
                                      controller.validateRequired(
                                        value,
                                        '请输入 Secret Key',
                                      ),
                                ),
                                const SizedBox(height: 16),
                                SyncSettingsTextField(
                                  controller: controller.s3RegionController,
                                  label: 'Region (区域 - 可选)',
                                  hint: '默认自动，如 us-east-1',
                                  icon: Icons.map_outlined,
                                  textColor: textColor,
                                  borderColor: borderColor,
                                  fillColor: fillColor,
                                ),
                              ],

                              const SizedBox(height: 24),

                              Container(
                                decoration: BoxDecoration(
                                  color: tc.switchBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: textColor.withValues(alpha: 0.1),
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: SwitchListTile(
                                    value: controller.autoSync,
                                    onChanged: (val) => setState(
                                      () => controller.autoSync = val,
                                    ),
                                    activeThumbColor: activeThumbColor,
                                    activeTrackColor: activeTrackColor,
                                    title: Text(
                                      '开启自动同步',
                                      style: GoogleFonts.notoSerifSc(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '开启后会在保存内容、回到前台等时机排队同步。\n关闭后只保留本地更改，等待你手动同步。',
                                        style: GoogleFonts.notoSerifSc(
                                          color: textColor.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 图片压缩开关
                              Container(
                                decoration: BoxDecoration(
                                  color: tc.switchBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: textColor.withValues(alpha: 0.1),
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: SwitchListTile(
                                    value: controller.compressImages,
                                    onChanged: (val) => setState(
                                      () => controller.compressImages = val,
                                    ),
                                    activeThumbColor: activeThumbColor,
                                    activeTrackColor: activeTrackColor,
                                    title: Text(
                                      '开启图片压缩',
                                      style: GoogleFonts.notoSerifSc(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '开启后将压缩上传，显著节省云端存储和流量 (推荐)。\n关闭则上传原图，画质更好但耗流量。',
                                        style: GoogleFonts.notoSerifSc(
                                          color: textColor.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // 功能按钮区
                              Row(
                                children: [
                                  Expanded(
                                    child: SyncSettingsActionButton(
                                      label: '测试连接',
                                      onTap: _isLoading ? null : _saveAndTest,
                                      isPrimary: false,
                                      primaryGradient: tc.primaryGradient,
                                      primaryBtnColor: tc.primaryBtnColor,
                                      primaryShadowColor: tc.primaryShadowColor,
                                      secondaryBtnColor: tc.secondaryBtnColor,
                                      secondaryBtnTextColor:
                                          tc.secondaryBtnTextColor,
                                      secondaryBorderColor:
                                          tc.secondaryBorderColor,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: SyncSettingsActionButton(
                                      label: '立即同步',
                                      onTap: _isLoading ? null : _syncNow,
                                      isPrimary: true,
                                      primaryGradient: tc.primaryGradient,
                                      primaryBtnColor: tc.primaryBtnColor,
                                      primaryShadowColor: tc.primaryShadowColor,
                                      secondaryBtnColor: tc.secondaryBtnColor,
                                      secondaryBtnTextColor:
                                          tc.secondaryBtnTextColor,
                                      secondaryBorderColor:
                                          tc.secondaryBorderColor,
                                    ),
                                  ),
                                ],
                              ),

                              if (provider.config.enabled) ...[
                                const SizedBox(height: 12),
                                SyncSettingsActionButton(
                                  label: '停用同步',
                                  onTap: _isLoading ? null : _disableSync,
                                  isPrimary: false,
                                  primaryGradient: tc.primaryGradient,
                                  primaryBtnColor: tc.primaryBtnColor,
                                  primaryShadowColor: tc.primaryShadowColor,
                                  secondaryBtnColor: tc.secondaryBtnColor,
                                  secondaryBtnTextColor:
                                      tc.secondaryBtnTextColor,
                                  secondaryBorderColor: tc.secondaryBorderColor,
                                ),
                              ],

                              if (_isLoading ||
                                  provider.status == SyncStatus.syncing)
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        provider.progressMessage.isEmpty
                                            ? '正在处理...'
                                            : provider.progressMessage,
                                        style: GoogleFonts.notoSerifSc(
                                          color: textColor.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),

                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: provider.totalProgress > 0
                                              ? provider.totalProgress
                                              : null,
                                          backgroundColor: textColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          color: tc.accentColor,
                                          minHeight: 6,
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              provider.currentFileSpeed,
                                              style: GoogleFonts.robotoMono(
                                                color: textColor.withValues(
                                                  alpha: 0.6,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (provider
                                                .etaMessage
                                                .isNotEmpty) ...[
                                              Text(
                                                '  |  ',
                                                style: TextStyle(
                                                  color: textColor.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                provider.etaMessage,
                                                style: GoogleFonts.notoSerifSc(
                                                  color: textColor.withValues(
                                                    alpha: 0.7,
                                                  ),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 40),
                              SyncSettingsTips(
                                textColor: textColor,
                                backgroundColor: tc.tipsBgColor,
                                syncType: controller.syncType,
                              ),
                            ],
                          ),
                        ),
                      ))
              : _buildLockCard(context, tc),
        ),
      ],
    );
  }

  /// 协议切换：先更新草稿协议（与 controller 同源），再持久化；
  /// 保存为 fire-and-forget，失败时由下次进入页面的 hydrate 回填真实协议。
  void _selectProtocol(SyncType type) {
    setState(() => controller.setSyncType(type));
    final provider = Provider.of<SyncProvider>(context, listen: false);
    provider.saveConfig(provider.config.copyWith(syncType: type));
  }

  Widget _buildSlidingSwitch(SyncSettingsThemeData tc) {
    final trackColor = tc.switchTrackColor;
    final thumbColor = tc.switchThumbColor;
    final activeTextColor = tc.switchActiveText;
    final inactiveTextColor = tc.switchInactiveText;
    final double slidingSwitchShadowOpacity = tc.slidingSwitchShadowOpacity;
    final double thumbShadowOpacity = tc.thumbShadowOpacity;

    final isWebDav = controller.syncType == SyncType.webdav;
    return Center(
      child: Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: slidingSwitchShadowOpacity),
              offset: const Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                // 1. Thumb (Animated)
                AnimatedAlign(
                  alignment: isWebDav
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: segmentWidth,
                    height: double.infinity,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: thumbShadowOpacity,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Labels (Interactive)
                Row(
                  children: [
                    SyncSettingsSwitchLabel(
                      text: 'WebDAV',
                      isActive: isWebDav,
                      activeColor: activeTextColor,
                      inactiveColor: inactiveTextColor,
                      onTap: () => _selectProtocol(SyncType.webdav),
                    ),
                    SyncSettingsSwitchLabel(
                      text: 'S3 存储',
                      isActive: !isWebDav,
                      activeColor: activeTextColor,
                      inactiveColor: inactiveTextColor,
                      onTap: () => _selectProtocol(SyncType.s3),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
