import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/diary_entry.dart';
import '../models/trash_record.dart';
import '../providers/diary_provider.dart';
import '../providers/settings_provider.dart';
import '../services/moment_service.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final MomentService _momentService = MomentService();

  List<DiaryEntry> _trashEntries = <DiaryEntry>[];
  List<TrashRecord> _momentRecords = <TrashRecord>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);
    final diaryProvider = Provider.of<DiaryProvider>(context, listen: false);
    final diaryService = diaryProvider.service;

    try {
      await diaryService.init();
      await _momentService.init();

      final files = await diaryService.trashService.listValidTrashFiles();
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      final List<DiaryEntry> loadedEntries = <DiaryEntry>[];
      for (final file in files) {
        try {
          final content = await file.readAsString();
          final filename = path.basename(file.path);
          loadedEntries.add(DiaryEntry.fromFileContent(filename, content));
        } catch (e) {
          debugPrint('Error parsing trash file ${file.path}: $e');
        }
      }

      final momentRecords = await _momentService.trashService.listRecords(
        type: TrashRecordType.moment,
      );
      momentRecords.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));

      if (mounted) {
        setState(() {
          _trashEntries = loadedEntries;
          _momentRecords = momentRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trash: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreDiaryFile(String filename) async {
    final service = Provider.of<DiaryProvider>(context, listen: false).service;

    try {
      await service.trashService.restoreFromTrash(filename, service.dataDir!);
      service.manifestService.updateItem(filename, isDeleted: false);

      if (!mounted) return;
      SkeuomorphicToast.success(context, '已恢复: $filename');
      await _loadTrash();
      await Provider.of<DiaryProvider>(context, listen: false).loadEntries();
    } catch (e) {
      if (mounted) {
        SkeuomorphicToast.error(context, '恢复失败: $e');
      }
    }
  }

  Future<void> _restoreMomentRecord(TrashRecord record) async {
    try {
      await _momentService.init();
      await _momentService.trashService.restoreRecord(record, _momentService.dataDir!);
      _momentService.manifestService.updateItem(record.primaryFilename, isDeleted: false);

      if (!mounted) return;
      SkeuomorphicToast.success(context, '已恢复随心记');
      await _loadTrash();
    } catch (e) {
      if (mounted) {
        SkeuomorphicToast.error(context, '恢复失败: $e');
      }
    }
  }

  Future<void> _deleteDiaryPermanently(String filename) async {
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
            onPressed: () => Navigator.pop(ctx),
          ),
          SkeuomorphicDialogButton(
            label: '删除',
            isPrimary: true,
            onPressed: () async {
              Navigator.pop(ctx);
              final service =
                  Provider.of<DiaryProvider>(context, listen: false).service;

              try {
                await service.trashService.deletePermanently(filename);
                if (mounted) {
                  SkeuomorphicToast.success(context, '已彻底删除');
                  await _loadTrash();
                }
              } catch (e) {
                if (mounted) {
                  SkeuomorphicToast.error(context, '删除失败: $e');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMomentPermanently(TrashRecord record) async {
    showDialog(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: '彻底删除',
        headerIcon: Icons.delete_forever,
        content: const Text(
          '确定要彻底删除这条随心记吗？\n归档的图片和语音也会一起删除。',
          textAlign: TextAlign.center,
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '取消',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          SkeuomorphicDialogButton(
            label: '删除',
            isPrimary: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _momentService.trashService.deleteRecordPermanently(record);
                if (mounted) {
                  SkeuomorphicToast.success(context, '已彻底删除');
                  await _loadTrash();
                }
              } catch (e) {
                if (mounted) {
                  SkeuomorphicToast.error(context, '删除失败: $e');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;

    final tc = AppTheme.getTrashPageTheme(theme);
    final Color titleColor = tc['titleColor'];
    final Color iconColor = tc['iconColor'];

    return Stack(
      children: [
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),
        ...AppTheme.getBackgroundOverlays(theme),
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
              : (_trashEntries.isEmpty && _momentRecords.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 64,
                            color: iconColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '回收站为空',
                            style: GoogleFonts.notoSerifSc(
                              color: titleColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_trashEntries.isNotEmpty) ...[
                          _buildSectionHeader('日记', titleColor),
                          const SizedBox(height: 12),
                          ..._trashEntries.map(
                            (entry) => _buildDiaryTrashItem(context, entry, tc),
                          ),
                        ],
                        if (_momentRecords.isNotEmpty) ...[
                          if (_trashEntries.isNotEmpty) const SizedBox(height: 16),
                          _buildSectionHeader('随心记', titleColor),
                          const SizedBox(height: 12),
                          ..._momentRecords.map(
                            (record) => _buildMomentTrashItem(context, record, tc),
                          ),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.notoSerifSc(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDiaryTrashItem(
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
      onTap: () => _showDiaryPreview(context, entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Row(
          children: [
            Icon(
              Icons.menu_book_rounded,
              color: iconColor.withValues(alpha: 0.7),
              size: 28,
            ),
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
                      color: cardTitleColor,
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
                          color: cardDateColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _getWeatherIcon(entry.weather),
                        size: 14,
                        color: cardDateColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.restore, color: restoreColor),
              tooltip: '恢复',
              onPressed: () => _restoreDiaryFile(entry.filename),
            ),
            IconButton(
              icon: Icon(Icons.delete_forever_outlined, color: dangerColor),
              tooltip: '彻底删除',
              onPressed: () => _deleteDiaryPermanently(entry.filename),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomentTrashItem(
    BuildContext context,
    TrashRecord record,
    Map<String, dynamic> tc,
  ) {
    final Color cardTitleColor = tc['cardTitleColor'];
    final Color cardDateColor = tc['cardDateColor'];
    final Color iconColor = tc['iconColor'];
    final Color restoreColor = tc['restoreColor'];
    final Color dangerColor = tc['dangerColor'];
    final BoxDecoration decoration = tc['cardDecoration'];

    final previewText = (record.previewText ?? '').trim();
    final title = previewText.isEmpty
        ? '随心记'
        : (previewText.length > 28
              ? '${previewText.substring(0, 28)}...'
              : previewText);

    return GestureDetector(
      onTap: () => _showMomentPreview(context, record),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_motion_outlined,
              color: iconColor.withValues(alpha: 0.7),
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSerifSc(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: cardTitleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已归档 ${record.relatedFiles.length + 1} 个文件',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      color: cardDateColor,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.restore, color: restoreColor),
              tooltip: '恢复',
              onPressed: () => _restoreMomentRecord(record),
            ),
            IconButton(
              icon: Icon(Icons.delete_forever_outlined, color: dangerColor),
              tooltip: '彻底删除',
              onPressed: () => _deleteMomentPermanently(record),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiaryPreview(BuildContext context, DiaryEntry entry) {
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
                Text(
                  entry.dateString,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Icon(_getWeatherIcon(entry.weather), size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.content.length > 500
                  ? '${entry.content.substring(0, 500)}...'
                  : entry.content,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '关闭',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          SkeuomorphicDialogButton(
            label: '恢复日记',
            isPrimary: true,
            onPressed: () {
              Navigator.pop(ctx);
              _restoreDiaryFile(entry.filename);
            },
          ),
        ],
      ),
    );
  }

  void _showMomentPreview(BuildContext context, TrashRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: '随心记归档',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              record.previewText?.isNotEmpty == true
                  ? record.previewText!
                  : '这条随心记已移入回收站。',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              '关联文件：${record.relatedFiles.length + 1}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '关闭',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          SkeuomorphicDialogButton(
            label: '恢复随心记',
            isPrimary: true,
            onPressed: () {
              Navigator.pop(ctx);
              _restoreMomentRecord(record);
            },
          ),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(WeatherType weather) {
    switch (weather) {
      case WeatherType.sunny:
        return Icons.wb_sunny_outlined;
      case WeatherType.cloudy:
        return Icons.wb_cloudy_outlined;
      case WeatherType.rainy:
        return Icons.umbrella_outlined;
      case WeatherType.snowy:
        return Icons.ac_unit;
      case WeatherType.windy:
        return Icons.air;
    }
  }
}
