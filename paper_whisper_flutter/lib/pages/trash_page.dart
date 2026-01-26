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
import 'package:google_fonts/google_fonts.dart'; // Ensure google fonts is imported if used

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<DiaryEntry> _trashEntries = []; // Change to store parsed entries
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);
    final diaryProvider = Provider.of<DiaryProvider>(context, listen: false); // Use provider directly
    final service = diaryProvider.service;
    
    try {
      final files = await service.trashService.listValidTrashFiles();
      // Sort by Date Modified (desc) first to align with files
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      List<DiaryEntry> loadedEntries = [];
      for (var file in files) {
         try {
           final content = await file.readAsString();
           final filename = path.basename(file.path);
           // Parse entry
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
      // Need to find the File object again or construct path? 
      // TrashService uses filename to restore.
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

  Future<void> _deletePermanently(String filename) async {
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
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;
    final bool isAmber = theme == AppTheme.themeAmberLens;

    final themeConfig = AppTheme.getSettingsTheme(theme);
    
    final Color titleColor = themeConfig.isNotEmpty
        ? themeConfig['titleColor']
        : (isSeaFlower
            ? const Color(0xFF880E4F)
            : (isMidnight ? const Color(0xFFe6edf3) : (isAmber ? const Color(0xFFE0E0E0) : const Color(0xFFF4ECD8))));
        
    final Color iconColor = themeConfig.isNotEmpty
        ? themeConfig['iconColor']
        : (isSeaFlower
            ? const Color(0xFFAD1457)
            : (isMidnight ? const Color(0xFFc9d1d9) : (isAmber ? const Color(0xFFFF9800) : const Color(0xFFD7CCC8))));

    return Stack(
      children: [
        // 1. 背景
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),
        
        // 2. Visual Effects
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
                        return _buildTrashItem(context, _trashEntries[index], isSeaFlower, isMidnight, isAmber, titleColor, iconColor);
                      },
                  ),
        ),
      ],
    );
  }

  Widget _buildTrashItem(
    BuildContext context, 
    DiaryEntry entry, 
    bool isSeaFlower, 
    bool isMidnight, 
    bool isAmber,
    Color titleColor, 
    Color iconColor
  ) {
    // 针对列表项内部的文字颜色，复古模式下需要深色（因为卡片是白色的）
    // 而传入的 titleColor 是用于 AppBar 的（浅色），所以这里需要反转一下复古模式的颜色
    Color cardTitleColor;
    Color cardDateColor;

    if (!isSeaFlower && !isMidnight && !isAmber) {
       // Vintage Mode
       cardTitleColor = const Color(0xFF2d241f); // Dark Brown
       cardDateColor = const Color(0xFF5D4037).withOpacity(0.6);
    } else {
       cardTitleColor = titleColor;
       cardDateColor = titleColor.withOpacity(0.6);
    }

    final theme = Provider.of<SettingsProvider>(context, listen: false).currentTheme;
    final themeConfig = AppTheme.getSettingsTheme(theme);

    BoxDecoration decoration;
    
    if (themeConfig.isNotEmpty) {
       decoration = themeConfig['groupDecoration'];
    } else if (isSeaFlower) {
      decoration = BoxDecoration(
         color: Colors.white.withOpacity(0.4),
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
         boxShadow: [
           BoxShadow(
             color: const Color(0xFFF48FB1).withOpacity(0.2),
             blurRadius: 8,
             offset: const Offset(0, 2)
           )
         ],
      );
    } else if (isMidnight) {
      decoration = BoxDecoration(
         color: const Color(0xFF161b22).withOpacity(0.8),
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: const Color(0xFF30363d), width: 1),
         boxShadow: const [
           BoxShadow(
             color: Colors.black,
             blurRadius: 8,
             offset: Offset(0, 2)
           )
         ],
      );
    } else if (isAmber) {
       decoration = BoxDecoration(
         color: const Color(0xFF2C2C2C).withOpacity(0.8),
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3), width: 1),
         boxShadow: const [
           BoxShadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))
         ]
       );
    } else {
      // Vintage
      decoration = BoxDecoration(
        color: const Color(0xFFF4F0E6), // Slightly warmer white
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
           BoxShadow(
            color: const Color(0xFF5D4037).withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          )
        ],
      );
    }

    // Remove Dismissible since we have explicit buttons and swipe is disabled
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
                      // Weather Icon small
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
              icon: Icon(Icons.restore, color: isSeaFlower ? const Color(0xFFE91E63) : (isMidnight ? const Color(0xFF69f0ae) : Colors.green)),
              tooltip: '恢复',
              onPressed: () => _restoreFile(entry.filename),
            ),
            IconButton(
              icon: Icon(Icons.delete_forever_outlined, color: isSeaFlower ? const Color(0xFFC2185B) : (isMidnight ? const Color(0xFFff5252) : Colors.redAccent)),
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
