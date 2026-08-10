class SyncItem {
  final String filename;
  final String versionHash; // Simple: md5 or modified time string
  final int versionTimestamp; // millisecondsSinceEpoch
  final bool isDeleted;

  SyncItem({
    required this.filename,
    required this.versionHash,
    required this.versionTimestamp,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() => {
    'f': filename,
    'v': versionHash,
    't': versionTimestamp,
    'd': isDeleted,
  };

  factory SyncItem.fromJson(Map<String, dynamic> json) {
    return SyncItem(
      filename: json['f'] ?? '',
      versionHash: json['v'] ?? '',
      versionTimestamp: json['t'] ?? 0,
      isDeleted: json['d'] ?? false,
    );
  }

  SyncItem copyWith({
    String? filename,
    String? versionHash,
    int? versionTimestamp,
    bool? isDeleted,
  }) {
    return SyncItem(
      filename: filename ?? this.filename,
      versionHash: versionHash ?? this.versionHash,
      versionTimestamp: versionTimestamp ?? this.versionTimestamp,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  bool sameAs(SyncItem other) {
    return filename == other.filename &&
        versionHash == other.versionHash &&
        versionTimestamp == other.versionTimestamp &&
        isDeleted == other.isDeleted;
  }
}

class SyncManifest {
  final int lastSyncTimestamp;
  final Map<String, SyncItem> items;

  SyncManifest({required this.lastSyncTimestamp, required this.items});

  Map<String, dynamic> toJson() => {
    'lastSync': lastSyncTimestamp,
    'items': items.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory SyncManifest.fromJson(Map<String, dynamic> json) {
    var itemsMap = <String, SyncItem>{};
    if (json['items'] != null) {
      (json['items'] as Map<String, dynamic>).forEach((key, value) {
        itemsMap[key] = SyncItem.fromJson(value);
      });
    }
    return SyncManifest(
      lastSyncTimestamp: json['lastSync'] ?? 0,
      items: itemsMap,
    );
  }

  SyncManifest clone() {
    return SyncManifest(
      lastSyncTimestamp: lastSyncTimestamp,
      items: items.map((key, value) => MapEntry(key, value.copyWith())),
    );
  }

  // Helpers
  void updateItem(SyncItem item) {
    items[item.filename] = item;
  }

  SyncItem? getItem(String filename) => items[filename];
}
