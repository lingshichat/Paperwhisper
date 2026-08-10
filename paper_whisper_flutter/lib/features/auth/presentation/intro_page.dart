import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/core/theme/widgets/visual_effects.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<IntroSlideData> _slides = [
    // 1. 欢迎页
    IntroSlideData(
      title: '纸语 PaperWhisper',
      subtitle: '纸本无言，因你而语\nSilent pages, awakened by you',
      useAppIcon: true, // Use app icon
      description: '',
    ),
    // 2. 设计理念
    IntroSlideData(
      title: '拟物之美',
      subtitle: 'Skeuomorphic Design',
      icon: Icons.brush,
      description: '光影流转，触手可及。每一个像素都经过精心雕琢，只为还原真实的物理质感。',
    ),
    // 3. 数据隐私
    IntroSlideData(
      title: '只属于你的秘密',
      subtitle: 'Local Storage',
      icon: Icons.lock,
      description: '数据本地存储，离线可用。你的故事，只属于你自己。',
    ),
    // 4. 丰富主题
    IntroSlideData(
      title: '随心而动',
      subtitle: 'Various Themes',
      icon: Icons.palette,
      description: '多种拟物主题，随心情切换。从午夜的静谧到花语的芬芳。',
    ),
    // 5. 开始
    IntroSlideData(
      title: '开启旅程',
      subtitle: 'Start Your Journey',
      icon: Icons.flight_takeoff,
      description: '准备好书写你的故事了吗？',
      isLastPage: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 获取当前主题
    // final theme = Theme.of(context); // Not used directly, using AppTheme logic implicitly

    return Scaffold(
      backgroundColor: const Color(0xFFF9F4E6), // 还原暖色背景
      body: Stack(
        children: [
          // 1. PageView 内容
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return IntroSlide(data: _slides[index]);
            },
          ),

          // 2. 底部指示器 (Page Indicators)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: _currentPage == index ? 24 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF8D6E63)
                        : const Color(0xFFD7CCC8),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      if (_currentPage == index)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      else
                        const BoxShadow(color: Colors.transparent),
                    ],
                  ),
                );
              }),
            ),
          ),

          // 3. 礼花特效 (只在最后一页显示)
          if (_currentPage == _slides.length - 1)
            const Positioned.fill(child: PetalRainWidget(burst: true)),
        ],
      ),
    );
  }
}

class IntroSlideData {
  final String title;
  final String subtitle;
  final IconData? icon; // Optional icon
  final bool useAppIcon; // Add flag for using app icon
  final String description;
  final bool isLastPage;

  IntroSlideData({
    required this.title,
    required this.subtitle,
    this.icon,
    this.useAppIcon = false, // Default false
    required this.description,
    this.isLastPage = false,
  });
}

class IntroSlide extends StatelessWidget {
  final IntroSlideData data;

  const IntroSlide({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 拟物化图标展示区
          Padding(
            padding: const EdgeInsets.only(bottom: 60),
            child: data.useAppIcon
                ? Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/icon.png',
                      ), // Ensure this asset exists
                    ),
                  )
                : Icon(
                    data.icon,
                    size: 100,
                    color: const Color(
                      0xFF5D4037,
                    ).withValues(alpha: 0.8), // Seamless blend
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
          ),

          // 标题
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: data.useAppIcon
                  ? 36
                  : 32, // Slightly larger for main title
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3E2723),
              shadows: [
                const Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 1,
                  color: Colors.white,
                ),
                Shadow(
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 副标题/英文
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              // English serif
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF8D6E63),
            ),
          ),

          const SizedBox(height: 32),

          // 描述文字
          Text(
            // Auto-format: Add newline after Chinese period for better readability
            data.description.replaceAll('。', '。\n').trim(),
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 16,
              height: 1.8, // Increase line height slightly
              color: const Color(0xFF5D4037),
            ),
          ),

          const SizedBox(height: 60),

          // 如果是最后一页，显示进入按钮
          if (data.isLastPage) _EnterButton(),
        ],
      ),
    );
  }
}

class _EnterButton extends StatefulWidget {
  @override
  State<_EnterButton> createState() => _EnterButtonState();
}

class _EnterButtonState extends State<_EnterButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        // 记录引导页已显示
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('intro_shown', true);

        if (!context.mounted) return;

        // 导航到主页，使用淡入淡出动画（800ms forward，reverse 保留默认 300ms）
        Navigator.of(context).pushReplacement(AppRoutes.introCompleted());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 200,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFEFE6D0), // Button face color
          borderRadius: BorderRadius.circular(30),
          boxShadow: _isPressed
              ? [
                  // Pressed state: Inner shadow
                  // Pressed state: No drop shadow, closer to surface
                  BoxShadow(
                    color: Colors.transparent, // Hide shadow
                    blurRadius: 0,
                    offset: Offset(0, 0),
                  ),
                  // Workaround: Standard doesn't support inset. Use Neumorphism trick or just simple state change.
                  // Let's do simple state change: Remove drop shadow, maybe darker color.
                ]
              : [
                  // Normal state: Drop shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(4, 4),
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    blurRadius: 10,
                    offset: Offset(-4, -4),
                  ),
                ],
          gradient: _isPressed
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(
                      0xFFEFE6D0,
                    ).withValues(red: 230, green: 220, blue: 200), // Darker
                    const Color(0xFFEFE6D0),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF9F4E6), Color(0xFFEFE6D0)],
                ),
        ),
        alignment: Alignment.center,
        transform: _isPressed
            ? Matrix4.translationValues(2, 2, 0)
            : Matrix4.identity(),
        child: Text(
          '进入应用',
          style: GoogleFonts.notoSerifSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF5D4037),
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 简单的礼花/散落动画组件
// ---------------------------------------------------------------------------
