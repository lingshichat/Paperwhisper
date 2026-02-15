import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/diary_entry.dart';
import '../models/moment.dart';
import 'diary_service.dart';
import 'moment_service.dart';
import 'trash_service.dart';

class StatisticsData {
  final int totalDiaries;
  final int totalMoments;
  final int trashCount;
  final int continuousDays;
  final int totalWords;
  final Map<MoodType, int> moodDistribution;
  final Map<WeatherType, int> weatherDistribution;
  final Map<String, int> dailyCounts; // YYYY-MM-DD -> count
  final List<DateTime> allActiveDates;
  final int momentsWithImages;
  final int momentsWithAudio;

  StatisticsData({
    this.totalDiaries = 0,
    this.totalMoments = 0,
    this.trashCount = 0,
    this.continuousDays = 0,
    this.totalWords = 0,
    this.moodDistribution = const {},
    this.weatherDistribution = const {},
    this.dailyCounts = const {},
    this.allActiveDates = const [],
    this.momentsWithImages = 0,
    this.momentsWithAudio = 0,
  });
}

class StatisticsService {
  final DiaryService _diaryService = DiaryService();
  final MomentService _momentService = MomentService();

  Future<StatisticsData> calculateStatistics() async {
    try {
      // 获取所有数据
      final diaries = await _diaryService.getEntries();
      final moments = await _momentService.getMoments();
      final trashItems = await _diaryService.trashService.listValidTrashFiles();

      // 基础统计
      final totalDiaries = diaries.length;
      final totalMoments = moments.length;
      final trashCount = trashItems.length;

      // 计算总字数（日记内容 + 随心记内容）
      int totalWords = 0;
      for (var diary in diaries) {
        totalWords += diary.content.length;
        totalWords += diary.title.length;
      }
      for (var moment in moments) {
        totalWords += moment.content.length;
      }

      // 计算连续天数
      final allDates = _collectAllDates(diaries, moments);
      final continuousDays = _calculateContinuousDays(allDates);

      // 心情分布
      final moodDistribution = _calculateMoodDistribution(diaries);

      // 天气分布
      final weatherDistribution = _calculateWeatherDistribution(diaries);

      // 每日写作数量
      final dailyCounts = _calculateDailyCounts(diaries, moments);

      // 带图/带音频的随心记
      final momentsWithImages = moments.where((m) => m.images.isNotEmpty).length;
      final momentsWithAudio = moments.where((m) => m.audioPath != null).length;

      return StatisticsData(
        totalDiaries: totalDiaries,
        totalMoments: totalMoments,
        trashCount: trashCount,
        continuousDays: continuousDays,
        totalWords: totalWords,
        moodDistribution: moodDistribution,
        weatherDistribution: weatherDistribution,
        dailyCounts: dailyCounts,
        allActiveDates: allDates.toList(),
        momentsWithImages: momentsWithImages,
        momentsWithAudio: momentsWithAudio,
      );
    } catch (e) {
      debugPrint('Error calculating statistics: $e');
      return StatisticsData();
    }
  }

  Set<DateTime> _collectAllDates(List<DiaryEntry> diaries, List<Moment> moments) {
    final dates = <DateTime>{};
    
    // 从日记收集日期
    for (var diary in diaries) {
      final date = DateTime.parse(diary.dateString);
      dates.add(DateTime(date.year, date.month, date.day));
    }
    
    // 从随心记收集日期
    for (var moment in moments) {
      dates.add(DateTime(
        moment.createdAt.year,
        moment.createdAt.month,
        moment.createdAt.day,
      ));
    }
    
    return dates;
  }

  int _calculateContinuousDays(Set<DateTime> dates) {
    if (dates.isEmpty) return 0;
    
    final sortedDates = dates.toList()
      ..sort((a, b) => b.compareTo(a)); // 降序排列
    
    int continuousDays = 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // 检查今天或昨天是否有记录
    DateTime checkDate = todayDate;
    
    // 如果今天没有记录，从昨天开始算
    if (!dates.contains(checkDate)) {
      checkDate = todayDate.subtract(const Duration(days: 1));
    }
    
    // 向前数连续的天数
    while (dates.contains(checkDate)) {
      continuousDays++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return continuousDays;
  }

  Map<MoodType, int> _calculateMoodDistribution(List<DiaryEntry> diaries) {
    final distribution = <MoodType, int>{};
    
    for (var diary in diaries) {
      distribution[diary.mood] = (distribution[diary.mood] ?? 0) + 1;
    }
    
    return distribution;
  }

  Map<WeatherType, int> _calculateWeatherDistribution(List<DiaryEntry> diaries) {
    final distribution = <WeatherType, int>{};
    
    for (var diary in diaries) {
      distribution[diary.weather] = (distribution[diary.weather] ?? 0) + 1;
    }
    
    return distribution;
  }

  Map<String, int> _calculateDailyCounts(List<DiaryEntry> diaries, List<Moment> moments) {
    final counts = <String, int>{};
    
    // 统计日记
    for (var diary in diaries) {
      counts[diary.dateString] = (counts[diary.dateString] ?? 0) + 1;
    }
    
    // 统计随心记
    for (var moment in moments) {
      final dateStr = '${moment.createdAt.year}-${moment.createdAt.month.toString().padLeft(2, '0')}-${moment.createdAt.day.toString().padLeft(2, '0')}';
      counts[dateStr] = (counts[dateStr] ?? 0) + 1;
    }
    
    return counts;
  }

  // 获取最近30天的写作趋势数据
  List<int> getLast30DaysTrend(Map<String, int> dailyCounts) {
    final trend = <int>[];
    final today = DateTime.now();
    
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      trend.add(dailyCounts[dateStr] ?? 0);
    }
    
    return trend;
  }

  // 获取月度统计
  Map<String, int> getMonthlyStatistics(Map<String, int> dailyCounts) {
    final monthly = <String, int>{};
    
    dailyCounts.forEach((dateStr, count) {
      final parts = dateStr.split('-');
      final monthKey = '${parts[0]}-${parts[1]}';
      monthly[monthKey] = (monthly[monthKey] ?? 0) + count;
    });
    
    return monthly;
  }
}
