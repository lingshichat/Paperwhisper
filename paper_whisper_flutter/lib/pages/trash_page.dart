import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../providers/diary_provider.dart';
import '../services/diary_service.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<File> _trashFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);
    final service = Provider.of<DiaryProvider>(context, listen: false).service;
    final files = await service.trashService.listValidTrashFiles();
    // Sort by Date Modified (desc)
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    
    if (mounted) {
      setState(() {
        _trashFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreFile(File file) async {
    final service = Provider.of<DiaryProvider>(context, listen: false).service;
    final filename = path.basename(file.path);
    
    try {
      await service.trashService.restoreFromTrash(filename, service.dataDir!);
      // Update Manifest: Mark as NOT deleted
      service.manifestService.updateItem(filename, isDeleted: false);
      
      if (mounted) {
        SkeuomorphicToast.success(context, '已恢复: $filename');
        _loadTrash();
        // Reload main list
        Provider.of<DiaryProvider>(context, listen: false).loadEntries();
      }
    } catch (e) {
      if (mounted) SkeuomorphicToast.error(context, '恢复失败: $e');
    }
  }

  Future<void> _deletePermanently(File file) async {
    // Show confirmation
    showDialog(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: '彻底删除',
        headerIcon: Icons.delete_forever,
        content: const Text(
          '确定要彻底删除这篇日记吗？\n删除后将无法找回。',
          textAlign: TextAlign.center,
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '取消', 
            isPrimary: false, 
            onPressed: () => Navigator.pop(ctx)
          ),
          SkeuomorphicDialogButton(
            label: '删除', 
            isPrimary: true, 
             // Red color implies danger, usually primary is theme color. 
             // We can customize button color if needed but standard is fine.
            onPressed: () async {
              Navigator.pop(ctx);
              final service = Provider.of<DiaryProvider>(context, listen: false).service;
              final filename = path.basename(file.path);
              
              try {
                await service.trashService.deletePermanently(filename);
                // Note: We DO NOT update manifest to 'not deleted'. 
                // We keep it 'deleted' in manifest so sync knows it's gone.
                // In fact, if we want sync to propagate "Remote Trash Delete" we might need a status?
                // But current plan says "Cloud Trash is Safe Archive". It never deletes.
                // So locally deleting purely saves space.
                
                if (mounted) {
                  SkeuomorphicToast.success(context, '已彻底删除');
                  _loadTrash();
                }
              } catch (e) {
                if (mounted) SkeuomorphicToast.error(context, '删除失败: $e');
              }
            }
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine Theme Colors
    // Simple light theme background or reuse app background logic
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E8), // Paper-like background
      appBar: AppBar(
        title: const Text('回收站', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _trashFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 64, color: Colors.black26),
                      const SizedBox(height: 16),
                      const Text("回收站为空", style: TextStyle(color: Colors.black45)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _trashFiles.length,
                  itemBuilder: (context, index) {
                    final file = _trashFiles[index];
                    final filename = path.basename(file.path);
                    // Try to parse date from filename if possible?
                    // Filename format: {dateStr}_{uuid}.txt
                    String displayDate = filename;
                    if (filename.contains('_')) {
                       displayDate = filename.split('_')[0];
                    }
                    
                    return Dismissible(
                       key: Key(filename),
                       background: Container(color: Colors.red),
                       onDismissed: (_) {
                          // Swipe to ... restore? Or delete? 
                          // Better disable swipe to avoid accidents in trash.
                       },
                       confirmDismiss: (_) async => false, // Disable swipe
                       child: Container(
                         margin: const EdgeInsets.only(bottom: 12),
                         padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(12),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.black.withOpacity(0.05),
                               blurRadius: 10,
                               offset: const Offset(0, 4),
                             )
                           ],
                         ),
                         child: Row(
                           children: [
                             Icon(Icons.description, color: Colors.grey[400]),
                             const SizedBox(width: 16),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                   Text(filename, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                 ],
                               ),
                             ),
                             IconButton(
                               icon: const Icon(Icons.restore, color: Colors.green),
                               tooltip: '恢复',
                               onPressed: () => _restoreFile(file),
                             ),
                             IconButton(
                               icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                               tooltip: '彻底删除',
                               onPressed: () => _deletePermanently(file),
                             ),
                           ],
                         ),
                       ),
                    );
                  },
              ),
    );
  }
}
