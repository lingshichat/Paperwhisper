import 'package:intl/intl.dart';

enum WeatherType { sunny, cloudy, rainy, snowy, windy }

enum MoodType { happy, calm, sad, excited, tired }

class DiaryEntry {
  final String filename; // e.g. "2023-10-27_uuid.txt"
  final String dateString; // e.g. "2023-10-27"
  String title;
  WeatherType weather;
  MoodType mood;
  String content;
  bool isMarkdown;
  DateTime? lastModified; // 新增：记录最后修改时间用于排序

  DiaryEntry({
    required this.filename,
    required this.dateString,
    this.title = '无题',
    this.weather = WeatherType.sunny,
    this.mood = MoodType.calm,
    this.content = '',
    this.isMarkdown = false,
    this.lastModified,
  });

  // 从文件内容解析
  factory DiaryEntry.fromFileContent(
    String filename,
    String rawContent, {
    DateTime? lastModified,
  }) {
    List<String> lines = rawContent.split('\n');
    String title = '无题';
    WeatherType weather = WeatherType.sunny;
    MoodType mood = MoodType.calm;
    bool isMarkdown = false;
    int contentStartIndex = 0;

    if (lines.isNotEmpty) {
      title = lines[0].trim();
      if (title.isEmpty) title = '无题';
      contentStartIndex = 1;
    }

    // 解析 META Line
    if (lines.length > 1 && lines[1].startsWith("META|")) {
      contentStartIndex =
          2; // 跳过 META 行和其后的空行(如果有的话，但在 Python 代码里 META 后紧接着是 \n\n，所以通常是 lines[2] 开始为空行，lines[3] 为正文)
      // Python: file_content = f"{title}\n{meta_line}\n\n{content}"
      // line 0: title
      // line 1: META...
      // line 2: (empty)
      // line 3: content start...

      // 但由于 split('\n')，我们要小心处理
      try {
        String metaLine = lines[1].trim();
        List<String> parts = metaLine.split('|');
        for (String p in parts) {
          if (p.startsWith('weather:')) {
            String val = p.split(':')[1].trim();
            weather = _parseWeather(val);
          } else if (p.startsWith('mood:')) {
            String val = p.split(':')[1].trim();
            mood = _parseMood(val);
          } else if (p.startsWith('markdown:')) {
            String val = p.split(':')[1].trim();
            isMarkdown = val.toLowerCase() == 'true';
          }
        }

        // 修正 contentStartIndex
        // split 之后的数组，如果原文件是 title\nMeta\n\nContent
        // lines[0] = title
        // lines[1] = Meta
        // lines[2] = ""
        // lines[3] = Content
        contentStartIndex = 3;
      } catch (e) {
        // print('Meta parse error: $e');
      }
    }

    String content = '';
    if (lines.length > contentStartIndex) {
      content = lines.sublist(contentStartIndex).join('\n');
    }

    // 从文件名提取日期
    String dateStr = filename.split('_')[0];
    // 简单验证日期格式
    try {
      DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (_) {
      dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    return DiaryEntry(
      filename: filename,
      dateString: dateStr,
      title: title,
      weather: weather,
      mood: mood,
      content: content,
      isMarkdown: isMarkdown,
      lastModified: lastModified,
    );
  }

  // 生成文件内容
  String toFileContent() {
    // Python: content = content.replace('\r\n', '\n')
    // Python: meta_line = f"META|weather:{weather}|mood:{mood}|markdown:{is_markdown}"
    // Python: file_content = f"{title}\n{meta_line}\n\n{content}"

    String wStr = _weatherToString(weather);
    String mStr = _moodToString(mood);
    String mdStr = isMarkdown ? 'true' : 'false';

    String metaLine = "META|weather:$wStr|mood:$mStr|markdown:$mdStr";
    // 确保 content 换行符归一化， though Dart strings are usually \n
    String normalizedContent = content.replaceAll('\r\n', '\n');

    return "$title\n$metaLine\n\n$normalizedContent";
  }

  static WeatherType _parseWeather(String s) {
    return WeatherType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => WeatherType.sunny,
    );
  }

  static MoodType _parseMood(String s) {
    return MoodType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => MoodType.calm,
    );
  }

  static String _weatherToString(WeatherType w) => w.name;
  static String _moodToString(MoodType m) => m.name;

  // JSON Serialization for Cache
  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'dateString': dateString,
      'title': title,
      'weather': _weatherToString(weather),
      'mood': _moodToString(mood),
      'content': content,
      'isMarkdown': isMarkdown,
      'lastModified': lastModified?.toIso8601String(),
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      filename: json['filename'] ?? '',
      dateString: json['dateString'] ?? '',
      title: json['title'] ?? '无题',
      weather: _parseWeather(json['weather'] ?? ''),
      mood: _parseMood(json['mood'] ?? ''),
      content: json['content'] ?? '',
      isMarkdown: json['isMarkdown'] ?? false,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'])
          : null,
    );
  }
}
