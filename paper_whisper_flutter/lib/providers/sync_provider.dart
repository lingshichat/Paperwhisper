import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/sync_manifest.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sync_config.dart';
import '../services/webdav_sync_service.dart';
import '../services/diary_service.dart';
import '../services/moment_service.dart';
import '../services/payment_service.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import 'diary_provider.dart';

import '../services/s3_sync_service.dart';
import '../services/cloud_storage_service.dart';

enum SyncStatus { none, syncing, success, failed }

class SyncProvider with ChangeNotifier {
  final WebDavSyncService _webDavService = WebDavSyncService();
  final S3SyncService _s3Service = S3SyncService();
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
  
  // Total Progress & ETA State
  int _totalOps = 0;
  int _processedOps = 0;
  DateTime? _batchStartTime;
  String _etaMessage = '';
  
  Timer? _autoSyncTimer;
  static const int _notificationId = 888;
  static const String _channelId = 'paper_whisper_sync';
  static const String _channelName = 'Sync Status';

  // Statistics
  int _statDiaries = 0;
  int _statMoments = 0;
  int _statImages = 0;
  int _statAudio = 0;

  SyncConfig get config => _config;
  SyncStatus get status => _status;
  String get lastError => _lastError;
  String get progressMessage => _progressMessage; 
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // Is Configured Logic
  bool get isConfigured {
    if (!_config.enabled) return false;
    if (_config.syncType == SyncType.webdav) {
      return _config.serverUrl.isNotEmpty && _config.username.isNotEmpty;
    } else {
      return _config.s3EndPoint.isNotEmpty && _config.s3AccessKey.isNotEmpty && _config.s3SecretKey.isNotEmpty && _config.s3BucketName.isNotEmpty;
    }
  }
  
  double get currentFileProgress => _currentFileProgress;
  String get currentFileSpeed => _currentFileSpeed;
  
  /// Total Progress (0.0 - 1.0)
  /// Formula: (processed + currentFilePart) / total
  double get totalProgress {
    if (_totalOps == 0) return 0.0;
    // Cap currentFileProgress to 1.0 just in case
    double filePart = _currentFileProgress.clamp(0.0, 1.0);
    return (_processedOps + filePart) / _totalOps;
  }
  
  String get etaMessage => _etaMessage;

  late Future<void> _initFuture;
  
  // Service Switcher
  CloudStorageService get _storageService {
    return _config.syncType == SyncType.s3 ? _s3Service : _webDavService;
  }

  SyncProvider() {
    _initFuture = _loadConfig();
    _initNotifications();
  }

  void updateDiaryProvider(DiaryProvider dp) {
    _diaryProvider = dp;
  }
  
  // Helper to reset transfer stats
  void _resetTransferStats(int totalOperations) {
    _currentFileProgress = 0.0;
    _currentFileSpeed = '';
    _lastBytesCount = 0;
    _lastSpeedUpdate = null;
    
    _totalOps = totalOperations;
    _processedOps = 0;
    _batchStartTime = DateTime.now();
    _etaMessage = '计算中...';
    notifyListeners();
  }

  void _onTransferProgress(int count, int total) {
    // debugPrint('SyncProgress: $count / $total'); // Reduce log noise
    
    final now = DateTime.now();
    
    // Calculate Progress
    if (total > 0) {
      _currentFileProgress = count / total;
    } else {
      _currentFileProgress = 0.0;
    }
    
    // Initial speed display
    if (_currentFileSpeed.isEmpty) {
       _currentFileSpeed = "计算中..."; 
    }
    
    // Update Speed & ETA every 500ms
    if (_lastSpeedUpdate == null || now.difference(_lastSpeedUpdate!).inMilliseconds >= 500) {
       _updateSpeedAndETA(now, count);
       _lastSpeedUpdate = now;
       _lastBytesCount = count;
       notifyListeners();
    }
  }
  
