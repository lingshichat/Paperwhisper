import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_service.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/features/statistics/data/statistics_service.dart';

import 'widgets/mood_badge_ring.dart';
import 'widgets/vintage_stamp.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with SingleTickerProviderStateMixin {
  // 共享服务实例（composition root 注入），统计侧不维护会写 Manifest
  // 的独立 DiaryService/MomentService。
  late final StatisticsService _statisticsService;
  StatisticsData _stats = StatisticsData();
  bool _isLoading = true;
  late PageController _pageController;
  int _currentPage = 0;

  // 心情分布筛选
  String _moodFilter = '本月'; // '本月', '本年', '全部'

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _statisticsService = StatisticsService(
      diaryService: context.read<DiaryService>(),
      momentService: context.read<MomentService>(),
    );
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadStatistics();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    final stats = await _statisticsService.calculateStatistics();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
    _animationController.forward();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final currentTheme = settings.currentTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: _isLoading
            ? _buildLoadingView(colorScheme)
            : FadeTransition(
                opacity: _fadeAnimation,
                child: _buildContent(colorScheme, currentTheme),
              ),
      ),
    );
  }

  Widget _buildLoadingView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '正在翻开纪念册...',
            style: GoogleFonts.notoSerifSc(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, String theme) {
    return Column(
      children: [
        _buildAppBar(colorScheme),
        // 删除了 _buildPageIndicator(theme)
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: [_buildFirstPage(theme), _buildSecondPage(theme)],
          ),
        ),
        _buildPageHint(theme),
      ],
    );
  }

  Widget _buildAppBar(ColorScheme colorScheme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            const Spacer(),
            Text(
              '数据洞察',
              style: GoogleFonts.notoSerifSc(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  // ==================== 第一页：相遇纪念 ====================
  Widget _buildFirstPage(String theme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildDaysTogether(theme),
            const SizedBox(height: 60),
            _buildQuote(theme),
            const SizedBox(height: 80),
            _buildDivider(theme),
            const SizedBox(height: 60),
            _buildCoreStats(theme),
            const SizedBox(height: 50),
            _buildMonthlyKeyword(theme),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysTogether(String theme) {
    final days = _stats.daysTogether > 0 ? _stats.daysTogether : 1;

    return Column(
      children: [
        Text(
          '我们已相遇',
          style: GoogleFonts.notoSerifSc(
            fontSize: 15,
            color: _getTextColor(theme).withValues(alpha: 0.5),
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$days',
              style: GoogleFonts.notoSerifSc(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: _getAccentColor(theme),
                height: 1,
                shadows: [
                  Shadow(
                    color: _getAccentColor(theme).withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '天',
                style: GoogleFonts.notoSerifSc(
                  fontSize: 22,
                  color: _getTextColor(theme).withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_stats.firstRecordDate != null)
          Text(
            '始于 ${_formatDate(_stats.firstRecordDate!)}',
            style: GoogleFonts.notoSerifSc(
              fontSize: 12,
              color: _getTextColor(theme).withValues(alpha: 0.35),
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildQuote(String theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        '"每一天的记录，\n都是时光最温柔的见证"',
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSerifSc(
          fontSize: 15,
          color: _getTextColor(theme).withValues(alpha: 0.5),
          height: 1.8,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildDivider(String theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _getAccentColor(theme).withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.favorite,
              size: 12,
              color: _getAccentColor(theme).withValues(alpha: 0.4),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getAccentColor(theme).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 简洁统计展示
  Widget _buildCoreStats(String theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(
          theme: theme,
          icon: Icons.edit_note,
          value: '${_stats.totalDiaries + _stats.totalMoments}',
          label: '记录',
        ),
        _buildDividerDot(theme),
        _buildStatItem(
          theme: theme,
          icon: Icons.text_fields,
          value: _formatNumber(_stats.totalWords),
          label: '字数',
        ),
        _buildDividerDot(theme),
        _buildStatItem(
          theme: theme,
          icon: Icons.photo_library,
          value: '${_stats.totalMomentImages}',
          label: '图片',
        ),
      ],
    );
  }

  Widget _buildDividerDot(String theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: _getAccentColor(theme).withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildStatItem({
    required String theme,
    required IconData icon,
    required String value,
    required String label,
    VoidCallback? onTap,
  }) {
    final accentColor = _getAccentColor(theme);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 20, color: accentColor.withValues(alpha: 0.7)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.notoSerifSc(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _getTextColor(theme),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.notoSerifSc(
              fontSize: 12,
              color: _getTextColor(theme).withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // 本月关键词模块 - 简洁版
  Widget _buildMonthlyKeyword(String theme) {
    final keyword = _getMonthlyKeyword();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 14,
            color: _getAccentColor(theme).withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            '本月关键词 · ${keyword['title']}',
            style: GoogleFonts.notoSerifSc(
              fontSize: 13,
              color: _getTextColor(theme).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getMonthlyKeyword() {
    // 根据数据生成本月关键词
    if (_stats.totalDiaries + _stats.totalMoments == 0) {
      return {'title': '静待花开 🌱', 'desc': '开始你的第一篇记录吧'};
    }

    // 检查连续写作天数
    if (_stats.continuousDays >= 30) {
      return {'title': '笔耕不辍 ✍️', 'desc': '坚持就是胜利，你做到了！'};
    }

    // 检查字数
    if (_stats.totalWords > 50000) {
      return {'title': '文思泉涌 📝', 'desc': '你的文字如泉涌般流淌'};
    }

    // 检查图片数量
    if (_stats.totalMomentImages > 50) {
      return {'title': '光影收藏家 📸', 'desc': '用镜头记录生活的美好'};
    }

    // 检查心情分布
    if (_stats.moodDistribution.isNotEmpty) {
      final maxMood = _stats.moodDistribution.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      if (maxMood.key.toString().contains('happy')) {
        return {'title': '快乐源泉 😊', 'desc': '最近心情不错呢，加油鸭！'};
      }
      if (maxMood.key.toString().contains('calm')) {
        return {'title': '心如止水 🍃', 'desc': '享受这份宁静与平和'};
      }
    }

    // 默认
    return {'title': '成长路上 🌟', 'desc': '每一篇记录都是成长的足迹'};
  }

  // ==================== 第二页：详细数据 ====================
  Widget _buildSecondPage(String theme) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 连续写作 - 简洁卡片
          _buildStreakCard(theme),
          const SizedBox(height: 24),

          // 心情分布（带筛选和提示）
          if (_stats.moodDistribution.isNotEmpty) ...[
            _buildMoodSection(theme),
            const SizedBox(height: 24),
          ],

          // 天气记录
          if (_stats.weatherDistribution.isNotEmpty) ...[
            _buildSectionTitle(theme, '天气记录', Icons.wb_sunny),
            const SizedBox(height: 12),
            _buildWeatherDistribution(theme),
            const SizedBox(height: 24),
          ],

          // 随心记详情
          _buildSectionTitle(theme, '随心记详情', Icons.photo_camera),
          const SizedBox(height: 12),
          _buildMomentsDetail(theme),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStreakCard(String theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAccentColor(theme).withValues(alpha: 0.15),
            _getAccentColor(theme).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAccentColor(theme).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getAccentColor(theme).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department,
              color: _getAccentColor(theme),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连续写作',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 13,
                    color: _getTextColor(theme).withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_stats.continuousDays}',
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getAccentColor(theme),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '天',
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 14,
                        color: _getTextColor(theme).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _getStreakMessage(_stats.continuousDays),
            style: GoogleFonts.notoSerifSc(
              fontSize: 12,
              color: _getTextColor(theme).withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // 心情分布模块（带筛选和提示）
  Widget _buildMoodSection(String theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.mood, size: 16, color: _getAccentColor(theme)),
            const SizedBox(width: 8),
            Text(
              '心情分布',
              style: GoogleFonts.notoSerifSc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _getTextColor(theme),
              ),
            ),
            const Spacer(),
            // 筛选按钮
            _buildFilterButton(theme, '本月'),
            const SizedBox(width: 8),
            _buildFilterButton(theme, '本年'),
            const SizedBox(width: 8),
            _buildFilterButton(theme, '全部'),
          ],
        ),
        const SizedBox(height: 8),
        // 状态提示语
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getAccentColor(theme).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getMoodMessage(theme),
            style: GoogleFonts.notoSerifSc(
              fontSize: 13,
              color: _getTextColor(theme).withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 心情分布图表
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getCardColor(theme).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getAccentColor(theme).withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: MoodBadgeList(
            moodData: _stats.moodDistribution.map(
              (key, value) => MapEntry(key.toString().split('.').last, value),
            ),
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String theme, String label) {
    final isSelected = _moodFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _moodFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? _getAccentColor(theme).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _getAccentColor(theme).withValues(alpha: 0.5)
                : _getTextColor(theme).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSerifSc(
            fontSize: 11,
            color: isSelected
                ? _getAccentColor(theme)
                : _getTextColor(theme).withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  String _getMoodMessage(String theme) {
    if (_stats.moodDistribution.isEmpty) {
      return '还没有记录心情哦~';
    }

    final maxMood = _stats.moodDistribution.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    final moodName = maxMood.key.toString().split('.').last;

    switch (moodName) {
      case 'happy':
        return '最近心情不错呢，加油鸭！😊';
      case 'calm':
        return '最近心情很平和，享受这份宁静~ 🍃';
      case 'sad':
        return '最近有点辛苦呢，抱抱你，会好起来的 💙';
      case 'excited':
        return '最近充满活力呀，保持这份热情！⚡';
      case 'tired':
        return '最近有点累呢，记得好好休息 💤';
      default:
        return '每一种心情都值得被记录 ✨';
    }
  }

  Widget _buildSectionTitle(String theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _getAccentColor(theme)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.notoSerifSc(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _getTextColor(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherDistribution(String theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getCardColor(theme).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAccentColor(theme).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: WeatherStampCollection(
        weatherData: _stats.weatherDistribution.map(
          (key, value) => MapEntry(key.toString().split('.').last, value),
        ),
        theme: theme,
      ),
    );
  }

  Widget _buildMomentsDetail(String theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCardColor(theme).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAccentColor(theme).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            theme: theme,
            icon: Icons.image,
            label: '带图随心记',
            value: '${_stats.momentsWithImages} 条',
          ),
          const SizedBox(height: 10),
          Divider(
            color: _getAccentColor(theme).withValues(alpha: 0.1),
            height: 1,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            theme: theme,
            icon: Icons.mic,
            label: '语音随心记',
            value: '${_stats.momentsWithAudio} 条',
          ),
          const SizedBox(height: 10),
          Divider(
            color: _getAccentColor(theme).withValues(alpha: 0.1),
            height: 1,
          ),
          const SizedBox(height: 10),
          _buildDetailRow(
            theme: theme,
            icon: Icons.text_snippet,
            label: '纯文字随心记',
            value:
                '${_stats.totalMoments - _stats.momentsWithImages - _stats.momentsWithAudio} 条',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required String theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: _getAccentColor(theme).withValues(alpha: 0.7),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.notoSerifSc(
              fontSize: 14,
              color: _getTextColor(theme).withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.notoSerifSc(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _getTextColor(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildPageHint(String theme) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _currentPage == 0
                ? Row(
                    key: const ValueKey('hint1'),
                    children: [
                      Text(
                        '向左滑动查看详细数据',
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 13,
                          color: _getTextColor(theme).withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: _getTextColor(theme).withValues(alpha: 0.4),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('hint2'),
                    children: [
                      Icon(
                        Icons.arrow_back_ios,
                        size: 12,
                        color: _getTextColor(theme).withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '向右滑动返回纪念页',
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 13,
                          color: _getTextColor(theme).withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _getStreakMessage(int days) {
    if (days == 0) return '开始记录吧';
    if (days < 3) return '不错的开始';
    if (days < 7) return '继续保持';
    if (days < 30) return '养成习惯';
    if (days < 100) return '太棒了';
    return '写作大师';
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    }
    return NumberFormat.decimalPattern().format(number);
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  Color _getAccentColor(String theme) {
    return AppTheme.getAccentColor(theme);
  }

  Color _getTextColor(String theme) {
    // 统计页面使用深色背景，需要特殊处理
    if (theme == AppTheme.themeDefault) {
      return const Color(0xFFF4ECD8); // Vintage主题在统计页面使用浅色文字
    }
    return AppTheme.getTextColor(theme);
  }

  Color _getCardColor(String theme) {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return const Color(0xFF37474F);
      case AppTheme.themeTwilight:
        return const Color(0xFF352044);
      case AppTheme.themeAfterRain:
        return Colors.white;
      case AppTheme.themeSeaFlower:
        return const Color(0xFFFCE4EC);
      case AppTheme.themeMidnight:
        return const Color(0xFF161b22);
      case AppTheme.themeAmberLens:
        return const Color(0xFF2C2C2C);
      default:
        // Vintage主题使用深色卡片背景，让浅色文字更清晰
        return const Color(0xFF3E2723);
    }
  }
}
