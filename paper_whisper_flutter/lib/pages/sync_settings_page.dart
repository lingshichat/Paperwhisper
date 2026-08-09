import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/sync_config.dart';
import '../models/sync_trust_snapshot.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/payment_service.dart';
import '../features/sync/presentation/sync_ui_coordinator.dart';
import '../features/sync/presentation/sync_status_formatter.dart';
import '../widgets/skeuomorphic_toast.dart';
import 'premium_membership_page.dart';
import '../widgets/slide_page_route.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serverController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  // S3 Controllers
  late TextEditingController _s3EndPointController;
  late TextEditingController _s3AccessKeyController;
  late TextEditingController _s3SecretKeyController;
  late TextEditingController _s3BucketController;
  late TextEditingController _s3RegionController;

  bool _autoSync = false;
  bool _compressImages = true;
  bool _isLoading = false;
  bool _isBootstrapping = true;

  @override
  void initState() {
    super.initState();
    final config = Provider.of<SyncProvider>(context, listen: false).config;
    _serverController = TextEditingController(text: config.serverUrl);
    _usernameController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);

    _s3EndPointController = TextEditingController(text: config.s3EndPoint);
    _s3AccessKeyController = TextEditingController(text: config.s3AccessKey);
    _s3SecretKeyController = TextEditingController(text: config.s3SecretKey);
    _s3BucketController = TextEditingController(text: config.s3BucketName);
    _s3RegionController = TextEditingController(text: config.s3Region ?? '');

    _autoSync = config.autoSync;
    _compressImages = config.compressImages;

    Future<void>.microtask(_loadInitialConfig);
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _s3EndPointController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _s3BucketController.dispose();
    _s3RegionController.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    if (_isBootstrapping) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<SyncProvider>(context, listen: false);
    final newConfig = _buildDraftConfig(provider, enabled: true);

    try {
      await provider.saveConfig(newConfig);
      final success = await provider.connect();

      if (!mounted) return;

      setState(() => _isLoading = false);
      if (success) {
        SkeuomorphicToast.success(context, '连接成功，配置已保存');
      } else {
        SkeuomorphicToast.error(
          context,
          provider.lastError.isEmpty ? '连接失败，请检查配置' : provider.lastError,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SkeuomorphicToast.error(context, '保存失败，请稍后重试');
    }
  }

  Future<void> _syncNow() async {
    if (_isBootstrapping) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = Provider.of<SyncProvider>(context, listen: false);
    try {
      await provider.saveConfig(_buildDraftConfig(provider, enabled: true));
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
    try {
      await provider.saveConfig(_buildDraftConfig(provider, enabled: false));
      if (!mounted) return;
      SkeuomorphicToast.info(context, '已停用同步，内容将继续保留在本地');
    } catch (e) {
      if (!mounted) return;
      SkeuomorphicToast.error(context, '停用同步失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final config = provider.config;
    setState(() {
      _serverController.text = config.serverUrl;
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _s3EndPointController.text = config.s3EndPoint;
      _s3AccessKeyController.text = config.s3AccessKey;
      _s3SecretKeyController.text = config.s3SecretKey;
      _s3BucketController.text = config.s3BucketName;
      _s3RegionController.text = config.s3Region ?? '';
      _autoSync = config.autoSync;
      _compressImages = config.compressImages;
      _isBootstrapping = false;
    });
  }

  SyncConfig _buildDraftConfig(SyncProvider provider, {required bool enabled}) {
    return provider.config.copyWith(
      serverUrl: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      autoSync: _autoSync,
      compressImages: _compressImages,
      enabled: enabled,
      s3EndPoint: _s3EndPointController.text.trim(),
      s3AccessKey: _s3AccessKeyController.text.trim(),
      s3SecretKey: _s3SecretKeyController.text.trim(),
      s3BucketName: _s3BucketController.text.trim(),
      s3Region: _s3RegionController.text.trim().isEmpty
          ? null
          : _s3RegionController.text.trim(),
    );
  }

  String? _validateRequiredField(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  String? _validateServerUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '请输入服务器地址';
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return '服务器地址需以 http:// 或 https:// 开头';
    }
    return null;
  }

  Widget _buildLockCard(BuildContext context, Map<String, dynamic> tc) {
    final textColor = tc['textColor'] as Color;
    final lockBtnColor = tc['lockBtnColor'] as Color;

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
                onTap: () => Navigator.push(
                  context,
                  SlidePageRoute(page: const PremiumMembershipPage()),
                ),
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
    final themeConfig = AppTheme.getSettingsTheme(theme);
    final tc = AppTheme.getSyncSettingsTheme(theme);

    final Color titleColor = tc['titleColor'];
    final Color textColor = tc['textColor'];

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
                        child: CircularProgressIndicator(
                          color: tc['accentColor'] as Color,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 协议选择器 (拟物化滑块)
                              _buildSlidingSwitch(provider, tc),

                              _buildTrustStatusCard(provider, tc, textColor),
                              const SizedBox(height: 24),

                              if (provider.config.syncType ==
                                  SyncType.webdav) ...[
                                _buildSectionTitle('WebDAV 服务器配置', textColor),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _serverController,
                                  label: '服务器地址',
                                  hint: '例如: https://dav.jianguoyun.com/dav/',
                                  tc: tc,
                                  themeConfig: themeConfig,
                                  icon: Icons.link,
                                  validator: _validateServerUrl,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _usernameController,
                                  label: '账号 (Email)',
                                  hint: '您的 WebDAV 账号邮箱',
                                  tc: tc,
                                  themeConfig: themeConfig,
                                  icon: Icons.person_outline,
                                  validator: (value) =>
                                      _validateRequiredField(value, '请输入账号'),
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _passwordController,
                                  label: '密码 / 应用授权码',
                                  hint: '坚果云请使用"第三方应用密码"',
                                  tc: tc,
                                  themeConfig: themeConfig,
                                  icon: Icons.lock_outline,
                                  obscureText: true,
                                  validator: (value) => _validateRequiredField(
                                    value,
                                    '请输入密码或应用授权码',
                                  ),
                                ),
                              ] else ...[
                                _buildSectionTitle('S3 对象存储配置', textColor),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _s3EndPointController,
                                  label: 'Endpoint (API 地址)',
                                  hint:
                                      '例如: play.min.io 或 oss-cn-hangzhou.aliyuncs.com',
                                  tc: tc,
                                  themeConfig: themeConfig,
                                  icon: Icons.dns_outlined,
                                  validator: (value) => _validateRequiredField(
                                    value,
                                    '请输入 Endpoint 地址',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _s3BucketController,
                                  label: 'Bucket (存储桶名称)',
                                  hint: '例如: paper-whisper-backup',
                                  tc: tc,
                                  themeConfig: themeConfig,
                                  icon: Icons.folder_open_outlined,
                                  validator: (value) => _validateRequiredField(
                                    value,
                                    '请输入 Bucket 名称',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _s3AccessKeyController,
                                  label: 'Access Key (访问密钥)',
                                  hint: 'AK...',
                                  tc: tc,
                                  themeConfig: themeConfig,
                                  icon: Icons.vpn_key_outlined,
                                  validator: (value) => _validateRequiredField(
                                    value,
                                    '请输入 Access Key',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _s3SecretKeyController,
                                  label: 'Secret Key (私有密钥)',
                                  hint: 'SK...',
                                  tc: tc,
                                  themeConfig: themeConfig,
                                  icon: Icons.password_outlined,
                                  obscureText: true,
                                  validator: (value) => _validateRequiredField(
                                    value,
                                    '请输入 Secret Key',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _s3RegionController,
                                  label: 'Region (区域 - 可选)',
                                  hint: '默认自动，如 us-east-1',
                                  tc: tc,
                                  themeConfig: themeConfig,
                                  icon: Icons.map_outlined,
                                ),
                              ],

                              const SizedBox(height: 24),

                              Container(
                                decoration: BoxDecoration(
                                  color: tc['switchBgColor'],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: textColor.withValues(alpha: 0.1),
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: SwitchListTile(
                                    value: _autoSync,
                                    onChanged: (val) =>
                                        setState(() => _autoSync = val),
                                    activeThumbColor: themeConfig.isNotEmpty
                                        ? themeConfig['activeSwitchColor']
                                        : tc['accentColor'],
                                    activeTrackColor: themeConfig.isNotEmpty
                                        ? themeConfig['activeTrackColor']
                                        : (tc['accentColor'] as Color)
                                              .withValues(alpha: 0.5),
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
                                  color: tc['switchBgColor'],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: textColor.withValues(alpha: 0.1),
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: SwitchListTile(
                                    value: _compressImages,
                                    onChanged: (val) =>
                                        setState(() => _compressImages = val),
                                    activeThumbColor: themeConfig.isNotEmpty
                                        ? themeConfig['activeSwitchColor']
                                        : tc['accentColor'],
                                    activeTrackColor: themeConfig.isNotEmpty
                                        ? themeConfig['activeTrackColor']
                                        : (tc['accentColor'] as Color)
                                              .withValues(alpha: 0.5),
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
                                    child: _buildButton(
                                      label: '测试连接',
                                      onTap: _isLoading ? null : _saveAndTest,
                                      isPrimary: false,
                                      tc: tc,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildButton(
                                      label: '立即同步',
                                      onTap: _isLoading ? null : _syncNow,
                                      isPrimary: true,
                                      tc: tc,
                                    ),
                                  ),
                                ],
                              ),

                              if (provider.config.enabled) ...[
                                const SizedBox(height: 12),
                                _buildButton(
                                  label: '停用同步',
                                  onTap: _isLoading ? null : _disableSync,
                                  isPrimary: false,
                                  tc: tc,
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
                                      // Action Text
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

                                      // Progress Bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: provider.totalProgress > 0
                                              ? provider.totalProgress
                                              : null,
                                          backgroundColor: textColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          color: tc['accentColor'],
                                          minHeight: 6,
                                        ),
                                      ),

                                      // Speed & ETA Text
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
                              _buildTips(
                                textColor,
                                tc,
                                provider.config.syncType,
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

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.notoSerifSc(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTrustStatusCard(
    SyncProvider provider,
    Map<String, dynamic> tc,
    Color textColor,
  ) {
    final snapshot = provider.trustSnapshot;

    IconData icon;
    switch (snapshot.state) {
      case SyncTrustState.notEnabled:
        icon = Icons.cloud_off_outlined;
        break;
      case SyncTrustState.localChangesPending:
        icon = Icons.schedule_outlined;
        break;
      case SyncTrustState.syncing:
        icon = Icons.sync;
        break;
      case SyncTrustState.syncedSuccessfully:
        icon = Icons.verified_outlined;
        break;
      case SyncTrustState.syncFailed:
        icon = Icons.error_outline;
        break;
      case SyncTrustState.needsAttention:
        icon = Icons.warning_amber_rounded;
        break;
    }

    // 状态卡文案（title + lines）逐字委托 SyncStatusFormatter
    // （sync_settings 风格：分钟补零）；icon 与颜色仍由页面决定。
    final cardText = const SyncStatusFormatter().buildStatusCard(snapshot);
    final String title = cardText.title;
    final lines = cardText.lines;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc['switchBgColor'],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (tc['accentColor'] as Color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tc['accentColor'], size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.notoSerifSc(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (lines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: GoogleFonts.notoSerifSc(
                          color: textColor.withValues(alpha: 0.75),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Map<String, dynamic> tc,
    required Map<String, dynamic> themeConfig,
    required IconData icon,
    bool obscureText = false,
    FormFieldValidator<String>? validator,
  }) {
    final textColor = tc['textColor'] as Color;
    final hintColor = textColor.withValues(alpha: 0.5);

    final borderSide = BorderSide(
      color: themeConfig.isNotEmpty
          ? themeConfig['groupDecoration'].border.top.color
          : textColor.withValues(
              alpha: 0.2,
            ), // Fallback slightly visible border
    );

    final fillColor = themeConfig.isNotEmpty
        ? themeConfig['groupDecoration'].color
        : tc['switchBgColor'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSerifSc(
            color: textColor.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.fromBorderSide(borderSide),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(color: textColor),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintColor, fontSize: 13),
              prefixIcon: Icon(
                icon,
                color: textColor.withValues(alpha: 0.6),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
    required Map<String, dynamic> tc,
  }) {
    // 按主/次按钮读取相应的配置
    final gradient = isPrimary ? tc['primaryGradient'] as Gradient? : null;
    final color = isPrimary
        ? ((tc['primaryBtnColor'] != null)
              ? tc['primaryBtnColor'] as Color
              : Colors.transparent)
        : tc['secondaryBtnColor'] as Color;
    final textColor = isPrimary
        ? Colors.white
        : tc['secondaryBtnTextColor'] as Color;

    final boxShadows = isPrimary
        ? [
            BoxShadow(
              color: tc['primaryShadowColor'],
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ]
        : null;

    final border = !isPrimary
        ? Border.all(color: tc['secondaryBorderColor'])
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            color: color == Colors.transparent && gradient != null
                ? null
                : color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: boxShadows,
            border: border,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              color: onTap == null
                  ? textColor.withValues(alpha: 0.5)
                  : textColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingSwitch(SyncProvider provider, Map<String, dynamic> tc) {
    final trackColor = tc['switchTrackColor'] as Color;
    final thumbColor = tc['switchThumbColor'] as Color;
    final activeTextColor = tc['switchActiveText'] as Color;
    final inactiveTextColor = tc['switchInactiveText'] as Color;
    final double slidingSwitchShadowOpacity =
        tc['slidingSwitchShadowOpacity'] as double;
    final double thumbShadowOpacity = tc['thumbShadowOpacity'] as double;

    final isWebDav = provider.config.syncType == SyncType.webdav;

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
            final width = constraints.maxWidth;
            final segmentWidth = width / 2;

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
                    _buildSwitchLabel(
                      'WebDAV',
                      isWebDav,
                      activeTextColor,
                      inactiveTextColor,
                      () {
                        if (!isWebDav) {
                          provider.saveConfig(
                            provider.config.copyWith(syncType: SyncType.webdav),
                          );
                        }
                      },
                    ),
                    _buildSwitchLabel(
                      'S3 存储',
                      !isWebDav,
                      activeTextColor,
                      inactiveTextColor,
                      () {
                        if (isWebDav) {
                          provider.saveConfig(
                            provider.config.copyWith(syncType: SyncType.s3),
                          );
                        }
                      },
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

  Widget _buildSwitchLabel(
    String text,
    bool isActive,
    Color activeColor,
    Color inactiveColor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.notoSerifSc(
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _buildTips(
    Color textColor,
    Map<String, dynamic> tc,
    SyncType syncType,
  ) {
    String tips;
    if (syncType == SyncType.webdav) {
      tips =
          '1. 推荐使用坚果云 WebDAV 服务。\n'
          '2. 坚果云服务器地址通常为：https://dav.jianguoyun.com/dav/ \n'
          '3. 密码必须使用坚果云生成的"第三方应用密码"，不可使用登录密码。\n'
          '4. 同步策略：本地和云端双向合并，默认保留最新的修改。';
    } else {
      tips =
          '1. 支持 MinIO, AWS S3, 阿里云 OSS 等兼容 S3 的对象存储。\n'
          '2. Endpoint 为 API 域名 (例如 play.min.io)，Bucket 需提前创建。\n'
          '3. 请确保 Access Key 和 Secret Key 拥有该 Bucket 的读写权限。\n'
          '4. 开启"图片压缩"可显著节省存储空间和流量。';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc['tipsBgColor'],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: textColor.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '小贴士',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tips,
            style: GoogleFonts.notoSerifSc(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