  void _updateSpeedAndETA(DateTime now, int count) {
    // 1. Calculate Instant Speed
    if (_lastSpeedUpdate != null && count > _lastBytesCount) {
       final diffMs = now.difference(_lastSpeedUpdate!).inMilliseconds;
       if (diffMs > 0) {
         final bytesDiff = count - _lastBytesCount;
         final speedBytesPerSec = (bytesDiff / diffMs) * 1000;
         _currentFileSpeed = _formatSpeed(speedBytesPerSec);
       }
    }
    
    // 2. Calculate ETA based on Item Count
    // (Since we don't know total bytes size for downloads)
    if (_batchStartTime != null && _processedOps > 0 && _totalOps > _processedOps) {
       final elapsedMs = now.difference(_batchStartTime!).inMilliseconds;
       // Time per item = elapsed / processed
       final msPerItem = elapsedMs / _processedOps; // Simple average
       final remainingItems = _totalOps - _processedOps;
       
       // Deduct current item progress from remaining time?
       // Let's keep it simple: ETA based on full completed items is more stable.
       // Refined: time = avg * (remaining - currentPart)
       final estimatedRemainingMs = msPerItem * (remainingItems - _currentFileProgress);
       
       if (estimatedRemainingMs > 0) {
         final duration = Duration(milliseconds: estimatedRemainingMs.toInt());
         if (duration.inHours > 0) {
            _etaMessage = '剩余 ${duration.inHours} 小时 ${duration.inMinutes % 60} 分';
         } else if (duration.inMinutes > 0) {
            _etaMessage = '剩余 ${duration.inMinutes} 分 ${duration.inSeconds % 60} 秒';
         } else {
            _etaMessage = '剩余 ${duration.inSeconds} 秒';
         }
       }
    } else if (_processedOps == 0) {
       _etaMessage = '计算中...';
    } else {
       _etaMessage = '即将完成';
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
  
  // Helper to reset just the current file stats (for loop iteration)
  void _resetCurrentFileStats() {
    _currentFileProgress = 0.0;
    _currentFileSpeed = '';
    _lastBytesCount = 0;
    _lastSpeedUpdate = null;
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
    
    // Check for critical changes (Server URL or Username or Endpoint or Bucket)
    bool isChanged = false;
    if (_config.syncType != newConfig.syncType) {
        isChanged = true;
    } else {
        if (_config.syncType == SyncType.webdav) {
            if (_config.serverUrl != newConfig.serverUrl || _config.username != newConfig.username) isChanged = true;
        } else {
            if (_config.s3EndPoint != newConfig.s3EndPoint || _config.s3AccessKey != newConfig.s3AccessKey || _config.s3BucketName != newConfig.s3BucketName) isChanged = true;
        }
    }
    
    if (isChanged) {
       debugPrint("Sync Config changed. Resetting sync history to prevent data loss.");
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
    if (!PaymentService().canUseProFeatures) {
      _lastError = '需要赞助才能使用云同步'; // Changed from "WebDAV" to generic
      _status = SyncStatus.failed;
      notifyListeners();
      return false;
    }
    _updateProgress('正在连接服务器...');
    
    // Init Config based on type
    if (_config.syncType == SyncType.webdav) {
        _webDavService.initConfig(
          _config.serverUrl,
          _config.username,
          _config.password,
        );
    } else {
        _s3Service.initConfig(
          endPoint: _config.s3EndPoint,
          accessKey: _config.s3AccessKey,
          secretKey: _config.s3SecretKey,
          bucketName: _config.s3BucketName,
          region: _config.s3Region,
        );
    }
    
    final success = await _storageService.connect();
    
    if (success && test) {
      _updateProgress('正在验证连接...');
      return await _storageService.testConnection();
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
    if (!PaymentService().canUseProFeatures) {
      _setStatus(SyncStatus.failed, error: '需要赞助才能使用 WebDAV 同步');
      return;
    }
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
    if (!_storageService.isConnected) {
      _updateProgress('正在连接服务器...');
      bool connected = await connect(test: false);
      if (!connected) {
        _setStatus(SyncStatus.failed, error: '无法连接到服务器');
        if (context != null && context.mounted) {
             SkeuomorphicToast.error(context, "无法连接到云存储服务器");
        }
        // THROW so callers like BookFlipRefreshWidget know it failed
        throw Exception("无法连接到云存储服务器");
      }
    }

    _setStatus(SyncStatus.syncing);
    _updateProgress('准备开始同步...');
    if (!isAuto) _showNotification(0, 0, indeterminate: true);

    // Reset stats
    _statDiaries = 0;
    _statMoments = 0;
    _statImages = 0;
    _statAudio = 0;

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
      if (context != null && context.mounted) {
         String statMsg = "已同步: $_statDiaries篇日记, $_statMoments篇随心记\n$_statImages张图片, $_statAudio条语音";
         if (_statDiaries == 0 && _statMoments == 0 && _statImages == 0 && _statAudio == 0) {
            statMsg = "同步完成 (无变更)";
         }
         SkeuomorphicToast.success(context, statMsg);
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
      if (context != null && context.mounted) {
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
      final remoteManifestJsonStr = await _storageService.readRemoteFile(
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
      Set<String> ghostItems = {}; 
      Set<String> transientItems = {};
      
      for (var filename in mergedItems.keys) {
         final item = mergedItems[filename]!;
         final localFile = File(path.join(service.dataDir!.path, filename));
         final localExists = await localFile.exists();
         
         final localItem = localManifest.items[filename];
         final remoteItem = remoteManifest.items[filename];
         
         if (item.isDeleted) {
            if (localExists) {
               toDeleteLocal.add(filename);
            }
            if (remoteItem == null || !remoteItem.isDeleted) {
               toTrashRemote.add(filename);
            }
         } else {
            if (!localExists) {
               toDownload.add(filename);
            } else {
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
      _statDiaries = totalOps;
      
      // Init Global Progress State
      _resetTransferStats(totalOps);

      if (!isAuto && totalOps > 0) {
        _showNotification(processed, totalOps, body: "开始同步 $totalOps 个变更...");
      }

      await _processBatch(toDownload, (filename) async {
         try {
           await _storageService.downloadFile(
              WebDavSyncService.diaryBasePath + filename,
              path.join(service.dataDir!.path, filename)
           );
           service.manifestService.updateItem(filename, 
             timestamp: mergedItems[filename]!.versionTimestamp,
             isDeleted: false
           );
           processed++;
           _processedOps++; // Global Counter
           if (!isAuto) _showNotification(processed, totalOps, body: "下载: $filename");
         } catch (e) {
           final errStr = e.toString();
           if (errStr.contains("404") || errStr.contains("Not Found") || errStr.contains("NoSuchKey")) {
              debugPrint("Ghost file detected (404): $filename");
              ghostItems.add(filename);
           } else {
              debugPrint("Transient download error ($filename): $e");
              transientItems.add(filename);
           }
         }
      });
      
      await _processBatch(toUpload, (filename) async {
         final file = File(path.join(service.dataDir!.path, filename));
         if (await file.exists()) {
           try {
             await _storageService.uploadFile(
                file.path,
                WebDavSyncService.diaryBasePath + filename
             );
             processed++;
             _processedOps++; // Global Counter
             if (!isAuto) _showNotification(processed, totalOps, body: "上传: $filename");
           } catch (e) {
             debugPrint("Diary upload failed ($filename): $e");
           }
         }
      });
      
      await _processBatch(toDeleteLocal, (filename) async {
         final file = File(path.join(service.dataDir!.path, filename));
         if (await file.exists()) {
            await service.trashService.moveToTrash(file);
         }
         processed++;
         _processedOps++; // Global Counter
      });
      
      await _processBatch(toTrashRemote, (filename) async {
         final srcPath = WebDavSyncService.diaryBasePath + filename;
         final trashPath = WebDavSyncService.trashBasePath + filename;
         
         await _storageService.ensureDirectoryExists(WebDavSyncService.trashBasePath);
         
         try {
           await _storageService.moveFile(srcPath, trashPath);
         } catch (e) {
           debugPrint("Remote move failed (maybe file already gone): $e");
         }
         processed++;
         _processedOps++; // Global Counter
      });
      
      // [FIX] 只更新磁盘上确实存在的文件（或标记删除的文件）到本地 manifest
      // 之前的实现会把所有合并条目都写入本地 manifest，
      // 导致下载失败的文件也被记录为"已有"，manifest 与磁盘状态不一致
      for (var item in mergedItems.values) {
        if (ghostItems.contains(item.filename)) continue; 
        if (transientItems.contains(item.filename)) continue;
        if (!item.isDeleted) {
          final f = File(path.join(service.dataDir!.path, item.filename));
          if (!f.existsSync()) {
            debugPrint('[SYNC] 跳过 manifest 更新(文件不存在): ${item.filename}');
            continue;
          }
        }
        service.manifestService.updateItem(item.filename, 
           timestamp: item.versionTimestamp,
           isDeleted: item.isDeleted
        );
      }
      
      final newManifest = service.manifestService.manifest; 
      // RESTORE TRANSIENT ITEMS to Remote Manifest so they are not lost
      for (var name in transientItems) {
         final original = mergedItems[name];
         if (original != null) {
            newManifest.items[name] = original;
         }
      }
      
      // REMOVE GHOST ITEMS from Manifest (Fix persistent 404)
      for (var name in ghostItems) {
         service.manifestService.removeItem(name);
         newManifest.items.remove(name);
      }

      await _storageService.writeRemoteFile(
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
      await _storageService.ensureDirectoryExists(WebDavSyncService.trashBasePath);

      final remoteTrashList = await _storageService.listFiles(
        WebDavSyncService.trashBasePath
      );
      final remoteNames = remoteTrashList.map((f) => f.name).toSet();
      
      await _processBatch(trashFiles, (file) async {
         final name = path.basename(file.path);
         if (!remoteNames.contains(name)) {
            await _storageService.uploadFile(
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
      
      // 2. Fetch Valid Images Set (For Cleanup)
      final service = _momentService;
      Set<String> validImages = await service.getAllReferencedImages();

      // 3. Sync Images (with cleanup)
      if (service.imagesDir != null) {
         await _syncMomentImages(service.imagesDir!, isAuto, validImages);
      }
      
      // 4. Sync Audio
      if (service.audioDir != null) {
         await _syncMomentAudio(service.audioDir!, isAuto);
      }
  }

  Future<void> _syncMomentJsonFiles(bool isAuto) async {
       final service = _momentService; // Use MomentService instance
       await service.init();
       
       // 1. 获取本地 Manifest
       final localManifest = service.manifestService.manifest;
       
       // 2. 获取云端 Manifest
       if (!isAuto) _showNotification(null, null, body: "正在获取随心记索引...");
       final remoteManifestJsonStr = await _storageService.readRemoteFile(
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
       Set<String> ghostItems = {};
       Set<String> transientItems = {};
       
       for (var filename in mergedItems.keys) {
          final item = mergedItems[filename]!;
          final localFile = File(path.join(service.dataDir!.path, filename));
          final localExists = await localFile.exists();
          
          final localItem = localManifest.items[filename];
          final remoteItem = remoteManifest.items[filename];
          
          if (item.isDeleted) {
             if (localExists) {
                toDeleteLocal.add(filename);
             }
             if (remoteItem == null || !remoteItem.isDeleted) {
                toTrashRemote.add(filename);
             }
          } else {
             if (!localExists) {
                toDownload.add(filename);
             } else {
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
       _statMoments = totalOps;
       
       // Init Global Progress State for Moments
       _resetTransferStats(totalOps);
       
       if (!isAuto && totalOps > 0) {
         _showNotification(processed, totalOps, body: "同步随心记 ($totalOps)...");
       }
 
       // Downloads
       await _processBatch(toDownload, (filename) async {
          _resetCurrentFileStats(); // Reset for new file
          try {
            await _storageService.downloadFile(
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
            _processedOps++; // Global Counter
            if (!isAuto) _showNotification(processed, totalOps, body: "随心记下载: $filename");
          } catch (e) {
             final errStr = e.toString();
             if (errStr.contains("404") || errStr.contains("Not Found") || errStr.contains("NoSuchKey")) {
                debugPrint("Ghost moment file detected (404): $filename");
                ghostItems.add(filename);
             } else {
                debugPrint("Transient moment download error ($filename): $e");
                transientItems.add(filename);
             }
          }
       });
       
       // Uploads
       await _processBatch(toUpload, (filename) async {
          final file = File(path.join(service.dataDir!.path, filename));
          if (await file.exists()) {
            _resetCurrentFileStats(); // Reset for new file
            try {
              await _storageService.uploadFile(
                 file.path,
                 WebDavSyncService.momentsBasePath + filename,
                 onProgress: _onTransferProgress
              );
              processed++;
              _processedOps++; // Global Counter
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
          _processedOps++; // Global Counter
       });
       
       // Remote Deletes (Move to Trash)
       await _processBatch(toTrashRemote, (filename) async {
          final srcPath = WebDavSyncService.momentsBasePath + filename;
          final trashPath = WebDavSyncService.trashBasePath + "moments_" + filename;
          
          await _storageService.ensureDirectoryExists(WebDavSyncService.trashBasePath);
          
          try {
            await _storageService.moveFile(srcPath, trashPath);
          } catch (e) {
            debugPrint("Remote moment move failed: $e");
          }
          processed++;
          _processedOps++; // Global Counter
       });
       
       // 5. 更新 Local Manifest (Merge Result)
       // [FIX] 只更新磁盘上确实存在的文件到本地 manifest
       for (var item in mergedItems.values) {
         if (ghostItems.contains(item.filename)) continue;
         if (transientItems.contains(item.filename)) continue;
         if (!item.isDeleted) {
           final f = File(path.join(service.dataDir!.path, item.filename));
           if (!f.existsSync()) {
             debugPrint('[SYNC-M] 跳过 manifest 更新(文件不存在): ${item.filename}');
             continue;
           }
         }
         service.manifestService.updateItem(item.filename, 
            timestamp: item.versionTimestamp,
            isDeleted: item.isDeleted
         );
       }
       
       // 6. 更新 Remote Manifest
 


       final newManifest = service.manifestService.manifest;
       
       // RESTORE TRANSIENT ITEMS
       for (var name in transientItems) {
          final original = mergedItems[name];
          if (original != null) {
             newManifest.items[name] = original;
          }
       }
       
       // REMOVE GHOST ITEMS
       for (var name in ghostItems) {
          service.manifestService.removeItem(name);
          newManifest.items.remove(name);
       }

       await _storageService.writeRemoteFile(
          WebDavSyncService.rootPath + 'moments_manifest.json',
          jsonEncode(newManifest.toJson())
       );
  }

  Future<void> _syncMomentImages(Directory localImagesDir, bool isAuto, Set<String> validImageNames) async {
      if (!isAuto) _showNotification(null, null, body: "正在同步图片...");
      
      // 1. Get Remote List
      List<RemoteFile> remoteImagesRaw = await _storageService.listFiles(
        WebDavSyncService.momentsImagesPath
      );
      Set<String> remoteImageNames = remoteImagesRaw
         .map((f) => f.name)
         .toSet();

      // 2. Get Local List
      List<FileSystemEntity> localImages = localImagesDir.listSync();
      
      // 3. Collect Uploads
      List<FileSystemEntity> toUpload = [];
      List<FileSystemEntity> toDeleteLocal = []; 
      
      for (var file in localImages) {
         if (file is! File) continue;
         
         String name = path.basename(file.path);
         // Local Orphan Check
         if (!validImageNames.contains(name)) {
            toDeleteLocal.add(file);
            continue;
         }

         if (!remoteImageNames.contains(name)) {
            toUpload.add(file);
         }
      }
      
      // Safety Check: 如果自动同步时发现大量文件需要上传，可能是因为误判或新设备迁移
      // 为了防止流量偷跑，跳过本次自动同步
      if (isAuto && toUpload.length > 20) {
         debugPrint('AutoSync Safety: Skipping upload of ${toUpload.length} images to prevent high data usage.');
         return;
      }
      
      List<String> toDeleteRemote = [];
      List<String> toDownload = [];

      for (var remoteFile in remoteImagesRaw) {
         String name = remoteFile.name;
         
         // ORPHAN CHECK: If not in validImageNames, it's trash!
         if (!validImageNames.contains(name)) {
            toDeleteRemote.add(name);
            continue; // Skip download check
         }

         File localFile = File(path.join(localImagesDir.path, name));
         bool exists = localFile.existsSync();
         if (!exists) {
            toDownload.add(name);
         }
      }

      int total = toUpload.length + toDownload.length + toDeleteRemote.length + toDeleteLocal.length;
      _statImages = total;
      int processed = 0;
      
      // Cleanup Remote Orphans First
      if (toDeleteRemote.isNotEmpty) {
         debugPrint("Cleaning up ${toDeleteRemote.length} orphan images...");
         await _processBatch(toDeleteRemote, (name) async {
             try {
                await _storageService.deleteFile(WebDavSyncService.momentsImagesPath + name);
                processed++;
                if (!isAuto) _showNotification(processed, total, body: "清理云端无效图片: $name");
             } catch (e) {
                debugPrint("Failed to delete orphan image $name: $e");
             }
         });
      }
      
      // Cleanup Local Orphans
      if (toDeleteLocal.isNotEmpty) {
         debugPrint("Cleaning up ${toDeleteLocal.length} local orphan images...");
         for (var f in toDeleteLocal) {
            try {
              if (f.existsSync()) {
                f.deleteSync();
                processed++;
                if (!isAuto) _showNotification(processed, total, body: "清理本地无效图片: ${path.basename(f.path)}");
              }
            } catch (e) {
               debugPrint("Failed to delete local orphan ${f.path}: $e");
            }
         }
      }

      // Parallel Upload
      await _processBatch(toUpload, (f) async {
          String name = path.basename(f.path);
          try {
            await _storageService.uploadFile(
               f.path, 
               WebDavSyncService.momentsImagesPath + name
            );
            processed++;
            if (!isAuto) _showNotification(processed, total, body: "图片上传: $name");
          } catch (e) {
             debugPrint("Image upload failed ($name): $e");
          }
      });

      // Parallel Download
      await _processBatch(toDownload, (name) async {
          File localFile = File(path.join(localImagesDir.path, name));
           try {
             await _storageService.downloadFile(
                WebDavSyncService.momentsImagesPath + name, 
                localFile.path
             ).timeout(const Duration(seconds: 15));
             processed++;
             if (!isAuto) _showNotification(processed, total, body: "图片下载: $name");
           } catch (e) {
             debugPrint("Image download failed ($name): $e");
           }
      });
  }

  Future<void> _syncMomentAudio(Directory localAudioDir, bool isAuto) async {
      if (!isAuto) _showNotification(null, null, body: "正在同步语音...");
      
      // 1. Get Remote List
      List<RemoteFile> remoteAudioRaw = await _storageService.listFiles(
        WebDavSyncService.momentsAudioPath
      );
      Set<String> remoteAudioNames = remoteAudioRaw
         .map((f) => f.name)
         .toSet();

      // 2. Get Local List
      List<FileSystemEntity> localAudioFiles = localAudioDir.listSync();
      
      // 3. Collect Uploads
      List<File> toUpload = [];
      for (var f in localAudioFiles) {
         if (f is File) {
            String name = path.basename(f.path);
            if (!remoteAudioNames.contains(name)) {
               toUpload.add(f);
            }
         }
      }
      
      // Safety Check
      if (isAuto && toUpload.length > 20) {
         debugPrint('AutoSync Safety: Skipping upload of ${toUpload.length} audio files.');
         return;
      }
      
      // 4. Collect Downloads
      List<String> toDownload = [];
      for (var remoteFile in remoteAudioRaw) {
         String name = remoteFile.name;
         File localFile = File(path.join(localAudioDir.path, name));
         if (!localFile.existsSync()) {
            toDownload.add(name);
         }
      }

      int total = toUpload.length + toDownload.length;
      _statAudio = total;
      int processed = 0;

      // Parallel Upload
      await _processBatch(toUpload, (f) async {
          String name = path.basename(f.path);
          try {
            await _storageService.uploadFile(
               f.path, 
               WebDavSyncService.momentsAudioPath + name
            );
            processed++;
            if (!isAuto) _showNotification(processed, total, body: "语音上传: $name");
          } catch (e) {
             debugPrint("Audio upload failed ($name): $e");
          }
      });

      // Parallel Download
      await _processBatch(toDownload, (name) async {
          File localFile = File(path.join(localAudioDir.path, name));
           try {
             await _storageService.downloadFile(
                WebDavSyncService.momentsAudioPath + name, 
                localFile.path
             );
             processed++;
             if (!isAuto) _showNotification(processed, total, body: "语音下载: $name");
           } catch (e) {
             debugPrint("Audio download failed ($name): $e");
           }
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

