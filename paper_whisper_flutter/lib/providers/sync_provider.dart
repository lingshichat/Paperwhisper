import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/sync_manifest.dart';
import '../models/diary_entry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sync_config.dart';
import '../services/webdav_sync_service.dart';
import '../services/diary_service.dart';
import '../services/moment_service.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import 'diary_provider.dart';

enum SyncStatus { none, syncing, success, failed }

class SyncProvider with ChangeNotifier {
  final WebDavSyncService _webDavService = WebDavSyncService();
  final MomentService _momentService = MomentService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  DiaryProvider? _diaryProvider;
  
  SyncConfig _config = SyncConfig();
  SyncStatus _status = SyncStatus.none;
  String _lastError = '';
  String _progressMessage = ''; 
  DateTime? _lastSyncTime;
  
  // Progress & Speed State
  double _currentFileProgress = 0.0;
  String _currentFileSpeed = '';
  int _lastBytesCount = 0;
  DateTime? _lastSpeedUpdate;
  
  Timer? _autoSyncTimer;
  static const int _notificationId = 888;
  static const String _channelId = 'paper_whisper_sync';
  static const String _channelName = 'Sync Status';

  SyncConfig get config => _config;
  SyncStatus get status => _status;
  String get lastError => _lastError;
  String get progressMessage => _progressMessage; 
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConfigured => _config.enabled && _config.serverUrl.isNotEmpty;
  
  double get currentFileProgress => _currentFileProgress;
  String get currentFileSpeed => _currentFileSpeed;

  late Future<void> _initFuture;

  SyncProvider() {
    _initFuture = _loadConfig();
    _initNotifications();
  }

  void updateDiaryProvider(DiaryProvider dp) {
    _diaryProvider = dp;
  }
  
  // Helper to reset transfer stats
  void _resetTransferStats() {
    _currentFileProgress = 0.0;
    _currentFileSpeed = '';
    _lastBytesCount = 0;
    _lastSpeedUpdate = null;
    notifyListeners();
  }

