
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../config/app_theme.dart';
import '../widgets/lock_screen.dart';
import '../widgets/visual_effects.dart';

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
    
    if (mounted) {
      setState(() {
        _isLockEnabled = lock;
        _isBiometricEnabled = bio;
        _canUseBio = canBio;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLock(bool value) async {
    if (value) {
      // Enable -> Setup Flow (Full Screen)
      // Navigate to LockScreen in SETUP mode
      await Navigator.of(context).push(
        PageRouteBuilder(
           pageBuilder: (context, animation, secondaryAnimation) => LockScreen(
             mode: LockScreenMode.setup,
             enableBack: true,
             onUnlocked: () {
               Navigator.pop(context); // Return from LockScreen
             },
           ),
           transitionsBuilder: (context, animation, secondaryAnimation, child) {
             return FadeTransition(opacity: animation, child: child);
           }
        )
      );
      // Refresh state after return (user might have canceled or succeeded)
      await _loadState();
      
    } else {
      // Disable -> Verify Flow first
      await Navigator.of(context).push(
        PageRouteBuilder(
           pageBuilder: (context, animation, secondaryAnimation) => LockScreen(
             mode: LockScreenMode.verify,
             enableBack: true,
             onUnlocked: () async {
                // Verified success
                await _authService.clearLock();
                if (mounted) Navigator.pop(context); // Pop LockScreen
             },
           ),
           transitionsBuilder: (context, animation, secondaryAnimation, child) {
             return FadeTransition(opacity: animation, child: child);
           }
        )
      );
      await _loadState();
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!value) {
      // Disable directly
      await _authService.setBiometricEnabled(false);
      await _loadState();
    } else {
      // Enable: Verify Bio first to ensure it works
      // Push LockScreen? Or just quick check?
      // Better to check quickly here without full screen if possible,
      // BUT for consistency, maybe just show the toast and check locally.
      // Or actually trigger a quick bio check.
      
      final success = await _authService.authenticateBiometric();
      if (success) {
        await _authService.setBiometricEnabled(true);
        await _loadState();
        if (mounted) SkeuomorphicToast.success(context, '指纹解锁已开启');
      } else {
        if (mounted) SkeuomorphicToast.error(context, '验证失败，无法开启');
      }
    }
  }

  Future<void> _changePin() async {
    // 1. Verify Old
    await Navigator.of(context).push(
        PageRouteBuilder(
           pageBuilder: (context, animation, secondaryAnimation) => LockScreen(
             mode: LockScreenMode.verify,
             enableBack: true,
             onUnlocked: () async {
                 // Verified old pin, now go to Setup new pin
                 // We need to replace the current LockScreen(Verify) with LockScreen(Setup)
                 Navigator.pushReplacement(context, 
                    PageRouteBuilder(
                      pageBuilder: (ctx, anim, secAnim) => LockScreen(
                        mode: LockScreenMode.setup,
                        enableBack: true, 
                        onUnlocked: () {
                           Navigator.pop(ctx); // Done setup
                        }
                      ),
                      transitionsBuilder: (ctx, anim, secAnim, child) => FadeTransition(opacity: anim, child: child)
                    )
                 );
             },
           ),
           transitionsBuilder: (context, animation, secondaryAnimation, child) {
             return FadeTransition(opacity: animation, child: child);
           }
        )
      );
      await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<SettingsProvider>(context);
    final canUsePro = Provider.of<PaymentService>(context, listen: true).canUseProFeatures;
    final theme = themeProvider.currentTheme;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;
    
    final textColor = AppTheme.getTextColor(theme);
    final bgColor = AppTheme.getPaperColor(theme);

    Widget content = Scaffold(
      appBar: AppBar(
        title: Text('密码锁', style: GoogleFonts.notoSerifSc(color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      backgroundColor: bgColor,
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSkeuomorphicTile(
            title: '启用安全锁',
            subtitle: '启动应用时需验证密码',
            value: _isLockEnabled,
            onChanged: (v) => _toggleLock(v),
            theme: theme,
          ),
          
          if (_isLockEnabled && _canUseBio) ...[
             const SizedBox(height: 16),
             _buildSkeuomorphicTile(
               title: '使用生物识别',
               subtitle: canUsePro ? '解锁更快、更安全' : '赞助后可用',
               value: _isBiometricEnabled,
               onChanged: canUsePro ? (v) => _toggleBiometric(v) : null,
               theme: theme,
             ),
          ],
          
          if (_isLockEnabled) ...[
            const SizedBox(height: 32),
            InkWell(
              onTap: _changePin,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textColor.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("修改密码", style: GoogleFonts.notoSerifSc(fontSize: 16, color: textColor)),
                    Icon(Icons.arrow_forward_ios, size: 16, color: textColor.withOpacity(0.5))
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );

    return Stack(
      children: [
        // 1. Background
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),
        
        // 2. Visual Effects
        if (isSeaFlower) Positioned.fill(child: const PetalRainWidget()),
        if (isMidnight) Positioned.fill(child: const StarrySkyWidget()),
        
        // 3. Content
        Positioned.fill(child: content),
      ],
    );
  }
  
  Widget _buildSkeuomorphicTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    required String theme,
  }) {
    final textColor = AppTheme.getTextColor(theme);
    final accentColor = AppTheme.getAccentColor(theme);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Add spacing between tiles
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.05), // Slightly stronger fill
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.15)), // Much stronger border
      ),
      child: SwitchListTile(
        title: Text(title, style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Text(subtitle, style: GoogleFonts.notoSerifSc(fontSize: 12, color: textColor.withOpacity(0.6))),
        value: value,
        onChanged: onChanged,
        activeColor: accentColor,
        activeTrackColor: accentColor.withOpacity(0.2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }
}
