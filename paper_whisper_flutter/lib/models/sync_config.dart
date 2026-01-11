class SyncConfig {
  final String serverUrl;
  final String username;
  final String password; // 应当加密存储，但在简易版中我们先明文存 SP，生产环境建议用 flutter_secure_storage
  final bool autoSync;
  final bool enabled;

  static const String defaultServerUrl = 'https://dav.jianguoyun.com/dav/';

  SyncConfig({
    this.serverUrl = defaultServerUrl,
    this.username = '',
    this.password = '',
    this.autoSync = false,
    this.enabled = false,
  });

  SyncConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    bool? autoSync,
    bool? enabled,
  }) {
    return SyncConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      autoSync: autoSync ?? this.autoSync,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'username': username,
      'password': password,
      'autoSync': autoSync,
      'enabled': enabled,
    };
  }

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      serverUrl: json['serverUrl'] ?? defaultServerUrl,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      autoSync: json['autoSync'] ?? false,
      enabled: json['enabled'] ?? false,
    );
  }
}
