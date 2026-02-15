import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/statistics_service.dart';
import '../widgets/slide_page_route.dart';
import 'diary_list_page.dart';
import 'moments_page.dart';
import 'gallery_page.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  final StatisticsService _statisticsService = StatisticsService();
  StatisticsData _stats = StatisticsData();
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: _isLoading
            ? _buildLoadingView(colorScheme)
            : FadeTransition(
                opacity: _fadeAnimation,
                child: _buildContent(colorScheme),
              ),
      ),
    );
  }

  Widget _buildLoadingView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '正在统计数据...',
            style: GoogleFonts.notoSerifSc(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    return CustomScrollView(
      slivers: [
        // 顶部导航栏
        SliverAppBar(
          floating: true,
          backgroundColor: colorScheme.surface.withOpacity(0.95),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '数据洞察',
            style: GoogleFonts.notoSerifSc(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 概览卡片
                _buildOverviewCards(colorScheme),
                const SizedBox(height: 30),
                
                // 连续写作天数
                _buildStreakCard(colorScheme),
                const SizedBox(height: 30),
                
                // 写作趋势（按字数）
                _buildTrendSection(colorScheme),
                const SizedBox(height: 30),
                
                // 文思泉涌
                _buildCreativeHighlights(colorScheme),
                const SizedBox(height: 30),
                
                // 心情分布
                _buildMoodDistribution(colorScheme),
                const SizedBox(height: 30),
                
                // 天气分布
                _buildWeatherDistribution(colorScheme),
                const SizedBox(height: 30),
                
                // 随心记详情
                _buildMomentsDetail(colorScheme),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCards(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '写作概览',
          style: GoogleFonts.notoSerifSc(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                colorScheme,
                icon: Icons.menu_book,
                label: '日记篇数',
                value: _stats.totalDiaries.toString(),
                color: colorScheme.primary,
                onTap: () => Navigator.push(
                  context,
                  SlidePageRoute(page: const DiaryListPage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                colorScheme,
                icon: Icons.photo_camera_outlined,
                label: '随心记数',
                value: _stats.totalMoments.toString(),
                color: colorScheme.secondary,
                onTap: () => Navigator.push(
                  context,
                  SlidePageRoute(page: const MomentsPage()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                colorScheme,
                icon: Icons.text_fields,
                label: '总字数',
                value: _formatNumber(_stats.totalWords),
                color: const Color(0xFF8E6C88),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                colorScheme,
                icon: Icons.photo_library,
                label: '图片数',
                value: _stats.totalMomentImages.toString(),
                color: const Color(0xFF6B8E9F),
                onTap: () => Navigator.push(
                  context,
                  SlidePageRoute(page: const GalleryPage()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.15),
            colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department,
              color: colorScheme.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连续写作天数',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_stats.continuousDays} 天',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStreakMessage(_stats.continuousDays),
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
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
    if (days == 0) return '开始你的第一篇日记吧！';
    if (days < 3) return '不错的开始，继续保持！';
    if (days < 7) return '养成习惯的初期，加油！';
    if (days < 30) return '你正在形成写作习惯！';
    if (days < 100) return '坚持就是胜利，太棒了！';
    return '你已经是个写作大师了！';
  }

  Widget _buildTrendSection(ColorScheme colorScheme) {
    final trendData = _statisticsService.getLast30DaysWordTrend(_stats.dailyWordCounts);
    final maxValue = trendData.isEmpty ? 0 : trendData.reduce((a, b) => a > b ? a : b);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '近30天写作趋势',
          style: GoogleFonts.notoSerifSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: trendData.every((d) => d == 0)
              ? Center(
                  child: Text(
                    '暂无数据',
                    style: GoogleFonts.notoSerifSc(
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxValue > 0 ? maxValue * 1.2 : 100,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value % 5 != 0) return const SizedBox.shrink();
                            final day = DateTime.now().subtract(
                              Duration(days: (29 - value).toInt()),
                            );
                            return Text(
                              '${day.day}',
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: trendData.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.toDouble(),
                            color: entry.value > 0
                                ? colorScheme.primary
                                : colorScheme.outline.withOpacity(0.2),
                            width: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  // 文思泉涌板块
  Widget _buildCreativeHighlights(ColorScheme colorScheme) {
    final hasLongestDiary = _stats.longestDiary != null && _stats.longestDiary!.wordCount > 0;
    final hasMaxMomentsDay = _stats.maxMomentsDay != null && _stats.maxMomentsDay!.momentCount > 0;
    
    if (!hasLongestDiary && !hasMaxMomentsDay) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '文思泉涌',
          style: GoogleFonts.notoSerifSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        if (hasLongestDiary)
          _buildHighlightCard(
            colorScheme,
            icon: Icons.auto_stories,
            title: '最长的一篇日记',
            subtitle: _stats.longestDiary!.title.isNotEmpty
                ? _stats.longestDiary!.title
                : '无标题',
            value: '${_formatNumber(_stats.longestDiary!.wordCount)} 字',
            date: _stats.longestDiary!.dateString,
            iconColor: const Color(0xFFFFA726),
          ),
        if (hasLongestDiary && hasMaxMomentsDay)
          const SizedBox(height: 12),
        if (hasMaxMomentsDay)
          _buildHighlightCard(
            colorScheme,
            icon: Icons.emoji_objects,
            title: '单日最多随心记',
            subtitle: '${_stats.maxMomentsDay!.momentCount} 条随心记',
            value: '灵感爆发',
            date: '${_stats.maxMomentsDay!.date.year}-${_stats.maxMomentsDay!.date.month.toString().padLeft(2, '0')}-${_stats.maxMomentsDay!.date.day.toString().padLeft(2, '0')}',
            iconColor: const Color(0xFF66BB6A),
          ),
      ],
    );
  }

  Widget _buildHighlightCard(
    ColorScheme colorScheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String date,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            iconColor.withOpacity(0.15),
            iconColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: GoogleFonts.notoSerifSc(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodDistribution(ColorScheme colorScheme) {
    if (_stats.moodDistribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final moodColors = {
      'happy': const Color(0xFFFFD93D),
      'calm': const Color(0xFF6BCB77),
      'sad': const Color(0xFF4D96FF),
      'excited': const Color(0xFFFF6B6B),
      'tired': const Color(0xFFB8B8B8),
    };

    final moodLabels = {
      'happy': '开心',
      'calm': '平静',
      'sad': '难过',
      'excited': '兴奋',
      'tired': '疲惫',
    };

    final total = _stats.moodDistribution.values.reduce((a, b) => a + b);
    final sortedMoods = _stats.moodDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '心情分布',
          style: GoogleFonts.notoSerifSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: sortedMoods.map((entry) {
                      final percentage = (entry.value / total * 100).toInt();
                      return PieChartSectionData(
                        color: moodColors[entry.key.name] ?? Colors.grey,
                        value: entry.value.toDouble(),
                        title: '$percentage%',
                        radius: 35,
                        titleStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: sortedMoods.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: moodColors[entry.key.name] ?? Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            moodLabels[entry.key.name] ?? entry.key.name,
                            style: GoogleFonts.notoSerifSc(
                              fontSize: 13,
                              color: colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            entry.value.toString(),
                            style: GoogleFonts.notoSerifSc(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherDistribution(ColorScheme colorScheme) {
    if (_stats.weatherDistribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final weatherIcons = {
      'sunny': Icons.wb_sunny,
      'cloudy': Icons.wb_cloudy,
      'rainy': Icons.water_drop,
      'snowy': Icons.ac_unit,
      'windy': Icons.air,
    };

    final weatherLabels = {
      'sunny': '晴天',
      'cloudy': '多云',
      'rainy': '雨天',
      'snowy': '雪天',
      'windy': ' windy',
    };

    final sortedWeather = _stats.weatherDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '天气记录',
          style: GoogleFonts.notoSerifSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: sortedWeather.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      weatherIcons[entry.key.name] ?? Icons.wb_sunny,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      weatherLabels[entry.key.name] ?? entry.key.name,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMomentsDetail(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '随心记详情',
          style: GoogleFonts.notoSerifSc(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDetailRow(
                colorScheme,
                icon: Icons.image,
                label: '带图随心记',
                value: '${_stats.momentsWithImages} 条',
              ),
              Divider(height: 24, color: colorScheme.outline.withOpacity(0.2)),
              _buildDetailRow(
                colorScheme,
                icon: Icons.photo_library,
                label: '图片总数',
                value: '${_stats.totalMomentImages} 张',
              ),
              Divider(height: 24, color: colorScheme.outline.withOpacity(0.2)),
              _buildDetailRow(
                colorScheme,
                icon: Icons.mic,
                label: '语音随心记',
                value: '${_stats.momentsWithAudio} 条',
              ),
              Divider(height: 24, color: colorScheme.outline.withOpacity(0.2)),
              _buildDetailRow(
                colorScheme,
                icon: Icons.text_snippet,
                label: '纯文字随心记',
                value: '${_stats.totalMoments - _stats.momentsWithImages - _stats.momentsWithAudio} 条',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.notoSerifSc(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.notoSerifSc(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    }
    return NumberFormat.decimalPattern().format(number);
  }
}
