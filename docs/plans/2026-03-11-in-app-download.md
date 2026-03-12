# In-App Download Update Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the browser-first update flow with an in-app download and install flow that preserves file suffixes, shows progress, and still keeps browser fallback available.

**Architecture:** Keep `UpdateDialog` as the single UI entry point and keep download/install state local to the widget. Move download hardening and install outcome reporting into `UpdateService`, then let the dialog translate those outcomes into user-facing Chinese guidance.

**Tech Stack:** Flutter, Dart `dart:io`, `dio`, `open_filex`, `path_provider`, `url_launcher`

---

### Task 1: Harden `UpdateService` download and install contract

**Files:**
- Modify: `paper_whisper_flutter/lib/services/update_service.dart`
- Verify: `paper_whisper_flutter/android/app/src/main/AndroidManifest.xml`

**Step 1: Add a structured install result**

Add a lightweight result type in `update_service.dart` so the UI can distinguish success, permission denial, unsupported platform, and generic failure without parsing logs.

Suggested shape:

```dart
enum UpdateInstallStatus { launched, permissionDenied, unsupportedPlatform, failed }

class UpdateInstallResult {
  final UpdateInstallStatus status;
  final String? message;

  const UpdateInstallResult(this.status, {this.message});
}
```

**Step 2: Configure explicit Dio timeouts**

Create the `Dio` client with explicit timeout settings so the dialog can leave the `downloading` state predictably on weak networks.

Suggested baseline:

```dart
final dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(seconds: 30),
  ),
);
```

**Step 3: Keep temp-file cleanup symmetric**

- Delete stale temp files before a new download starts
- Delete partial files on cancel
- Delete partial files on failed download when the file exists
- Do not delete the downloaded file after an install failure; the user may need to retry install only

**Step 4: Return install outcomes instead of logging-only**

- Android: map `OpenFilex.open(filePath)` to `UpdateInstallResult`
- Treat permission-like/system-refusal outcomes as `permissionDenied`
- Windows: wrap `Process.start()` in `try/catch`; only call `exit(0)` after process launch succeeds
- Unsupported platforms: return `unsupportedPlatform`

**Step 5: Run static analysis**

Run:

```powershell
& 'E:\environment\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze 'lib/services/update_service.dart'
```

Expected: `No issues found!`

**Step 6: Human commit checkpoint**

Suggested commit message:

```text
fix(update): harden in-app download and install service flow
```

### Task 2: Teach `UpdateDialog` to handle download errors and install errors separately

**Files:**
- Modify: `paper_whisper_flutter/lib/widgets/update_dialog.dart`

**Step 1: Keep install failure out of the download error branch**

Do not send install failures into the current `error` state if that would discard the downloaded file path. Keep `_downloadedPath` intact and allow the user to retry install directly.

Recommended approach:

- Keep `_state == _DownloadState.downloaded`
- Add an install-specific message field or reuse `_errorMessage` only for inline rendering in the downloaded view

**Step 2: Wire `_installUpdate()` to the structured service result**

Handle each service result explicitly:

- `launched`: no extra UI changes needed
- `permissionDenied`: show a Chinese hint explaining how to enable install permission, keep “立即安装”
- `failed`: show a generic install failure message, keep retry install ability
- `unsupportedPlatform`: show a safe fallback message and keep browser fallback available

**Step 3: Preserve existing fallback actions**

Ensure these still work after the state changes:

- “备用下载” in idle/downloaded/error views where applicable
- “浏览器下载” in download-error view
- “暂不更新” only when `onLater != null`

**Step 4: Keep mounted checks and state resets tight**

- Reset progress counters and error text before each new download
- Cancel the token in `dispose()`
- Avoid `setState()` after unmount

**Step 5: Run static analysis**

Run:

```powershell
& 'E:\environment\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze 'lib/widgets/update_dialog.dart'
```

Expected: `No issues found!`

**Step 6: Human commit checkpoint**

Suggested commit message:

```text
fix(update): surface install guidance in update dialog
```

### Task 3: Verify platform wiring and smoke-test the full flow

**Files:**
- Verify: `paper_whisper_flutter/pubspec.yaml`
- Verify: `paper_whisper_flutter/android/app/src/main/AndroidManifest.xml`
- Verify: `paper_whisper_flutter/lib/services/update_service.dart`
- Verify: `paper_whisper_flutter/lib/widgets/update_dialog.dart`

**Step 1: Re-check dependency and permission declarations**

Confirm:

- `dio` remains declared in `pubspec.yaml`
- `REQUEST_INSTALL_PACKAGES` remains declared in `AndroidManifest.xml`

**Step 2: Run combined analysis**

Run:

```powershell
& 'E:\environment\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze 'lib/services/update_service.dart' 'lib/widgets/update_dialog.dart'
```

Expected: `No issues found!`

**Step 3: Manual Android smoke checklist**

- Open update dialog
- Tap “立即更新”
- Observe progress and percentage movement
- Cancel once and confirm the dialog returns to idle
- Download again to completion
- Tap “立即安装”
- If permission is denied, confirm the dialog shows guidance and still allows retry install

**Step 4: Manual Windows smoke checklist**

- Open update dialog
- Tap “立即更新”
- Observe progress and percentage movement
- Let download finish
- Tap “立即安装”
- Confirm the installer launches before the app exits
- If process launch fails, confirm the dialog stays open and shows an error

**Step 5: Human finish-work checkpoint**

Before any final commit, run the project’s normal finish checklist and record manual test outcomes in the task or journal.
