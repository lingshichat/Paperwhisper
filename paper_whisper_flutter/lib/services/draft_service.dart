import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';

class DraftService {
  static const String _draftPrefix = 'draft_';

  /// 保存草稿
  /// [id] 日记ID或文件名，新建日记可用 'new'
  Future<void> saveDraft(String id, DiaryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_draftPrefix$id';
    
    // 我们只保存关键内容字段，不保存完整的文件结构（如META行），转为JSON存
    // 这里为了方便，可以复用 DiaryEntry.toJson 如果有的话，或者手动组装
    // DiaryEntry 目前主要是 toFileContent，我们这里存个简单的 Map
    final data = {
      'title': entry.title,
      'content': entry.content,
      'weather': entry.weather.name, // Convert to String
      'mood': entry.mood.name,       // Convert to String
      'date': entry.dateString,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    await prefs.setString(key, jsonEncode(data));
    debugPrint('Draft saved for $id');
  }

  /// 获取草稿
  Future<DiaryEntry?> getDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_draftPrefix$id';
    final jsonStr = prefs.getString(key);
    
    if (jsonStr == null || jsonStr.isEmpty) return null;
    
    try {
      final data = jsonDecode(jsonStr);
      // Parse Enums
      final weatherStr = data['weather'] as String? ?? 'sunny';
      final moodStr = data['mood'] as String? ?? 'calm';
      
      final weather = WeatherType.values.firstWhere(
        (e) => e.name == weatherStr, 
        orElse: () => WeatherType.sunny
      );
      final mood = MoodType.values.firstWhere(
        (e) => e.name == moodStr, 
        orElse: () => MoodType.calm
      );

      // 构造临时 Entry
      return DiaryEntry(
        filename: id == 'new' ? '' : id, // 如果是new，filename为空
        dateString: data['date'] ?? '',
        title: data['title'] ?? '',
        weather: weather,
        mood: mood,
        content: data['content'] ?? '',
        isMarkdown: true, // 默认都按 MD 处理
      );
    } catch (e) {
      debugPrint('Error parsing draft: $e');
      return null;
    }
  }

  /// 清除草稿
  Future<void> clearDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_draftPrefix$id';
    await prefs.remove(key);
    debugPrint('Draft cleared for $id');
  }

  /// 检查是否有草稿
  Future<bool> hasDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_draftPrefix$id';
    return prefs.containsKey(key);
  }
}
