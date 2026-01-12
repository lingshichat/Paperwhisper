/// 更新信息模型
/// 从远程 version.json 解析的版本数据
class UpdateInfo {
  final String latestVersion;
  final int? buildNumber;
  final String? releaseDate;
  final bool isForceUpdate;
  final List<String> changelog;
  final Map<String, String> downloadUrl;
  final Map<String, String>? backupUrl; // 蓝奏云备用下载链接
  final String? minSupportedVersion;

  UpdateInfo({
    required this.latestVersion,
    this.buildNumber,
    this.releaseDate,
    this.isForceUpdate = false,
    required this.changelog,
    required this.downloadUrl,
    this.backupUrl,
    this.minSupportedVersion,
  });

  /// 从 JSON 创建 UpdateInfo 实例
  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latestVersion'] as String,
      buildNumber: json['latestBuildNumber'] as int?,
      releaseDate: json['releaseDate'] as String?,
      isForceUpdate: json['isForceUpdate'] as bool? ?? false,
      changelog: (json['changelog'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      downloadUrl: Map<String, String>.from(json['downloadUrl'] as Map),
      backupUrl: json['backupUrl'] != null
          ? Map<String, String>.from(json['backupUrl'] as Map)
          : null,
      minSupportedVersion: json['minSupportedVersion'] as String?,
    );
  }

  /// 根据平台获取主下载链接
  String? getDownloadUrl(String platform) {
    return downloadUrl[platform];
  }

  /// 根据平台获取备用下载链接
  String? getBackupUrl(String platform) {
    return backupUrl?[platform];
  }

  /// 检查是否有备用下载链接
  bool hasBackupUrl(String platform) {
    return backupUrl != null && backupUrl!.containsKey(platform);
  }
}
