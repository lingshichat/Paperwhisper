import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/moment.dart';
import '../services/moment_service.dart';
import '../providers/sync_provider.dart';
import '../widgets/skeuomorphic_dialog.dart';

import '../config/app_theme.dart';
import '../providers/settings_provider.dart';

class MomentEditorPage extends StatefulWidget {
  const MomentEditorPage({super.key});

  @override
  State<MomentEditorPage> createState() => _MomentEditorPageState();
}

class _MomentEditorPageState extends State<MomentEditorPage> {
  final TextEditingController _contentController = TextEditingController();
  final List<XFile> _images = [];

  // 共享 MomentService（composition root 注入），initState 一次性
  // context.read，跨 await 不再查询可能已 deactivated 的 context。
  late final MomentService _momentService;
  final ImagePicker _picker = ImagePicker();

  String? _selectedWeather;
  String? _selectedMood;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _momentService = context.read<MomentService>();
  }

  final List<String> _weathers = ['☀️', '☁️', '🌧️', '❄️', '🌪️', '🌫️'];
  final List<String> _moods = ['😊', '😂', '🤔', '😢', '😡', '😴', '🥳'];

  Future<void> _pickImage() async {
    final syncProvider = context.read<SyncProvider>();
    final prefs = await SharedPreferences.getInstance();

    // Check if we need to show the educational prompt
    // Conditions:
    // 1. WebDAV is configured
    // 2. User has NOT seen the prompt yet
    bool webDavConfigured = syncProvider.isConfigured;
    bool hasShownPrompt =
        prefs.getBool('has_shown_compression_prompt') ?? false;

    if (webDavConfigured && !hasShownPrompt) {
      if (!mounted) return;
      bool? confirmCompression = await showDialog<bool>(
        context: context,
        builder: (ctx) => SkeuomorphicDialog(
          title: '图片上传设置',
          headerIcon: Icons.cloud_upload,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('检测到您已开启 WebDAV 同步。为节省您的云端流量（坚果云等通常每月流量有限），建议开启图片压缩。'),
              SizedBox(height: 10),
              Text(
                '• 压缩模式 (推荐)：保留清晰度的同时大幅减小体积，节省流量。',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '• 原图模式：占用大量空间和流量。',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            SkeuomorphicDialogButton(
              label: '使用原图',
              isPrimary: false,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            SkeuomorphicDialogButton(
              label: '开启压缩 (推荐)',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (confirmCompression != null) {
        // Update Config
        final newConfig = syncProvider.config.copyWith(
          compressImages: confirmCompression,
        );
        await syncProvider.saveConfig(newConfig);
        // Mark as shown
        await prefs.setBool('has_shown_compression_prompt', true);
      } else {
        // User dismissed without choice, don't mark as shown? Or default to no change.
        // Let's just return to avoid picking if they cancelled dialog.
        return;
      }
    }

    try {
      // Get latest config
      bool compress = syncProvider.config.compressImages;

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: compress ? 1920 : null,
        imageQuality: compress ? 80 : null,
      );

      if (images.isNotEmpty) {
        setState(() {
          _images.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (_contentController.text.trim().isEmpty && _images.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写点什么或发张图吧...')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Save images
      List<String> savedImagePaths = [];
      for (var img in _images) {
        String relativePath = await _momentService.saveImage(File(img.path));
        savedImagePaths.add(relativePath);
      }

      // 2. Create Moment
      Moment newMoment = Moment.create(
        content: _contentController.text,
        images: savedImagePaths,
        weather: _selectedWeather,
        mood: _selectedMood,
      );

      // 3. Save Moment
      await _momentService.saveMoment(newMoment);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate reload needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final themeConfig = AppTheme.getMomentEditorTheme(theme);

    // Background can be complex (texture), so we use getBackground if available,
    // or fallback to solid color from config.
    // However, MomentEditorPage usually has a solid/simple background.
    // Let's use the one from config.
    final bgColor = themeConfig['bgColor'] as Color;
    final appBarTextColor = themeConfig['appBarTextColor'] as Color;
    final appBarIconColor = themeConfig['appBarIconColor'] as Color;
    final inputBg = themeConfig['inputBg'] as Color;
    final inputTextColor = themeConfig['inputTextColor'] as Color;
    final hintColor = themeConfig['hintColor'] as Color;
    final photoEmptyColor = themeConfig['photoEmptyColor'] as Color;
    final photoIconColor = themeConfig['photoIconColor'] as Color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          '记一笔',
          style: GoogleFonts.notoSerifSc(color: appBarTextColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: appBarIconColor),
        actions: [
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(appBarIconColor),
                    ),
                  )
                : const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Weather & Mood Selector
            Row(
              children: [
                _buildDropdown(
                  _weathers,
                  _selectedWeather,
                  '天气',
                  (val) => setState(() => _selectedWeather = val),
                ),
                const SizedBox(width: 15),
                _buildDropdown(
                  _moods,
                  _selectedMood,
                  '心情',
                  (val) => setState(() => _selectedMood = val),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Text Input
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                minLines: 5,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 16,
                  height: 1.5,
                  color: inputTextColor,
                ),
                decoration: InputDecoration(
                  hintText: '写下此刻的想法...',
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(15),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Image Grid
            if (_images.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _images.length + 1,
                itemBuilder: (context, index) {
                  if (index == _images.length) {
                    return _buildAddButton(photoEmptyColor, photoIconColor);
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_images[index].path),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              _buildAddButton(photoEmptyColor, photoIconColor, isLarge: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    List<String> items,
    String? value,
    String hint,
    Function(String?) onChanged,
  ) {
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final themeConfig = AppTheme.getMomentEditorTheme(theme);
    final dropdownBg = themeConfig['dropdownBg'] as Color;
    final dropdownIconColor = themeConfig['dropdownIconColor'] as Color;
    final dropdownMenuBg = themeConfig['dropdownMenuBg'] as Color;
    final dropdownItemColor = themeConfig['dropdownItemColor'] as Color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: dropdownBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: dropdownItemColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          icon: Icon(Icons.arrow_drop_down, color: dropdownIconColor),
          dropdownColor: dropdownMenuBg,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: TextStyle(fontSize: 20, color: dropdownItemColor),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAddButton(
    Color bgColor,
    Color iconColor, {
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: isLarge ? 120 : null,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: iconColor.withValues(alpha: 0.5),
            style: BorderStyle.none,
          ), // Removed dashed border for skeuomorphic feel, just bg
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              color: iconColor,
              size: isLarge ? 32 : 24,
            ),
            if (isLarge) ...[
              const SizedBox(height: 8),
              Text(
                "添加图片",
                style: TextStyle(color: iconColor.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
