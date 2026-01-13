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
  DateTime? _lastSyncTime;
  
  Timer? _autoSyncTimer;
  static const int _notificationId = 888;
  static const String _channelId = 'paper_whisper_sync';
  static const String _channelName = 'Sync Status';

  SyncConfig get config => _config;
  SyncStatus get status => _status;
  String get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConfigured => _config.enabled && _config.serverUrl.isNotEmpty;

  late Future<void> _initFuture;

  SyncProvider() {
    _initFuture = _loadConfig();
    _initNotifications();
  }

  void updateDiaryProvider(DiaryProvider dp) {
    _diaryProvider = dp;
  }
  
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
        
    // Darwin (iOS) settings can be added here
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _notificationsPlugin.initialize(initializationSettings);
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
    _config = newConfig;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_config', jsonEncode(_config.toJson()));
    notifyListeners();
    
    // 如果启用，尝试连接
    if (_config.enabled) {
      connect();
    }
  }

  Future<bool> connect({bool test = true}) async {
    final success = await _webDavService.connect(
      _config.serverUrl,
      _config.username,
      _config.password,
    );
    
    if (success && test) {
      return await _webDavService.testConnection();
    }
    return success;
  }
  
  /// 请求自动同步（防抖 30秒）
  /// 请求自动同步（防抖 30秒）
  /// [fromLifecycle]: 是否由生命周期(如切前台)触发。如果是，则受 5分钟 冷却限制。
  /// 请求自动同步（防抖 30秒）
  /// [fromLifecycle]: 是否由生命周期(如切前台)触发。如果是，则受 5分钟 冷却限制。
  Future<void> requestAutoSync({bool fromLifecycle = false}) async {
    // 等待初始化完成，避免冷启动时 _lastSyncTime 尚未加载导致冷却失效
    await _initFuture;

    if (!_config.enabled) return;
    
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
      sync(isAuto: true);
    });
  }

  /// 检查并请求通知权限（带拟物化弹窗）
  Future<void> checkNotificationPermission(BuildContext context) async {
     var status = await Permission.notification.status;
     if (!status.isGranted) {
       // Show Explanation Dialog
       if (context.mounted) {
         await showDialog(
           context: context,
           builder: (ctx) => SkeuomorphicDialog(
             title: '需要通知权限',
             headerIcon: Icons.notifications_active,
             content: const Text(
               '为了防止同步过程被系统中断，并让您直观地看到上传进度，我们需要申请通知栏权限。\n\n这能确保您的日记和瞬间安全地备份到云端。',
             ),
             actions: [
               SkeuomorphicDialogButton(
                 label: '暂不开启', 
                 isPrimary: false,
                 onPressed: () => Navigator.pop(ctx),
               ),
               SkeuomorphicDialogButton(
                 label: '去开启', 
                 onPressed: () {
                   Navigator.pop(ctx);
                   Permission.notification.request();
                 },
               ),
             ],
           ),
         );
       }
     }
  }

  /// 执行完整同步
  Future<void> sync({bool isAuto = false}) async {
    if (_status == SyncStatus.syncing) return;
    if (!_config.enabled) return;

    // 确保连接
    if (!_webDavService.isConnected) {
      bool connected = await connect(test: false);
      if (!connected) {
        _setStatus(SyncStatus.failed, error: '无法连接到服务器');
        return;
      }
    }

    _setStatus(SyncStatus.syncing);
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
      
      // 完成通知
      if (!isAuto) {
         _showCompletionNotification('同步成功');
         // 延迟关闭
         Future.delayed(const Duration(seconds: 2), () => _cancelNotification());
      }
      
    } catch (e) {
      debugPrint('Sync failed: $e');
      _setStatus(SyncStatus.failed, error: e.toString());
      if (!isAuto) _showCompletionNotification('同步失败: $e');
    }
  }
  
  // ==========================================
  // 并发处理辅助
  // ==========================================
  Future<void> _processBatch<T>(List<T> items, Future<void> Function(T) action) async {
    const int batchSize = 3;
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);
      await Future.wait(batch.map((item) => action(item)));
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
  // 随心记同步逻辑 (Moments)
  // ==========================================
  Future<void> _syncMoments(bool isAuto) async {
      await _momentService.init();
      final localDir = _momentService.dataDir;
      if (localDir == null) return;
      
      await _syncMomentJsonFiles(localDir, isAuto);
      
      final imagesDir = Directory(path.join(localDir.path, 'images'));
      if (await imagesDir.exists()) {
         await _syncMomentImages(imagesDir, isAuto);
      }
  }

  Future<void> _syncMomentJsonFiles(Directory localDir, bool isAuto) async {
      final prefs = await SharedPreferences.getInstance();
      List<String> lastKnownRemoteFiles = prefs.getStringList('last_known_moments_manifest') ?? [];

      if (!isAuto) _showNotification(null, null, body: "正在检查随心记...");

      List<webdav.File> currentRemoteFilesRaw = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.momentsBasePath
      );
      
      List<webdav.File> currentRemoteFilesList = currentRemoteFilesRaw
          .where((f) => f.name != null && f.name!.endsWith('.json'))
          .toList();
      Map<String, webdav.File> currentRemoteMap = {
        for (var f in currentRemoteFilesList) f.name!: f
      };
      
      List<FileSystemEntity> localFiles = localDir.listSync();
      Map<String, File> currentLocalMap = {};
      for (var f in localFiles) {
        if (f is File && path.extension(f.path) == '.json') {
          currentLocalMap[path.basename(f.path)] = f;
        }
      }

      // Cloud Delete -> Local Delete
      for (var filename in lastKnownRemoteFiles) {
        if (!currentRemoteMap.containsKey(filename) && currentLocalMap.containsKey(filename)) {
           try {
             await currentLocalMap[filename]!.delete();
             currentLocalMap.remove(filename);
           } catch(e) {
             debugPrint('Sync Moments: Error deleting local file $filename: $e');
           }
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
         await _processBatch(filesToDeleteRemote, (filename) async {
            await _webDavService.deleteFile(WebDavSyncService.momentsBasePath + filename);
         });
         for(var f in filesToDeleteRemote) currentRemoteMap.remove(f);
      }

      List<String> toDownload = [];
      List<String> toUpload = [];
      
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
        if (toDownload.contains(filename) || toUpload.contains(filename)) currentLocalMap.remove(filename);
      }

      for (var entry in currentLocalMap.entries) toUpload.add(entry.key);

      int processed = 0;
      int total = toDownload.length + toUpload.length;

      // Downloads
      await _processBatch(toDownload, (filename) async {
          await _webDavService.downloadFile(
            WebDavSyncService.momentsBasePath + filename, 
            path.join(localDir.path, filename)
          );
          processed++;
          if (!isAuto) _showNotification(processed, total, body: "随心记下载: $filename");
      });

      // Uploads
      await _processBatch(toUpload, (filename) async {
          File f = File(path.join(localDir.path, filename));
          if (await f.exists()) {
             await _webDavService.uploadFile(
               f.path, 
               WebDavSyncService.momentsBasePath + filename
             );
             processed++;
             if (!isAuto) _showNotification(processed, total, body: "随心记上传: $filename");
          }
      });

      // Update Snapshot (Local Calculation)
      Set<String> finalKeys = currentRemoteMap.keys.toSet();
      finalKeys.removeAll(filesToDeleteRemote);
      finalKeys.addAll(toUpload); // Add new/updated files

      await prefs.setStringList('last_known_moments_manifest', finalKeys.toList());
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
    await _notificationsPlugin.cancel(_notificationId);
  }

  void _setStatus(SyncStatus s, {String error = ''}) {
    _status = s;
    _lastError = error;
    notifyListeners();
  }
}

