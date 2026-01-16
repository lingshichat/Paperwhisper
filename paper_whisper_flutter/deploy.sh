#!/bin/bash
set -e

# --- 🛠️ 配置区域 ---
BUCKET_NAME="paper-whisper-releases"
R2_REMOTE="cfr2"
DOMAIN="https://dl.paperwhisper.com"
# --------------------

# 1. 自动获取版本号
VERSION=$(grep '^version:' pubspec.yaml | cut -d ' ' -f 2 | cut -d '+' -f 1)
echo "📌 当前版本: v$VERSION"

# ==========================================
# 🤖 第一部分：Android 打包与上传
# ==========================================
echo "--------------------------------------"
echo "🚀 [Android] 开始构建 APK..."
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
APK_NAME="paper_whisper_flutter_android_$VERSION.apk"

echo "☁️ [Android] 正在上传 $APK_NAME..."
rclone copy "$APK_PATH" "$R2_REMOTE:$BUCKET_NAME/Android/" --rename "$APK_NAME" --progress
rclone copyto "$APK_PATH" "$R2_REMOTE:$BUCKET_NAME/Android/latest.apk" --progress


# ==========================================
# 🎉 总结
# ==========================================
echo "--------------------------------------"
echo "🎉 Android 发布任务完成！"
echo "⬇️ Android 最新版: $DOMAIN/Android/latest.apk"
echo "📦 历史存档: $DOMAIN/Android/$APK_NAME"