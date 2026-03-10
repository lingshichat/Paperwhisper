import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import '../providers/diary_provider.dart';
import '../models/diary_entry.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../widgets/visual_effects.dart';
import 'package:google_fonts/google_fonts.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<DiaryEntry> _trashEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);
    final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
    final service = diaryProvider.service;
    
    try {
      final files = await service.trashService.listValidTrashFiles();
      // 按修改时间降序排列
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      List<DiaryEntry> loadedEntries = [];
      for (var file in files) {
         try {
           final content = await file.readAsString();
           final filename = path.basename(file.path);
           loadedEntries.add(DiaryEntry.fromFileContent(filename, content));
         } catch (e) {
           debugPrint('Error parsing trash file ${file.path}: $e');
         }
      }
      
      if (mounted) {
        setState(() {
          _trashEntries = loadedEntries;
          _isLoading = false;
        });
      }
    } catch (e) {
       debugPrint('Error loading trash: $e');
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFile(String filename) async {
    final service = Provider.of<DiaryProvider>(context, listen: false).service;
    
    try {
      await service.trashService.restoreFromTrash(filename, service.dataDir!);
      // 更新清单：标记为未删除
      service.manifestService.updateItem(filename, isDeleted: false);
      
      if (mounted) {
        SkeuomorphicToast.success(context, '已恢复: $filename');
        _loadTrash();
        // 重新加载主列表
        Provider.of<DiaryProvider>(context, listen: false).loadEntries();
      }
    } catch (e) {
      if (mounted) SkeuomorphicToast.error(context, '恢复失败: $e');
    }
  }

  Future<void> _deletePermanently(String filename) async {
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
            onPressed: () async {
              Navigator.pop(ctx);
              final service = Provider.of<DiaryProvider>(context, listen: false).service;
              
              try {
                await service.trashService.deletePermanently(filename);
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
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;

    // 统一从 AppTheme 获取回收站页面配色
    final tc = AppTheme.getTrashPageTheme(theme);
    final Color titleColor = tc['titleColor'];
    final Color iconColor = tc['iconColor'];

    return Stack(
      children: [
        // 1. 背景
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),
        
        // 2. 视觉特效
        if (isSeaFlower) Positioned.fill(child: const PetalRainWidget()),
        if (isMidnight) Positioned.fill(child: const StarrySkyWidget()),

        // 3. 内容
        Scaffold(
          backgroundColor: Colors.transparent, 
          appBar: AppBar(
            title: Text(
              '回收站',
              style: GoogleFonts.notoSerifSc(
                color: titleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: AppTheme.getSystemUiOverlayStyle(theme),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: iconColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _isLoading 
              ? Center(child: CircularProgressIndicator(color: iconColor))
              : _trashEntries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 64, color: iconColor.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text("回收站为空", style: GoogleFonts.notoSerifSc(color: titleColor.withOpacity(0.5))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _trashEntries.length,
                      itemBuilder: (context, index) {
                        return _buildTrashItem(context, _trashEntries[index], tc);
                      },
                  ),
        ),
      ],
    );
  }

  /// 构建回收站列表项，所有颜色从 themeConfig 中获取
  Widget _buildTrashItem(
    BuildContext context, 
    DiaryEntry entry, 
    Map<String, dynamic> tc,
  ) {
    final Color cardTitleColor = tc['cardTitleColor'];
    final Color cardDateColor = tc['cardDateColor'];
    final Color iconColor = tc['iconColor'];
    final Color restoreColor = tc['restoreColor'];
    final Color dangerColor = tc['dangerColor'];
    final BoxDecoration decoration = tc['cardDecoration'];

    return GestureDetector(
      onTap: () {
         _showPreview(context, entry);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Row(
          children: [
            Icon(Icons.menu_book_rounded, color: iconColor.withOpacity(0.7), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty ? '无题' : entry.title, 
                    style: GoogleFonts.notoSerifSc(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16,
                      color: cardTitleColor
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        entry.dateString, 
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 12, 
                          color: cardDateColor
                        )
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _getWeatherIcon(entry.weather),
                        size: 14,
                        color: cardDateColor,
                      )
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.restore, color: restoreColor),
              tooltip: '恢复',
              onPressed: () => _restoreFile(entry.filename),
            ),
            IconButton(
              icon: Icon(Icons.delete_forever_outlined, color: dangerColor),
              tooltip: '彻底删除',
              onPressed: () => _deletePermanently(entry.filename),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreview(BuildContext context, DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: entry.title.isEmpty ? '无题' : entry.title,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
             Row(
               children: [
                 Text(entry.dateString, style: TextStyle(color: Colors.grey, fontSize: 12)),
                 const SizedBox(width: 10),
                 Icon(_getWeatherIcon(entry.weather), size: 14, color: Colors.grey),
               ],
             ),
             const SizedBox(height: 10),
             Text(
               entry.content.length > 500 ? '${entry.content.substring(0, 500)}...' : entry.content,
               style: const TextStyle(fontSize: 15),
             ),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '关闭',
            isPrimary: false, 
            onPressed: () => Navigator.pop(ctx)
          ),
          SkeuomorphicDialogButton(
            label: '恢复日记',
            isPrimary: true, 
             onPressed: () {
               Navigator.pop(ctx);
               _restoreFile(entry.filename);
             }
          ),
        ],
      )
    );
  }

  IconData _getWeatherIcon(WeatherType w) {
    switch(w) {
      case WeatherType.sunny: return Icons.wb_sunny_outlined;
      case WeatherType.cloudy: return Icons.wb_cloudy_outlined;
      case WeatherType.rainy: return Icons.umbrella_outlined;
      case WeatherType.snowy: return Icons.ac_unit;
      case WeatherType.windy: return Icons.air;
    }
  }
}
