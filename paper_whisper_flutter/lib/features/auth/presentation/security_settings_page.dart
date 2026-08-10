import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/components/settings_theme_data.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/services/auth_service.dart';
import 'package:paper_whisper_flutter/services/payment_service.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_toast.dart';
import 'package:paper_whisper_flutter/shared/widgets/visual_effects.dart';

import 'widgets/lock_screen.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _canUseBio = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final lock = await _authService.isLockEnabled();
    final bio = await _authService.isBiometricEnabled();
    final canBio = await _authService.canCheckBiometrics();

    if (!mounted) return;
    setState(() {
      _isLockEnabled = lock;
      _isBiometricEnabled = bio;
      _canUseBio = canBio;
      _isLoading = false;
    });
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      // 启用密码锁时进入设置流程
      await Navigator.of(context).push(
        AppRoutes.pageFadeBuilder(
          (routeContext) => LockScreen(
            mode: LockScreenMode.setup,
            enableBack: true,
            onUnlocked: () {
              Navigator.pop(routeContext);
            },
          ),
        ),
      );
      await _loadState();
      return;
    }

    // 关闭密码锁前先验证一次
    await Navigator.of(context).push(
      AppRoutes.pageFadeBuilder(
        (routeContext) => LockScreen(
          mode: LockScreenMode.verify,
          enableBack: true,
          onUnlocked: () async {
            await _authService.clearLock();
            if (routeContext.mounted) {
              Navigator.pop(routeContext);
            }
          },
        ),
      ),
    );
    await _loadState();
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!value) {
      await _authService.setBiometricEnabled(false);
      await _loadState();
      return;
    }

    final success = await _authService.authenticateBiometric();
    if (success) {
      await _authService.setBiometricEnabled(true);
      await _loadState();
      if (mounted) {
        SkeuomorphicToast.success(context, '生物识别已开启');
      }
      return;
    }

    if (mounted) {
      SkeuomorphicToast.error(context, '验证失败，无法开启');
    }
  }

  Future<void> _changePin() async {
    await Navigator.of(context).push(
      AppRoutes.pageFadeBuilder(
        (outerRouteContext) => LockScreen(
          mode: LockScreenMode.verify,
          enableBack: true,
          onUnlocked: () async {
            Navigator.pushReplacement(
              outerRouteContext,
              AppRoutes.pageFadeBuilder(
                (innerRouteContext) => LockScreen(
                  mode: LockScreenMode.setup,
                  enableBack: true,
                  onUnlocked: () {
                    Navigator.pop(innerRouteContext);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final canUsePro = Provider.of<PaymentService>(context).canUseProFeatures;
    final theme = settingsProvider.currentTheme;
    final headerColors = ThemeRegistry.get(theme).mobileHeader;
    final themeConfig = ThemeRegistry.get(theme).settings;
    final activeSwitchColor = themeConfig.activeSwitchColor;

    final content = Scaffold(
      appBar: AppBar(
        title: Text(
          '密码锁',
          style: GoogleFonts.notoSerifSc(color: headerColors.titleColor),
        ),
        backgroundColor: headerColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: headerColors.iconColor),
        centerTitle: true,
      ),
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(activeSwitchColor),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSecuritySwitchTile(
                  icon: Icons.lock_outline,
                  title: '启用安全锁',
                  subtitle: '启动应用时需验证密码',
                  value: _isLockEnabled,
                  onChanged: _toggleLock,
                  themeConfig: themeConfig,
                ),
                if (_isLockEnabled && _canUseBio) ...[
                  const SizedBox(height: 16),
                  _buildSecuritySwitchTile(
                    icon: Icons.fingerprint_rounded,
                    title: '使用生物识别',
                    subtitle: canUsePro ? '解锁更快、更安全' : '赞助后可用',
                    value: _isBiometricEnabled,
                    onChanged: canUsePro ? _toggleBiometric : null,
                    themeConfig: themeConfig,
                  ),
                ],
                if (_isLockEnabled) ...[
                  const SizedBox(height: 16),
                  _buildActionTile(
                    icon: Icons.password_outlined,
                    title: '修改密码',
                    subtitle: '重新设置应用锁密码',
                    onTap: _changePin,
                    themeConfig: themeConfig,
                  ),
                ],
              ],
            ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),
        if (themeConfig.showPetalRain)
          Positioned.fill(child: const PetalRainWidget()),
        if (themeConfig.showStarrySky)
          Positioned.fill(child: const StarrySkyWidget()),
        Positioned.fill(child: content),
      ],
    );
  }

  Widget _buildSecuritySwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required SettingsThemeData themeConfig,
  }) {
    final textColor = themeConfig.textColor;
    final iconColor = themeConfig.iconColor;
    final activeThumbColor = themeConfig.activeSwitchColor;
    final activeTrackColor = themeConfig.activeTrackColor;

    return Container(
      decoration: themeConfig.groupDecoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            _buildTileIcon(icon: icon, iconColor: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeThumbColor,
              activeTrackColor: activeTrackColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required SettingsThemeData themeConfig,
  }) {
    final textColor = themeConfig.textColor;
    final iconColor = themeConfig.iconColor;

    return Container(
      decoration: themeConfig.groupDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _buildTileIcon(icon: icon, iconColor: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTileIcon({required IconData icon, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 22, color: iconColor),
    );
  }
}
