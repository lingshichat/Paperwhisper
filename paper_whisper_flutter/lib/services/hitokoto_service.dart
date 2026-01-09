import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HitokotoService {
  static const String _baseUrl = 'https://v1.hitokoto.cn';

  Future<HitokotoLine?> fetchHitokoto() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return HitokotoLine(
          hitokoto: data['hitokoto'] ?? '获取失败',
          from: data['from'] ?? '未知',
        );
      }
    } catch (e) {
      debugPrint('Hitokoto fetch error: $e');
    }
    return null;
  }
}

class HitokotoLine {
  final String hitokoto;
  final String from;

  HitokotoLine({required this.hitokoto, required this.from});
}
