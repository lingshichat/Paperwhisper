import 'dart:io';
import 'dart:convert';

void main() {
  // 1. 定义路径
  // 假设脚本运行在 paper_whisper_flutter 目录下 (即项目根目录)
  final versionJsonPath = '../releases/version.json';
  final pubspecPath = 'pubspec.yaml';

  // 2. 读取 version.json
  final versionFile = File(versionJsonPath);
  if (!versionFile.existsSync()) {
    print('❌ Error: Could not find version.json at $versionJsonPath');
    exit(1);
  }

  final versionContent = versionFile.readAsStringSync();
  final versionMap = jsonDecode(versionContent);
  
  final String version = versionMap['latestVersion'];
  final int buildNumber = versionMap['latestBuildNumber'];
  
  final fullVersion = '$version+$buildNumber';

  print('📄 Found version in json: $fullVersion');

  // 3. 读取并更新 pubspec.yaml
  final pubspecFile = File(pubspecPath);
  if (!pubspecFile.existsSync()) {
    print('❌ Error: Could not find pubspec.yaml at $pubspecPath');
    exit(1);
  }

  var pubspecLines = pubspecFile.readAsLinesSync();
  bool updated = false;
  final newLines = <String>[];

  // 正则匹配 version: x.x.x+x
  final versionRegex = RegExp(r'^version:\s+.*');

  for (final line in pubspecLines) {
    if (versionRegex.hasMatch(line)) {
      newLines.add('version: $fullVersion');
      updated = true;
      print('✅ Updated pubspec.yaml to: version: $fullVersion');
    } else {
      newLines.add(line);
    }
  }

  if (!updated) {
    print('⚠️ Warning: Could not find "version:" line in pubspec.yaml to update.');
    exit(1);
  }

  // 4. 写回文件
  pubspecFile.writeAsStringSync(newLines.join('\n') + '\n');
  print('🚀 Version sync complete!');
}
