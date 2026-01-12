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

  Moment({
    required this.uuid,
    required this.content,
    required this.images,
    required this.createdAt,
    this.weather,
    this.mood,
    this.location,
  });

  factory Moment.create({
    required String content,
    List<String> images = const [],
    String? weather,
    String? mood,
    String? location,
  }) {
    return Moment(
      uuid: const Uuid().v4(),
      content: content,
      images: images,
      createdAt: DateTime.now(),
      weather: weather,
      mood: mood,
      location: location,
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
    );
  }
  
  String toJsonString() => json.encode(toJson());
  
  factory Moment.fromJsonString(String jsonString) => Moment.fromJson(json.decode(jsonString));
}
