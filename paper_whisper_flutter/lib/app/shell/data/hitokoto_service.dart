import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HitokotoService {
  static const String _baseUrl = 'https://v1.hitokoto.cn';

  // 静态缓存，使预热结果可被多个实例复用
  static HitokotoLine? _cachedResult;
  static bool _isFetching = false;

  /// 获取一言，如果有缓存则直接返回缓存
  Future<HitokotoLine?> fetchHitokoto() async {
    // 如果有缓存，直接返回
    if (_cachedResult != null) {
      return _cachedResult;
    }

    // 如果正在请求中，等待完成
    if (_isFetching) {
      // 等待最多 3 秒
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_cachedResult != null) return _cachedResult;
        if (!_isFetching) break;
      }
      return _cachedResult;
    }

    _isFetching = true;
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        _cachedResult = HitokotoLine(
          hitokoto: data['hitokoto'] ?? '获取失败',
          from: data['from'] ?? '未知',
        );
        return _cachedResult;
      }
    } catch (e) {
      debugPrint('Hitokoto fetch error: $e');
    } finally {
      _isFetching = false;
    }
    return null;
  }
}

class HitokotoLine {
  final String hitokoto;
  final String from;

  HitokotoLine({required this.hitokoto, required this.from});
}
