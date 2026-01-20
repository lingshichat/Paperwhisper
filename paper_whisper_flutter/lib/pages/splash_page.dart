import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/diary_provider.dart';
import '../services/hitokoto_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import 'diary_list_page.dart';
import 'intro_page.dart';
import 'moments_page.dart';
import '../providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/privacy_agreement_dialog.dart';

/// 启动屏：等待数据预加载完成后再导航到主页/引导页
/// 同时预热字体、shader 和网络请求，避免首次交互卡顿
class SplashPage extends StatefulWidget {
  final bool showIntro;
  const SplashPage({super.key, required this.showIntro});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    // 0. 检查是否同意过用户协议
    final prefs = await SharedPreferences.getInstance();
    final bool agreed = prefs.getBool('privacy_agreed') ?? false;

    if (!agreed && mounted) {
      // 显示协议弹窗
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PrivacyAgreementDialog(
          onAgree: () {
            Navigator.of(context).pop(true);
          },
          onDisagree: () {
            Navigator.of(context).pop(false);
          },
        ),
      );

      if (result == true) {
        await prefs.setBool('privacy_agreed', true);
      } else {
        // 退出应用
        await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        return;
      }
    }

    if (!mounted) return;

    final diaryProvider = context.read<DiaryProvider>();
    
    // 1. 并行执行预热任务，最多等待 2.5 秒（加上过渡动画约 3 秒）
    await Future.any([
      // 正常完成所有预热
      Future.wait([
        _waitForDiaryLoading(diaryProvider),
        _preloadHitokoto(),
        Future.delayed(const Duration(milliseconds: 300)),
      ]),
      // 硬性超时 2.5 秒
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);
    
    if (!mounted) return;

    // 2. 导航到目标页面
    
    // Determine target page based on settings
    final settings = context.read<SettingsProvider>();
    Widget targetPage;
    
    if (widget.showIntro) {
      targetPage = const IntroPage();
    } else {
      // Check startup preference
      switch (settings.startupPage) {
        case 'moments':
          targetPage = const MomentsPage();
          break;
        case 'writer':
          targetPage = const DiaryListPage();
          break;
        case 'last':
        default:
          // TODO: Implement actual 'last' logic or default to writer
          // For now default to writer if last is not tracked
          targetPage = const DiaryListPage();
          break;
      }
    }
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );

    // 3. 启动时自动检测更新（仅非引导页时检查）
    if (!widget.showIntro) {
      _checkForUpdateAfterNavigation();
    }
  }

  Future<void> _waitForDiaryLoading(DiaryProvider provider) async {
    int waitCount = 0;
    const maxWait = 100; // 最多等待 5 秒
    while (provider.isLoading && waitCount < maxWait) {
      await Future.delayed(const Duration(milliseconds: 50));
      waitCount++;
    }
  }

  Future<void> _preloadHitokoto() async {
    try {
      // 预热一言请求，结果会被缓存在 HitokotoService 中
      await HitokotoService().fetchHitokoto();
    } catch (_) {
      // 忽略错误，不影响启动
    }
  }

  /// 导航完成后延迟检测更新
  Future<void> _checkForUpdateAfterNavigation() async {
    // 等待页面动画完成
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (!mounted) return;

    try {
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdate();
      
      if (updateInfo != null && mounted) {
        final currentVersion = await updateService.getCurrentVersion();
        
        // 获取当前 Navigator 的 context（从新页面）
        // 由于导航已完成，需要通过全局 key 或 overlay 来显示弹窗
        // 这里使用延迟确保 context 可用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // 使用 Navigator 的 overlay context
            final navigatorContext = Navigator.of(context).context;
            UpdateDialog.show(
              navigatorContext,
              updateInfo: updateInfo,
              currentVersion: currentVersion,
            );
          }
        });
      }
    } catch (e) {
      // 静默失败，不影响用户体验
      print('启动时检测更新失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4ECD8),
      body: Stack(
        children: [
          // 主要内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App 图标
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icon.png',
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.book,
                        size: 60,
                        color: Color(0xFF8D6E63),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // App 名称（同时预热 GoogleFonts）
                Text(
                  '纸语',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3E2723),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'PaperWhisper',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF8D6E63),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 加载指示器
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
                  ),
                ),
              ],
            ),
          ),

          // 隐藏的 BackdropFilter 预热层
          // 渲染一个不可见的 BackdropFilter 来预编译 shader
          Positioned(
            left: -100,
            top: -100,
            child: SizedBox(
              width: 10,
              height: 10,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
