import 'dart:math';
import 'dart:ui' as ui; // Prefix to avoid TextStyle conflict
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'package:paper_whisper_flutter/config/app_theme.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/auth/application/lock_controller.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/widgets/skeuomorphic_toast.dart';
import 'animated_fingerprint.dart';

// LockScreenMode 所有权位于 features/auth/application/，此处 re-export
// 保证只 import lock_screen.dart 的调用方继续可见，不破坏现有引用。
export 'package:paper_whisper_flutter/features/auth/application/lock_controller.dart'
    show LockScreenMode;

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final bool enableBack; // If false, user cannot pop (for App Resume lock)
  final LockScreenMode mode; // Default to unlock

  /// 测试注入的控制器；为 null 时生产自建并仅 dispose 自有实例。
  final LockController? controller;

  const LockScreen({
    super.key,
    required this.onUnlocked,
    this.enableBack = false,
    this.mode = LockScreenMode.unlock,
    this.controller,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  late final LockController _controller;
  late final bool _ownsController;

  // Animations
  late AnimationController _shakeController; // Error shake

  late AnimationController _fingerprintEntryController; // Biometric entry
  late Animation<double> _fingerprintScale;
  late Animation<double> _fingerprintOpacity;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? LockController(mode: widget.mode);

    // Shake Animation
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Simple sine wave shake is handled in build, controller just drives 0->1

    // Biometric Entry Animation (Silky smooth)
    _fingerprintEntryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fingerprintScale = CurvedAnimation(
      parent: _fingerprintEntryController,
      curve: Curves.easeOutQuart,
    );
    _fingerprintOpacity = CurvedAnimation(
      parent: _fingerprintEntryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _initAuth();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _shakeController.dispose();
    _fingerprintEntryController.dispose();
    super.dispose();
  }

  Future<void> _initAuth() async {
    // 控制器负责 visible 标记与生物识别可用性查询（仅 unlock 模式）
    try {
      await _controller.initialize();
    } on StateError {
      return; // 页面已释放，静默
    }
    if (!mounted) return;

    setState(() {}); // 反映 biometricAvailable / useBiometric

    if (_controller.useBiometric) {
      _fingerprintEntryController.forward(); // Play entry animation

      // Auto-trigger with delay for smooth entry（保留原 500ms 时序）
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _controller.useBiometric) {
          _triggerBiometric();
        }
      });
    }
  }

  Future<void> _triggerBiometric() async {
    // Delay slightly to let animation play and UI settle
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || !_controller.useBiometric) return;

    final LockBiometricResult result;
    try {
      result = await _controller.authenticateBiometric();
    } on StateError {
      return; // 页面已释放，静默
    }
    if (!mounted) return;
    if (result == LockBiometricResult.authenticated) {
      _finish();
    }
    // failed：停留在当前界面，可点击重试或改用密码
  }

  void _finish() {
    // controller 已在成功路径调用 unlockApp，页面只触发回调，不重复解锁
    widget.onUnlocked();
  }

  // --- Logic ---

  void _onKeyTap(String value) {
    // 满 pinLength 位后不再触发多余 haptic（恢复旧 length<4 行为）
    if (_controller.inputPin.length >= _controller.pinLength) return;
    HapticFeedback.lightImpact(); // Physical feel
    final result = _controller.appendDigit(value);
    if (mounted) setState(() {}); // 刷新输入显示

    if (result == PinKeyResult.readyToSubmit) {
      _onSubmitPin();
    }
  }

  void _onDelete() {
    if (_controller.inputPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      _controller.delete();
      if (mounted) setState(() {});
    }
  }

  Future<void> _onSubmitPin() async {
    // Wait a brief moment to show the last digit
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final LockSubmitResult result;
    try {
      result = await _controller.submit();
    } on StateError {
      return; // 页面已释放，静默
    }
    if (!mounted) return;

    switch (result) {
      case LockUnlocked():
        // unlock / verify 校验通过（controller 已 unlockApp）
        HapticFeedback.mediumImpact(); // Success clunk
        _finish();
      case LockInvalid():
        // 校验失败，controller 已清空输入
        _onError();
      case LockAwaitConfirmation():
        // setup 第一步完成，已进入 confirm：刷新标题
        setState(() {});
      case LockSetupCompleted():
        // 两次一致（controller 已 setPin + unlockApp）
        HapticFeedback.mediumImpact();
        if (mounted) SkeuomorphicToast.success(context, "密码设置成功");
        _finish();
      case LockMismatch():
        // 两次不一致：controller 已重置回 setup 并清空输入
        if (mounted) SkeuomorphicToast.error(context, "两次输入不一致");
        _onError();
    }
  }

  void _onError() {
    HapticFeedback.heavyImpact(); // Error rattle
    _shakeController.forward(from: 0.0);
    if (mounted) setState(() {}); // 输入已由 controller 清空
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    // Theme Adaptation
    final themeProvider = Provider.of<SettingsProvider>(context);
    final theme = themeProvider.currentTheme;

    // Background Determination
    BoxDecoration bgDecor = AppTheme.getBackground(theme);

    // Overlay for contrast (Glass effect)
    final themeConfig = ThemeRegistry.get(theme).lockScreen;
    Color overlayColor = themeConfig.displayBg != null
        ? themeConfig.displayBg!.withValues(
            alpha: 0.1,
          ) // Derive from displayBg or use default
        : (theme == AppTheme.themeSeaFlower
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.3));

    return PopScope(
      canPop: widget.enableBack,
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor:
            Colors.transparent, // Important for background pass-through
        body: Container(
          decoration: bgDecor, // Theme background
          child: Stack(
            children: [
              // Blurry Glass Effect
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(color: overlayColor),
              ),

              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        children: [
                          // 1. PIN Mode: Top Spacing & Display Window
                          if (!_controller.useBiometric) ...[
                            const SizedBox(height: 60),
                            _buildDisplayWindow(theme),
                            const Spacer(),
                          ],

                          // 2. Biometric Mode: Top Spacer to center content
                          if (_controller.useBiometric) const Spacer(),

                          // 3. Main Content
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: _controller.useBiometric
                                ? _buildBiometricControls(theme)
                                : _buildKeypad(theme),
                          ),

                          // 4. Biometric Mode: Bottom Spacer to center content
                          if (_controller.useBiometric) const Spacer(),

                          // 5. PIN Mode: Bottom Spacing
                          if (!_controller.useBiometric)
                            const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Back Button (if enabled)
              if (widget.enableBack)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color:
                          (theme == AppTheme.themeDefault
                                  ? const Color(0xFFF4ECD8)
                                  : AppTheme.getTextColor(theme))
                              .withValues(alpha: 0.7),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayWindow(String theme) {
    String title = "请输入密码";
    if (_controller.mode == LockScreenMode.setup) title = "请设置新密码";
    if (_controller.mode == LockScreenMode.confirm) title = "请再次确认密码";
    if (_controller.mode == LockScreenMode.verify) title = "验证旧密码";
    if (_controller.useBiometric) title = "验证身份";

    final textColor = AppTheme.getTextColor(theme);
    final themeConfig = ThemeRegistry.get(theme).lockScreen;

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final offset = sin(_shakeController.value * pi * 4) * 10;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.notoSerifSc(
              fontSize: 18,
              color:
                  (theme == AppTheme.themeDefault
                          ? const Color(0xFFF4ECD8)
                          : textColor)
                      .withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),

          if (theme == AppTheme.themeGardenOfWords)
            _buildDigitalDisplay(theme)
          else if (themeConfig.displayBg != null)
            _buildDigitalDisplay(theme)
          else if (theme == AppTheme.themeDefault)
            _buildVintageDisplay()
          else if (theme == AppTheme.themeSeaFlower)
            _buildPearlDisplay()
          else
            _buildDigitalDisplay(theme),
        ],
      ),
    );
  }

  Widget _buildVintageDisplay() {
    return Container(
      width: 220,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Bronze Frame
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8D6E63), Color(0xFF4E342E)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4), // Frame width
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF150D0A), // Deep dark brown slot
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 2), // Inner bezel
          gradient: const RadialGradient(
            colors: [Color(0xFF251A15), Color(0xFF050302)],
            radius: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_controller.pinLength, (index) {
            final bool filled = index < _controller.inputPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? const Color(0xFFFF3D00)
                    : const Color(0xFF1a100d), // Red filament vs Off
                boxShadow: filled
                    ? [
                        const BoxShadow(
                          color: Color(0xFFFF3D00),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ), // Glow
                      ]
                    : [
                        const BoxShadow(
                          color: Colors.black,
                          offset: Offset(0, 1),
                          blurRadius: 1,
                        ), // Socket depth
                      ],
                border: Border.all(
                  color: filled
                      ? const Color(0xFFFFCCBC)
                      : const Color(0xFF3E2723),
                  width: 1.5,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDigitalDisplay(String theme) {
    final themeConfig = ThemeRegistry.get(theme).lockScreen;
    final accent = themeConfig.accentColor ?? AppTheme.getAccentColor(theme);
    final bg = themeConfig.displayBg ?? Colors.black.withValues(alpha: 0.3);
    final border = themeConfig.displayBorder ?? accent.withValues(alpha: 0.2);

    return Container(
      width: 200,
      height: 60,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border, width: 1),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_controller.pinLength, (index) {
          final bool filled = index < _controller.inputPin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? accent : Colors.transparent,
              border: Border.all(
                color: filled ? accent : accent.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPearlDisplay() {
    return Container(
      width: 200,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF8BBD0).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFAD1457).withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.2),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_controller.pinLength, (index) {
          final bool filled = index < _controller.inputPin.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? const Color(0xFFEC407A) : const Color(0xFFFCE4EC),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: const Color(0xFFEC407A).withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ]
                  : [],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBiometricControls(String theme) {
    final themeConfig = ThemeRegistry.get(theme).lockScreen;
    Color iconColor = themeConfig.accentColor ?? AppTheme.getAccentColor(theme);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Silky Entry Animation
        ScaleTransition(
          scale: _fingerprintScale,
          child: FadeTransition(
            opacity: _fingerprintOpacity,
            child: GestureDetector(
              onTap: _triggerBiometric,
              child: AnimatedFingerprint(
                size: 160, // Reference size from screenshot
                color: iconColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _triggerBiometric,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '验证身份',
              style: TextStyle(
                color: iconColor.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 48), // Increased spacing
        GestureDetector(
          onTap: () {
            _controller.setUseBiometric(false);
            if (mounted) setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '使用密码',
              style: TextStyle(
                color: theme == AppTheme.themeDefault
                    ? const Color(0xFFF4ECD8).withValues(alpha: 0.9)
                    : AppTheme.getTextColor(theme).withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypad(String theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) => _buildKey(key, theme)).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFunctionKey(
                icon: Icons.fingerprint,
                theme: theme,
                onTap: _controller.biometricAvailable
                    ? () {
                        _controller.setUseBiometric(true);
                        if (mounted) setState(() {});
                      }
                    : null,
                enabled: _controller.biometricAvailable,
              ),
              _buildKey('0', theme),
              _buildFunctionKey(
                icon: Icons.backspace_outlined,
                theme: theme,
                onTap: _onDelete,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKey(String value, String theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SkeuomorphicKey(
        label: value,
        theme: theme,
        onTap: () => _onKeyTap(value),
      ),
    );
  }

  Widget _buildFunctionKey({
    required IconData icon,
    required String theme,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: 72,
        height: 72,
        child: enabled && onTap != null
            ? IconButton(
                icon: Icon(
                  icon,
                  color:
                      (theme == AppTheme.themeDefault
                              ? const Color(0xFFF4ECD8)
                              : AppTheme.getTextColor(theme))
                          .withValues(alpha: 0.6),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
              )
            : const SizedBox(), // Placeholder logic
      ),
    );
  }
}

// Separate Widget for Optimize Rebuilds & State (Pressed)
class SkeuomorphicKey extends StatefulWidget {
  final String label;
  final String theme;
  final VoidCallback onTap;

  const SkeuomorphicKey({
    super.key,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  @override
  State<SkeuomorphicKey> createState() => _SkeuomorphicKeyState();
}

class _SkeuomorphicKeyState extends State<SkeuomorphicKey> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) =>
      setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    if (ThemeRegistry.get(widget.theme).lockScreen.displayBg != null) {
      return _buildFrostedStyle(); // Use frosted style for new themes
    } else if (widget.theme == AppTheme.themeDefault) {
      return _buildVintageStyle();
    } else if (widget.theme == AppTheme.themeSeaFlower) {
      return _buildPearlStyle();
    } else {
      // Midnight, Amber, etc.
      return _buildFrostedStyle();
    }
  }

  // 1. Vintage Typewriter Style (复古打字机)
  Widget _buildVintageStyle() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        margin: _isPressed
            ? const EdgeInsets.only(top: 2)
            : EdgeInsets.zero, // Mechanical press effect
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Outer Metal Ring
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8D6E63), // Lighter Bronze
              Color(0xFF3E2723), // Darker Bronze
            ],
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 1),
                    blurRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 4),
                    blurRadius: 5,
                  ),
                ],
        ),
        padding: const EdgeInsets.all(3), // Ring thickness
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1a100d), // Key Cap Dark
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: _isPressed
                  ? [const Color(0xFF000000), const Color(0xFF1a100d)]
                  : [const Color(0xFF2d241f), const Color(0xFF000000)],
              stops: const [0.0, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: GoogleFonts.notoSerifSc(
              // Consistent font
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF4ECD8), // Paper White
            ),
          ),
        ),
      ),
    );
  }

  // 2. Frosted Glass Style (Midnight / Amber / AfterRain)
  Widget _buildFrostedStyle() {
    final themeConfig = ThemeRegistry.get(widget.theme).lockScreen;

    final accentColor =
        themeConfig.accentColor ??
        (widget.theme == 'amber_lens'
            ? const Color(0xFFFF9800)
            : const Color(0xFF7986cb));

    final keyBg = themeConfig.keyBg ?? Colors.white.withValues(alpha: 0.05);

    final keyBorder =
        themeConfig.keyBorder ?? Colors.white.withValues(alpha: 0.15);

    final keyText = themeConfig.keyText ?? Colors.white.withValues(alpha: 0.9);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed ? accentColor.withValues(alpha: 0.2) : keyBg,
          border: Border.all(
            color: _isPressed ? accentColor.withValues(alpha: 0.5) : keyBorder,
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: GoogleFonts.notoSerifSc(
            fontSize: 30,
            fontWeight: FontWeight.w300,
            color: _isPressed ? accentColor : keyText,
          ),
        ),
      ),
    );
  }

  // 3. Pearl / Soft Neumorphic Style (Sea Flower)
  Widget _buildPearlStyle() {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFF0F5),
          gradient: _isPressed
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF48FB1).withValues(alpha: 0.1),
                    Colors.white,
                  ],
                )
              : null,
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFF48FB1).withValues(alpha: 0.4),
                    offset: const Offset(4, 4),
                    blurRadius: 10,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-4, -4),
                    blurRadius: 10,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: GoogleFonts.notoSerifSc(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF880E4F),
          ),
        ),
      ),
    );
  }
}
