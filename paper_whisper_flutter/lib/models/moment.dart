import 'dart:convert';
import 'package:uuid/uuid.dart';

class Moment {
  final String uuid;
  final String content;
  final List<String> images; // List of relative paths to images
  final DateTime createdAt;
  final String? weather;
  final String? mood;
  final String? location;
  final String? audioPath; // 录音文件相对路径
  final String? audioTitle; // 录音标题
  final int? audioDuration; // 录音时长(秒)

  Moment({
    required this.uuid,
    required this.content,
    required this.images,
    required this.createdAt,
    this.weather,
    this.mood,
    this.location,
    this.audioPath,
    this.audioTitle,
    this.audioDuration,
  });

  factory Moment.create({
    required String content,
    List<String> images = const [],
    String? weather,
    String? mood,
    String? location,
    String? audioPath,
    String? audioTitle,
    int? audioDuration,
  }) {
    return Moment(
      uuid: const Uuid().v4(),
      content: content,
      images: images,
      createdAt: DateTime.now(),
      weather: weather,
      mood: mood,
      location: location,
      audioPath: audioPath,
      audioTitle: audioTitle,
      audioDuration: audioDuration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'content': content,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'weather': weather,
      'mood': mood,
      'location': location,
      'audioPath': audioPath,
      'audioTitle': audioTitle,
      'audioDuration': audioDuration,
    };
  }

  factory Moment.fromJson(Map<String, dynamic> json) {
    return Moment(
      uuid: json['uuid'] as String,
      content: json['content'] as String,
      images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      weather: json['weather'] as String?,
      mood: json['mood'] as String?,
      location: json['location'] as String?,
      audioPath: json['audioPath'] as String?,
      audioTitle: json['audioTitle'] as String?,
      audioDuration: json['audioDuration'] as int?,
    );
  }
  
  String toJsonString() => json.encode(toJson());
  
  factory Moment.fromJsonString(String jsonString) => Moment.fromJson(json.decode(jsonString));
}
