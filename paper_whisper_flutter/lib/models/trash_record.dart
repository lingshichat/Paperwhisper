enum TrashRecordType { diary, moment }

class TrashRecord {
  final TrashRecordType type;
  final String primaryFilename;
  final List<String> relatedFiles;
  final DateTime deletedAt;
  final String? title;
  final String? previewText;

  const TrashRecord({
    required this.type,
    required this.primaryFilename,
    required this.relatedFiles,
    required this.deletedAt,
    this.title,
    this.previewText,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'primaryFilename': primaryFilename,
      'relatedFiles': relatedFiles,
      'deletedAt': deletedAt.toIso8601String(),
      'title': title,
      'previewText': previewText,
    };
  }

  factory TrashRecord.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();

    return TrashRecord(
      type: TrashRecordType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => TrashRecordType.diary,
      ),
      primaryFilename: json['primaryFilename']?.toString() ?? '',
      relatedFiles: (json['relatedFiles'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      deletedAt: DateTime.tryParse(json['deletedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: json['title']?.toString(),
      previewText: json['previewText']?.toString(),
    );
  }
}