  void _onTransferProgress(int count, int total) {
    debugPrint('SyncProgress: $count / $total'); // DEBUG log
    
    final now = DateTime.now();
    
    // Calculate Progress
    if (total > 0) {
      _currentFileProgress = count / total;
    } else {
      _currentFileProgress = 0.0;
    }
    
    // Initial speed display (avoid empty gap)
    if (_currentFileSpeed.isEmpty) {
       _currentFileSpeed = "Calculating..."; 
    }
    
    if (_lastSpeedUpdate == null) {
      _lastSpeedUpdate = now;
      _lastBytesCount = count;
      return;
    }
    
    final diff = now.difference(_lastSpeedUpdate!).inMilliseconds;
    // Update every 500ms
    if (diff >= 500) {
       if (count < _lastBytesCount) {
          _lastBytesCount = count; 
          return;
       }
       
       final bytesDiff = count - _lastBytesCount;
       if (diff > 0) {
         final speedBytesPerSec = (bytesDiff / diff) * 1000;
         _currentFileSpeed = _formatSpeed(speedBytesPerSec);
       }
       
       _lastSpeedUpdate = now;
       _lastBytesCount = count;
       notifyListeners(); 
    }
  }
  
  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return "${bytesPerSec.toStringAsFixed(0)} B/s";
    if (bytesPerSec < 1024 * 1024) return "${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s";
    return "${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s";
  }
  
  // Helper to update progress message and notify UI
  void _updateProgress(String message) {
    _progressMessage = message;
    notifyListeners();
  }

  Future<void> _setStatus(SyncStatus status, {String? error}) async {
    _status = status;
    if (error != null) _lastError = error;
    if (status == SyncStatus.success) _progressMessage = '同步完成';
    if (status == SyncStatus.failed) _progressMessage = '同步失败';
    notifyListeners();
  }
  
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
        
    // Darwin (iOS) settings can be added here
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    if (Platform.isAndroid || Platform.isIOS) {
       await _notificationsPlugin.initialize(initializationSettings);
    }
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('sync_config');
    if (jsonStr != null) {
      try {
        _config = SyncConfig.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint('Error loading sync config: $e');
      }
    }
    
    final timeStr = prefs.getString('last_sync_time');
    if (timeStr != null) {
      _lastSyncTime = DateTime.tryParse(timeStr);
    }

    if (_config.enabled) {
      // 尝试自动连接
      connect(test: false);
    }
    notifyListeners();
  }

  Future<void> saveConfig(SyncConfig newConfig) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check for critical changes (Server URL or Username)
    // If changed, we MUST reset the sync history (LastKnownManifests)
    // to prevent the "New Empty Server = All Deleted" logic from wiping local data.
    if (_config.serverUrl != newConfig.serverUrl || _config.username != newConfig.username) {
       debugPrint("Sync Config changed (Server/User). Resetting sync history to prevent data loss.");
       await prefs.remove('last_known_remote_manifest');
       await prefs.remove('last_known_moments_manifest');
       await prefs.remove('last_sync_time');
       _lastSyncTime = null;
    }

    _config = newConfig;
    await prefs.setString('sync_config', jsonEncode(_config.toJson()));
    notifyListeners();
    
    // 如果启用，尝试连接
    if (_config.enabled) {
      connect();
    }
  }

  Future<bool> connect({bool test = true}) async {
    _updateProgress('正在连接服务器...');
    final success = await _webDavService.connect(
      _config.serverUrl,
      _config.username,
      _config.password,
    );
    
    if (success && test) {
      _updateProgress('正在验证连接...');
      return await _webDavService.testConnection();
    }
    return success;
  }
  
  /// 请求自动同步（防抖 30秒）
  /// 请求自动同步（防抖 30秒）
  /// [fromLifecycle]: 是否由生命周期(如切前台)触发。如果是，则受 5分钟 冷却限制。
  /// 请求自动同步（防抖 30秒）
  /// [fromLifecycle]: 是否由生命周期(如切前台)触发。如果是，则受 5分钟 冷却限制。
  /// [force]: 是否强制立即同步（忽略防抖和冷却）。适用于用户手动触发或重要保存操作。
  Future<void> requestAutoSync({bool fromLifecycle = false, bool force = false, BuildContext? context}) async {
    // 等待初始化完成，避免冷启动时 _lastSyncTime 尚未加载导致冷却失效
    await _initFuture;

    if (!_config.enabled) return;

    // Force Sync: Skip checks, run immediately
    if (force) {
      debugPrint('Force Sync requested. Skipping debounce and cooldown.');
      if (_autoSyncTimer?.isActive ?? false) _autoSyncTimer!.cancel();
      // Pass context for feedback
      sync(isAuto: true, context: context).catchError((e) {
         debugPrint('Force Sync caught error: $e');
      });
      return;
    }
    
    // Cooldown verification for lifecycle events
    if (fromLifecycle && _lastSyncTime != null) {
       final diff = DateTime.now().difference(_lastSyncTime!);
       if (diff.inMinutes < 5) {
         debugPrint('AutoSync suppressed (Cooldown: ${5 - diff.inMinutes}m remaining)');
         return;
       }
    }
    
    debugPrint('AutoSync requested. Debouncing...');
    if (_autoSyncTimer?.isActive ?? false) _autoSyncTimer!.cancel();
    
    _autoSyncTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('AutoSync triggered!');
      // Context might be stale here if widget disposed, so usually we don't pass context 
      // from a delayed timer unless we are sure. 
      // Safe to pass null for pure auto sync.
      sync(isAuto: true).catchError((e) {
         debugPrint('AutoSync caught error: $e');
      });
    });
  }

  /// 检查并请求通知权限（强制）
  /// 返回 true 表示已获得权限或无需权限，false 表示用户未授权或取消
  Future<bool> checkNotificationPermission(BuildContext context) async {
     if (!Platform.isAndroid && !Platform.isIOS) return true;

     var status = await Permission.notification.status;
     if (status.isGranted) return true;

     // Show Explanation Dialog
     if (context.mounted) {
       final bool? result = await showDialog<bool>(
         context: context,
         barrierDismissible: true, // Allow click outside to cancel
         builder: (ctx) => SkeuomorphicDialog(
           title: '需要通知权限',
           headerIcon: Icons.notifications_active,
           content: const Text(
             '为了防止同步过程被系统中断，并让您直观地看到上传进度，我们需要申请通知栏权限。\n\n请授予通知权限以启用同步功能。',
           ),
           // Custom footer for single button
           footer: SizedBox(
             width: double.infinity,
             child: SkeuomorphicDialogButton(
                 label: '去授予通知权限', 
                 onPressed: () async {
                   Navigator.pop(ctx, true); // Close dialog first with flag
                 },
             ),
           ),
         ),
       );

       if (result == true) {
         // User clicked "Enable"
         final newStatus = await Permission.notification.request();
         if (newStatus.isGranted) {
           return true;
         } else {
           if (context.mounted) {
             SkeuomorphicToast.info(context, '同步需要通知权限以保持后台运行');
           }
           return false;
         }
       }
     }
     
     return false; // Dialog dismissed or ignored
  }

  /// 执行完整同步
  Future<void> sync({bool isAuto = false, BuildContext? context}) async {
    // Manually triggered sync: Check Permission First
    if (!isAuto && context != null) {
       final hasPermission = await checkNotificationPermission(context);
       if (!hasPermission) {
         // User cancelled or denied permission. Abort silent.
         return; 
       }
    }

    if (_status == SyncStatus.syncing) {
      if (context != null && !isAuto) {
         SkeuomorphicToast.info(context, '正在同步中，请稍候...');
      }
      return;
    }
    if (!_config.enabled) return;

    // 确保连接
    if (!_webDavService.isConnected) {
      _updateProgress('正在连接服务器...');
      bool connected = await connect(test: false);
      if (!connected) {
        _setStatus(SyncStatus.failed, error: '无法连接到服务器');
        if (context != null) {
             SkeuomorphicToast.error(context, "无法连接到 WebDAV 服务器");
        }
        // THROW so callers like BookFlipRefreshWidget know it failed
        throw Exception("无法连接到 WebDAV 服务器");
      }
    }

    _setStatus(SyncStatus.syncing);
    _updateProgress('准备开始同步...');
    if (!isAuto) _showNotification(0, 0, indeterminate: true);

    try {
      if (_diaryProvider == null) {
        throw Exception('DiaryProvider not initialized');
      }

      // 1. 同步日记 (Txt)
      await _syncDiaries(isAuto);
      
      // 2. 同步随心记 (Moments JSON & Images)
      await _syncMoments(isAuto);

      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());

      _setStatus(SyncStatus.success);
      
      // 刷新 UI
      await _diaryProvider!.loadEntries();
      
      // Success Feedback
      if (context != null) {
         SkeuomorphicToast.success(context, "同步成功");
      }
      
      // 完成通知
      if (!isAuto) {
         _showCompletionNotification('同步成功');
         // 延迟关闭
         Future.delayed(const Duration(seconds: 2), () => _cancelNotification());
      }
      
    } catch (e) {
      debugPrint('Sync failed: $e');
      _setStatus(SyncStatus.failed, error: e.toString());
      
      // Error Feedback via Toast
      if (context != null) {
         String msg = "同步失败";
         final errStr = e.toString();
         if (errStr.contains("Forbidden") || errStr.contains("403")) {
            msg = "同步失败 (403): 权限被拒绝\n请检查WebDAV配置或剩余空间";
         } else if (errStr.contains("401") || errStr.contains("Unauthorized")) {
            msg = "同步失败 (401): 账号或密码错误";
         } else if (errStr.contains("Service Unavailable") || errStr.contains("503") || errStr.contains("Blocked")) {
             msg = "同步失败: 服务器繁忙/暂停服务\n操作过于频繁，请等待15分钟后再试";
         } else if (errStr.contains("SocketException") || errStr.contains("Network")) {
             msg = "同步失败: 网络连接异常";
         } else {
             // Extract short error message
             msg = "同步失败: ${errStr.length > 50 ? errStr.substring(0, 50) + '...' : errStr}"; 
         }
         SkeuomorphicToast.error(context, msg);
      }
      
      if (!isAuto) _showCompletionNotification('同步失败: $e');
      rethrow;
    }
  }
  
  // ==========================================
  // 并发处理辅助
  // ==========================================
  Future<void> _processBatch<T>(List<T> items, Future<void> Function(T) action) async {
    // 坚果云等 WebDAV 服务对并发请求有严格限制 (部分触发 403 Forbidden)
    // 降级为串行处理 (Batch Size = 1) 并增加间隔
    const int batchSize = 1; 
    
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      
      await Future.wait(batch.map((item) => action(item)));
      
      // 增加 1000ms 间隔，避免触发 API 速率限制 (坚果云极其敏感)
      if (i + batchSize < items.length) {
         await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }
  
  // ==========================================
  // 日记同步逻辑 (Manifest Based)
  // ==========================================
  Future<void> _syncDiaries(bool isAuto) async {
      final service = _diaryProvider!.service;
      await service.init();
      
      // 1. 获取本地 Manifest
      final localManifest = service.manifestService.manifest;
      
      // 2. 获取云端 Manifest
      if (!isAuto) _showNotification(null, null, body: "正在获取云端索引...");
      final remoteManifestJsonStr = await _webDavService.readRemoteFile(
        WebDavSyncService.rootPath + 'manifest.json'
      );
      
      SyncManifest remoteManifest;
      if (remoteManifestJsonStr == null) {
        remoteManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
      } else {
        try {
          remoteManifest = SyncManifest.fromJson(jsonDecode(remoteManifestJsonStr));
        } catch (e) {
          debugPrint("Error parsing remote manifest: $e");
          remoteManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
        }
      }
      
      // 3. 合并 Manifest (Conflict Resolution)
      final mergedItems = _mergeManifests(localManifest, remoteManifest);
      
      // 4. 执行差异同步
      int processed = 0;
      int totalOps = 0;
      
      List<String> toDownload = [];
      List<String> toUpload = [];
      List<String> toDeleteLocal = [];
      List<String> toTrashRemote = []; 
      
      for (var filename in mergedItems.keys) {
         final item = mergedItems[filename]!;
         final localFile = File(path.join(service.dataDir!.path, filename));
         final localExists = await localFile.exists();
         
         if (item.isDeleted) {
            if (localExists) {
               toDeleteLocal.add(filename);
            }
            final remoteItem = remoteManifest.items[filename];
            if (remoteItem == null || !remoteItem.isDeleted) {
               toTrashRemote.add(filename);
            }
         } else {
            if (!localExists) {
               toDownload.add(filename);
            } else {
               final localItem = localManifest.items[filename];
               final remoteItem = remoteManifest.items[filename];
               
               bool fromRemote = remoteItem != null && 
                   remoteItem.versionTimestamp == item.versionTimestamp &&
                   remoteItem.versionTimestamp != (localItem?.versionTimestamp ?? -1);
                   
               bool fromLocal = localItem != null && 
                   localItem.versionTimestamp == item.versionTimestamp &&
                   localItem.versionTimestamp != (remoteItem?.versionTimestamp ?? -1);

               if (fromRemote) toDownload.add(filename);
               else if (fromLocal) toUpload.add(filename);
            }
         }
      }
      
      totalOps = toDownload.length + toUpload.length + toDeleteLocal.length + toTrashRemote.length;
      
      if (!isAuto && totalOps > 0) {
        _showNotification(processed, totalOps, body: "开始同步 $totalOps 个变更...");
      }

      await _processBatch(toDownload, (filename) async {
         await _webDavService.downloadFile(
            WebDavSyncService.diaryBasePath + filename,
            path.join(service.dataDir!.path, filename)
         );
         service.manifestService.updateItem(filename, 
           timestamp: mergedItems[filename]!.versionTimestamp,
           isDeleted: false
         );
         processed++;
         if (!isAuto) _showNotification(processed, totalOps, body: "下载: $filename");
      });
      
      await _processBatch(toUpload, (filename) async {
         final file = File(path.join(service.dataDir!.path, filename));
         if (await file.exists()) {
           await _webDavService.uploadFile(
              file.path,
              WebDavSyncService.diaryBasePath + filename
           );
         }
         processed++;
         if (!isAuto) _showNotification(processed, totalOps, body: "上传: $filename");
      });
      
      await _processBatch(toDeleteLocal, (filename) async {
         final file = File(path.join(service.dataDir!.path, filename));
         if (await file.exists()) {
            await service.trashService.moveToTrash(file);
         }
         processed++;
      });
      
      await _processBatch(toTrashRemote, (filename) async {
         final srcPath = WebDavSyncService.diaryBasePath + filename;
         final trashPath = WebDavSyncService.trashBasePath + filename;
         
         await _webDavService.ensureDirectoryExists(WebDavSyncService.trashBasePath);
         
         try {
           await _webDavService.moveFile(srcPath, trashPath);
         } catch (e) {
           debugPrint("Remote move failed (maybe file already gone): $e");
         }
         processed++;
      });
      
      for (var item in mergedItems.values) {
        service.manifestService.updateItem(item.filename, 
           timestamp: item.versionTimestamp,
           isDeleted: item.isDeleted
        );
      }
      
      final newManifest = service.manifestService.manifest; 
      await _webDavService.writeRemoteFile(
         WebDavSyncService.rootPath + 'manifest.json',
         jsonEncode(newManifest.toJson())
      );
      
      // 6. Sync Trash (Safe Archive - Upload Only)
      await _syncTrash(service, isAuto);
  }
  
  Map<String, SyncItem> _mergeManifests(SyncManifest local, SyncManifest remote) {
    Set<String> allKeys = {};
    allKeys.addAll(local.items.keys);
    allKeys.addAll(remote.items.keys);
    
    Map<String, SyncItem> merged = {};
    
    for (var key in allKeys) {
      final localItem = local.items[key];
      final remoteItem = remote.items[key];
      
      if (localItem == null && remoteItem == null) continue;
      
      if (localItem == null) {
        merged[key] = remoteItem!;
      } else if (remoteItem == null) {
        merged[key] = localItem;
      } else {
        if (localItem.versionTimestamp >= remoteItem.versionTimestamp) {
           merged[key] = localItem;
        } else {
           merged[key] = remoteItem;
        }
      }
    }
    return merged;
  }
  
  Future<void> _syncTrash(DiaryService service, bool isAuto) async {
    final trashFiles = await service.trashService.listValidTrashFiles();
    if (trashFiles.isEmpty) return;
    
    if (!isAuto) _showNotification(null, null, body: "正在归档回收站...");
    
    try {
      // 检查云端 Trash 目录是否存在
      await _webDavService.ensureDirectoryExists(WebDavSyncService.trashBasePath);

      final remoteTrashList = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.trashBasePath
      );
      final remoteNames = remoteTrashList.map((f) => f.name).toSet();
      
      await _processBatch(trashFiles, (file) async {
         final name = path.basename(file.path);
         if (!remoteNames.contains(name)) {
            await _webDavService.uploadFile(
               file.path,
               WebDavSyncService.trashBasePath + name
            );
         }
      });
    } catch (e) {
      debugPrint("Trash sync failed (non-critical): $e");
    }
  }

  // ==========================================
  // 日记同步逻辑 (Txt) - LEGACY
  // ==========================================
  Future<void> _syncDiariesLegacy(bool isAuto) async {
      await _diaryProvider!.service.init();
      final localDir = _diaryProvider!.service.dataDir;
      if (localDir == null) throw Exception('本地日记目录不可用');

      final prefs = await SharedPreferences.getInstance();
      List<String> lastKnownRemoteFiles = prefs.getStringList('last_known_remote_manifest') ?? [];

      if (!isAuto) _showNotification(null, null, body: "正在检查日记列表...");
      
      List<webdav.File> currentRemoteFilesRaw = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.diaryBasePath
      );
      
      List<webdav.File> currentRemoteFilesList = currentRemoteFilesRaw
          .where((f) => f.name != null && f.name!.endsWith('.txt'))
          .toList();
      Map<String, webdav.File> currentRemoteMap = {
        for (var f in currentRemoteFilesList) f.name!: f
      };
      
      List<FileSystemEntity> localFiles = localDir.listSync();
      Map<String, File> currentLocalMap = {};
      for (var f in localFiles) {
        if (f is File && path.extension(f.path) == '.txt') {
          currentLocalMap[path.basename(f.path)] = f;
        }
      }

      // Cloud Delete -> Local Delete
      for (var filename in lastKnownRemoteFiles) {
        if (!currentRemoteMap.containsKey(filename) && currentLocalMap.containsKey(filename)) {
           await _diaryProvider!.service.deleteEntry(filename);
           currentLocalMap.remove(filename);
        }
      }

      // Local Delete -> Cloud Delete
      List<String> filesToDeleteRemote = [];
      for (var filename in lastKnownRemoteFiles) {
        if (currentRemoteMap.containsKey(filename) && !currentLocalMap.containsKey(filename)) {
          filesToDeleteRemote.add(filename);
        }
      }
      
      if (filesToDeleteRemote.isNotEmpty) {
        if (!isAuto) _showNotification(null, null, body: "正在同步删除...");
        await _processBatch(filesToDeleteRemote, (filename) async {
           await _webDavService.deleteFile(WebDavSyncService.diaryBasePath + filename);
        });
        for (var f in filesToDeleteRemote) currentRemoteMap.remove(f);
      }

      // Update / Download List
      List<String> toDownload = [];
      List<String> toUpload = []; // Existing update
      
      for (var filename in currentRemoteMap.keys) {
        final remote = currentRemoteMap[filename]!;
        final localFile = currentLocalMap[filename];

        if (localFile == null) {
          toDownload.add(filename);
        } else if (remote.mTime != null) {
            final remoteTime = remote.mTime!;
            final localTime = await localFile.lastModified();
            if (remoteTime.difference(localTime).inSeconds > 2) {
               toDownload.add(filename);
             } else if (localTime.difference(remoteTime).inSeconds > 2) {
               toUpload.add(filename);
             }
        }
        if (toDownload.contains(filename) || toUpload.contains(filename)) {
           currentLocalMap.remove(filename);
        }
      }

      // New Uploads
      for (var entry in currentLocalMap.entries) {
        toUpload.add(entry.key);
      }

      int totalOps = toDownload.length + toUpload.length;
      int processed = 0;
      
      Future<void> updateProgress(String action, String name) async {
         processed++;
         if (!isAuto) _showNotification(processed, totalOps, body: "$action: $name");
      }

      // Execute Downloads
      await _processBatch(toDownload, (filename) async {
          await _webDavService.downloadFile(
            WebDavSyncService.diaryBasePath + filename, 
            path.join(localDir.path, filename)
          );
          await updateProgress("下载", filename);
      });

      // Execute Uploads
      await _processBatch(toUpload, (filename) async {
         // Re-find file object
         File f = File(path.join(localDir.path, filename));
         if (await f.exists()) {
            await _webDavService.uploadFile(
              f.path, 
              WebDavSyncService.diaryBasePath + filename
            );
            await updateProgress("上传", filename);
         }
      });

      // Update Snapshot (Local Calculation)
      Set<String> finalKeys = currentRemoteMap.keys.toSet();
      finalKeys.removeAll(filesToDeleteRemote);
      finalKeys.addAll(toUpload); // Add new/updated files
      
      await prefs.setStringList('last_known_remote_manifest', finalKeys.toList());
  }

  // ==========================================
  // 随心记同步逻辑 (Manifest Based)
  // ==========================================
  Future<void> _syncMoments(bool isAuto) async {
      await _momentService.init();
      // [FIX] Reset service to ensure we load the latest manifest from disk
      // This is critical because UI operations use a different MomentService instance,
      // creating a stale cache in this long-lived SyncProvider instance.
      _momentService.reset(); 
      await _momentService.init();
      final localDir = _momentService.dataDir;
      if (localDir == null) return;
      
      // 1. Sync JSONs (Manifest Based)
      await _syncMomentJsonFiles(isAuto);
      
      // 2. Sync Images (Append/Check only)
      final imagesDir = Directory(path.join(localDir.path, 'images'));
      if (await imagesDir.exists()) {
         await _syncMomentImages(imagesDir, isAuto);
      }
  }

  Future<void> _syncMomentJsonFiles(bool isAuto) async {
       final service = _momentService; // Use MomentService instance
       await service.init();
       
       // 1. 获取本地 Manifest
       final localManifest = service.manifestService.manifest;
       
       // 2. 获取云端 Manifest
       if (!isAuto) _showNotification(null, null, body: "正在获取随心记索引...");
       final remoteManifestJsonStr = await _webDavService.readRemoteFile(
         WebDavSyncService.rootPath + 'moments_manifest.json'
       );
       
       SyncManifest remoteManifest;
       if (remoteManifestJsonStr == null) {
         remoteManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
       } else {
         try {
           remoteManifest = SyncManifest.fromJson(jsonDecode(remoteManifestJsonStr));
         } catch (e) {
           debugPrint("Error parsing remote moments manifest: $e");
           remoteManifest = SyncManifest(lastSyncTimestamp: 0, items: {});
         }
       }
       
       // 3. 合并 Manifest
       final mergedItems = _mergeManifests(localManifest, remoteManifest);
       
       // 4. 执行差异同步
       int processed = 0;
       int totalOps = 0;
       
       List<String> toDownload = [];
       List<String> toUpload = [];
       List<String> toDeleteLocal = [];
       List<String> toTrashRemote = []; 
       
       for (var filename in mergedItems.keys) {
          final item = mergedItems[filename]!;
          final localFile = File(path.join(service.dataDir!.path, filename));
          final localExists = await localFile.exists();
          
          if (item.isDeleted) {
             if (localExists) {
                toDeleteLocal.add(filename);
             }
             final remoteItem = remoteManifest.items[filename];
             if (remoteItem == null || !remoteItem.isDeleted) {
                toTrashRemote.add(filename);
             }
          } else {
             if (!localExists) {
                toDownload.add(filename);
             } else {
                final localItem = localManifest.items[filename];
                final remoteItem = remoteManifest.items[filename];
                
                bool fromRemote = remoteItem != null && 
                    remoteItem.versionTimestamp == item.versionTimestamp &&
                    remoteItem.versionTimestamp != (localItem?.versionTimestamp ?? -1);
                    
                bool fromLocal = localItem != null && 
                    localItem.versionTimestamp == item.versionTimestamp &&
                    localItem.versionTimestamp != (remoteItem?.versionTimestamp ?? -1);
 
                if (fromRemote) toDownload.add(filename);
                else if (fromLocal) toUpload.add(filename);
             }
          }
       }
       
       totalOps = toDownload.length + toUpload.length + toDeleteLocal.length + toTrashRemote.length;
       
       if (!isAuto && totalOps > 0) {
         _showNotification(processed, totalOps, body: "同步随心记 ($totalOps)...");
       }
 
       // Downloads
       await _processBatch(toDownload, (filename) async {
          _resetTransferStats(); // Reset for new file
          try {
            await _webDavService.downloadFile(
               WebDavSyncService.momentsBasePath + filename,
               path.join(service.dataDir!.path, filename),
               onProgress: _onTransferProgress
            );
            // Only update manifest if success
            service.manifestService.updateItem(filename, 
              timestamp: mergedItems[filename]!.versionTimestamp,
              isDeleted: false
            );
            processed++;
            if (!isAuto) _showNotification(processed, totalOps, body: "随心记下载: $filename");
          } catch (e) {
             debugPrint("Failed to download $filename: $e");
             // Generate error toast or status but don't stop entire sync?
             // specific 404 check could go here
          }
       });
       
       // Uploads
       await _processBatch(toUpload, (filename) async {
          final file = File(path.join(service.dataDir!.path, filename));
          if (await file.exists()) {
            _resetTransferStats(); // Reset for new file
            try {
              await _webDavService.uploadFile(
                 file.path,
                 WebDavSyncService.momentsBasePath + filename,
                 onProgress: _onTransferProgress
              );
              processed++;
              if (!isAuto) _showNotification(processed, totalOps, body: "随心记上传: $filename");
            } catch (e) {
               debugPrint("Failed to upload $filename: $e");
            }
          }
       });
       
       // Local Deletes
       await _processBatch(toDeleteLocal, (filename) async {
          final file = File(path.join(service.dataDir!.path, filename));
          if (await file.exists()) {
             // For moments, we can just delete or move to a local trash if we had one.
             await file.delete(); 
          }
          processed++;
       });
       
       // Remote Deletes (Move to Trash)
       await _processBatch(toTrashRemote, (filename) async {
          final srcPath = WebDavSyncService.momentsBasePath + filename;
          final trashPath = WebDavSyncService.trashBasePath + "moments_" + filename;
          
          await _webDavService.ensureDirectoryExists(WebDavSyncService.trashBasePath);
          
          try {
            await _webDavService.moveFile(srcPath, trashPath);
          } catch (e) {
            debugPrint("Remote moment move failed: $e");
          }
          processed++;
       });
       
       // 5. 更新 Local Manifest (Merge Result)
       for (var item in mergedItems.values) {
         service.manifestService.updateItem(item.filename, 
            timestamp: item.versionTimestamp,
            isDeleted: item.isDeleted
         );
       }
       
       // 6. 更新 Remote Manifest
       final newManifest = service.manifestService.manifest; 
       await _webDavService.writeRemoteFile(
          WebDavSyncService.rootPath + 'moments_manifest.json',
          jsonEncode(newManifest.toJson())
       );
  }

  Future<void> _syncMomentImages(Directory localImagesDir, bool isAuto) async {
      if (!isAuto) _showNotification(null, null, body: "正在同步图片...");
      
      // 1. Get Remote List
      List<webdav.File> remoteImagesRaw = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.momentsImagesPath
      );
      Set<String> remoteImageNames = remoteImagesRaw
         .where((f) => f.name != null)
         .map((f) => f.name!)
         .toSet();

      // 2. Get Local List
      List<FileSystemEntity> localImages = localImagesDir.listSync();
      
      // 3. Collect Uploads
      List<File> toUpload = [];
      for (var f in localImages) {
         if (f is File) {
            String name = path.basename(f.path);
            if (!remoteImageNames.contains(name)) {
               toUpload.add(f);
            }
         }
      }
      
      // Safety Check: 如果自动同步时发现大量文件需要上传，可能是因为误判或新设备迁移
      // 为了防止流量偷跑，跳过本次自动同步
      if (isAuto && toUpload.length > 20) {
         debugPrint('AutoSync Safety: Skipping upload of ${toUpload.length} images to prevent high data usage.');
         return;
      }
      
      // 4. Collect Downloads
      List<String> toDownload = [];
      for (var remoteFile in remoteImagesRaw) {
         String? name = remoteFile.name;
         if (name == null) continue;
         File localFile = File(path.join(localImagesDir.path, name));
         if (!localFile.existsSync()) {
            toDownload.add(name);
         }
      }

      int total = toUpload.length + toDownload.length;
      int processed = 0;

      // Parallel Upload
      await _processBatch(toUpload, (f) async {
          String name = path.basename(f.path);
          await _webDavService.uploadFile(
             f.path, 
             WebDavSyncService.momentsImagesPath + name
          );
          processed++;
          if (!isAuto) _showNotification(processed, total, body: "图片上传: $name");
      });

      // Parallel Download
      await _processBatch(toDownload, (name) async {
          File localFile = File(path.join(localImagesDir.path, name));
           await _webDavService.downloadFile(
              WebDavSyncService.momentsImagesPath + name, 
              localFile.path
           );
           processed++;
           if (!isAuto) _showNotification(processed, total, body: "图片下载: $name");
      });
  }

  // ==========================================
  // 通知管理
  // ==========================================
  Future<void> _showNotification(int? progress, int? max, {String? body, bool indeterminate = false}) async {
    // Update local UI state
    if (body != null) _updateProgress(body);

    if (!Platform.isAndroid && !Platform.isIOS) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            _channelId, 
            _channelName,
            channelDescription: '显示同步状态和进度',
            importance: Importance.low, // Low = no sound/vibrate, good for progress
            priority: Priority.low,
            onlyAlertOnce: true,
            showProgress: true,
            maxProgress: max ?? 100,
            progress: progress ?? 0,
            indeterminate: indeterminate || (progress == null && max == null),
            ongoing: true, // Prevent swipe away
            autoCancel: false,
        );
        
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await _notificationsPlugin.show(
        _notificationId, 
        'PaperWhisper 云同步', 
        body ?? '正在同步中...', 
        platformChannelSpecifics
    );
  }
  
  Future<void> _showCompletionNotification(String message) async {
      if (!Platform.isAndroid && !Platform.isIOS) return;

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            _channelId, 
            _channelName,
            channelDescription: '显示同步状态和进度',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            ongoing: false,
            autoCancel: true,
        );
      final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
      
      await _notificationsPlugin.show(
        _notificationId, 
        '同步完成', 
        message, 
        platformChannelSpecifics
      );
  }

  Future<void> _cancelNotification() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _notificationsPlugin.cancel(_notificationId);
  }


}

