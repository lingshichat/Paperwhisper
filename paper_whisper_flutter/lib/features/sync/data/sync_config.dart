enum SyncType { webdav, s3 }

class SyncConfig {
  // Common
  final bool autoSync;
  final bool enabled;
  final bool compressImages;
  final SyncType syncType;

  // WebDAV Config
  final String serverUrl;
  final String username;
  final String password;

  // S3 Config
  final String s3EndPoint;
  final String s3AccessKey;
  final String s3SecretKey;
  final String s3BucketName;
  final String? s3Region;

  static const String defaultServerUrl = 'https://dav.jianguoyun.com/dav/';

  bool get hasWebDavCredentials =>
      serverUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.trim().isNotEmpty;

  bool get hasS3Credentials =>
      s3EndPoint.trim().isNotEmpty &&
      s3AccessKey.trim().isNotEmpty &&
      s3SecretKey.trim().isNotEmpty &&
      s3BucketName.trim().isNotEmpty;

  bool get hasRequiredCredentials =>
      syncType == SyncType.webdav ? hasWebDavCredentials : hasS3Credentials;

  SyncConfig({
    this.autoSync = false,
    this.enabled = false,
    this.compressImages = true,
    this.syncType = SyncType.webdav,

    // WebDAV defaults
    this.serverUrl = defaultServerUrl,
    this.username = '',
    this.password = '',

    // S3 defaults
    this.s3EndPoint = '',
    this.s3AccessKey = '',
    this.s3SecretKey = '',
    this.s3BucketName = '',
    this.s3Region,
  });

  SyncConfig copyWith({
    bool? autoSync,
    bool? enabled,
    bool? compressImages,
    SyncType? syncType,
    String? serverUrl,
    String? username,
    String? password,
    String? s3EndPoint,
    String? s3AccessKey,
    String? s3SecretKey,
    String? s3BucketName,
    String? s3Region,
  }) {
    return SyncConfig(
      autoSync: autoSync ?? this.autoSync,
      enabled: enabled ?? this.enabled,
      compressImages: compressImages ?? this.compressImages,
      syncType: syncType ?? this.syncType,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      s3EndPoint: s3EndPoint ?? this.s3EndPoint,
      s3AccessKey: s3AccessKey ?? this.s3AccessKey,
      s3SecretKey: s3SecretKey ?? this.s3SecretKey,
      s3BucketName: s3BucketName ?? this.s3BucketName,
      s3Region: s3Region ?? this.s3Region,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSync': autoSync,
      'enabled': enabled,
      'compressImages': compressImages,
      'syncType': syncType.index,
      'serverUrl': serverUrl,
      'username': username,
      's3EndPoint': s3EndPoint,
      's3AccessKey': s3AccessKey,
      's3BucketName': s3BucketName,
      's3Region': s3Region,
    };
  }

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      autoSync: json['autoSync'] ?? false,
      enabled: json['enabled'] ?? false,
      compressImages: json['compressImages'] ?? true,
      syncType: SyncType.values[json['syncType'] ?? 0],
      serverUrl: json['serverUrl'] ?? defaultServerUrl,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      s3EndPoint: json['s3EndPoint'] ?? '',
      s3AccessKey: json['s3AccessKey'] ?? '',
      s3SecretKey: json['s3SecretKey'] ?? '',
      s3BucketName: json['s3BucketName'] ?? '',
      s3Region: json['s3Region'],
    );
  }
}
