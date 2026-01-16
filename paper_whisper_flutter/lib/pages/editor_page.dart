import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/diary_provider.dart';
import '../providers/sync_provider.dart';
import '../models/diary_entry.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';
import '../widgets/paper_sheet_widget.dart';
import '../widgets/visual_effects.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../services/draft_service.dart'; // Added
import '../widgets/slide_page_route.dart'; // Needed for "Save As New" navigation
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../widgets/export_success_dialog.dart';
import 'package:flutter/rendering.dart'; // For RenderRepaintBoundary
import 'package:permission_handler/permission_handler.dart';

class EditorPage extends StatefulWidget {
  final DiaryEntry? entry;
  
  // 如果是从 draft 恢复的，则传入 content，否则为空
  // 但我们通过 service 恢复，不需要传参，直接内部加载
  
  const EditorPage({super.key, this.entry});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WidgetsBindingObserver {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  
  late WeatherType _weather;
  late MoodType _mood;
  late bool _isMarkdown;
  
  bool _isEditing = false;
  late String _currentDateStr;
  
  // Draft Logic
  final _draftService = DraftService();
  Timer? _autoSaveTimer;
  bool _hasDraftChanges = false;
  bool _hasCheckedDraft = false; // Prevent double checking

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    final e = widget.entry;
    _titleController = TextEditingController(text: e?.title ?? '');
    _contentController = TextEditingController(text: e?.content ?? '');
    _weather = e?.weather ?? WeatherType.sunny;
    _mood = e?.mood ?? MoodType.calm;
    _isMarkdown = e?.isMarkdown ?? false; 
    _isEditing = (e == null);
    _currentDateStr = e?.dateString ?? DateTime.now().toString().split(' ')[0];
    
    // Listeners for auto-save
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
    
    // Check Draft after UI build (For BOTH new and existing entries)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDraft());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _performAutoSave(); // 切后台立即保存
    }
  }

  // Auto-Save Logic (Debounce)
  void _onTextChanged() {
    if (!_isEditing) return;
    
    // Reset timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _performAutoSave);
    _hasDraftChanges = true;
  }

  Future<void> _performAutoSave() async {
    if (!mounted || !_hasDraftChanges) return;
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) return; // 空内容不存

    final id = widget.entry?.filename ?? 'new';
    final currentEntry = DiaryEntry(
      filename: id == 'new' ? '' : id,
      dateString: _currentDateStr,
      title: _titleController.text,
      weather: _weather,
      mood: _mood,
      content: _contentController.text,
      isMarkdown: _isMarkdown,
    );
    
    await _draftService.saveDraft(id, currentEntry);
    debugPrint('Auto-saved draft for $id');
    _hasDraftChanges = false; 
  }

  // Restore Logic
  Future<void> _checkDraft() async {
    if (_hasCheckedDraft) return;
    _hasCheckedDraft = true;

    final id = widget.entry?.filename ?? 'new';
    final draft = await _draftService.getDraft(id);
    
    if (draft == null) return;
    
    // 如果是新建，只要有草稿就恢复
    // 如果是编辑旧日记，对比内容是否不同
    if (id != 'new') {
       final currentContent = widget.entry?.content ?? '';
       // 如果草稿内容完全一样，就没必要提示了(可能是上次正常保存遗留的?)
       // 但我们在 save() 成功后会 clearDraft，所以只要有草稿通常意味着有未保存修改
       if (draft.content == currentContent && draft.title == (widget.entry?.title ?? '')) {
          await _draftService.clearDraft(id);
          return;
       }
    } else {
       if (draft.content.isEmpty && draft.title.isEmpty) {
          await _draftService.clearDraft(id);
          return;
       }
    }
    
    if (!mounted) return;

    // 比对残缺 (Check if draft is SMALLER than original)
    // 仅针对非新日记
    bool isIncomplete = false;
    if (id != 'new' && widget.entry != null) {
       // 简单的长度对比，未必精准但有效
       if (draft.content.length < widget.entry!.content.length) {
          isIncomplete = true;
       }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SkeuomorphicDialog(
        title: isIncomplete ? '发现残缺手稿' : '发现未保存手稿',
        headerIcon: isIncomplete ? Icons.warning_amber_rounded : Icons.restore_page,
        content: Text(
          isIncomplete 
             ? '上次编辑可能意外中断，本地草稿内容少于原日记。\n建议"另存为新日记"以对比查看，\n或选择"丢弃"保留原样。'
             : '上次编辑似乎没有保存成功，\n是否恢复到当时的状态？',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerifSc(
            fontSize: 16,
            color: const Color(0xFF5D4037),
            height: 1.6,
          ),
        ),
        // Use footer for custom layout (Column > [Button, Row])
        actions: null, 
        footer: Column(
          children: [
            // 1. 另存为新日记 (Safe Choice - Primary Action)
            SkeuomorphicDialogButton(
              label: '另存为新日记',
              isPrimary: true,
              onPressed: () {
                 Navigator.pop(ctx);
                 Navigator.pushReplacement(
                   context,
                   SlidePageRoute(page: EditorPage(
                     entry: DiaryEntry(
                        filename: '',
                        dateString: draft.dateString,
                        title: draft.title,
                        content: draft.content,
                        weather: draft.weather,
                        mood: draft.mood,
                        isMarkdown: true, 
                     )
                   )),
                 );
              },
            ),
            
            const SizedBox(height: 12), // Spacing
            
            // 2. Secondary Actions in a Row
            Row(
              children: [
                 // 丢弃 (Discard)
                 Expanded(
                   child: SkeuomorphicDialogButton(
                      label: '丢弃草稿',
                      isPrimary: false,
                      onPressed: () async {
                         Navigator.pop(ctx);
                         await _draftService.clearDraft(id);
                         if (mounted) SkeuomorphicToast.success(context, '草稿已丢弃');
                      },
                   ),
                 ),
                 const SizedBox(width: 12),
                 // 恢复 (Overwrite)
                 Expanded(
                   child: SkeuomorphicDialogButton(
                      label: '恢复覆盖',
                      isPrimary: !isIncomplete, 
                      onPressed: () {
                         Navigator.pop(ctx);
                         setState(() {
                            _titleController.text = draft.title;
                            _contentController.text = draft.content;
                            _weather = draft.weather;
                            _mood = draft.mood;
                            _currentDateStr = draft.dateString;
                         });
                         SkeuomorphicToast.success(context, '内容已恢复');
                      },
                   ),
                 ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _save() async {
    // 强制保存一次可能未保存的 draft? 不需要，因为我们马上要存正式文件了
    
    final provider = Provider.of<DiaryProvider>(context, listen: false);
    final newEntry = DiaryEntry(
      filename: widget.entry?.filename ?? '',
      dateString: _currentDateStr,
      title: _titleController.text,
      weather: _weather,
      mood: _mood,
      content: _contentController.text,
      isMarkdown: _isMarkdown,
    );
    
    try {
      await provider.saveEntry(newEntry);
      
      // Save Success: Clear Draft!
      final id = widget.entry?.filename ?? 'new';
      await _draftService.clearDraft(id);
      
      if (mounted) {
        final syncProvider = context.read<SyncProvider>();
        if (syncProvider.isConfigured) {
           SkeuomorphicToast.success(context, '日记已保存，准备同步...');
           // 检查权限并请求同步
           syncProvider.checkNotificationPermission(context).then((_) {
              if (mounted) syncProvider.requestAutoSync(force: true);
           });
        } else {
           SkeuomorphicToast.success(context, '日记已保存');
        }
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Save failed: $e");
      if (mounted) {
         SkeuomorphicToast.error(context, '保存失败: $e\n请检查存储权限或稍后重试');
      }
    }
  }

  void _delete() async {
    if (widget.entry == null) return;
    final provider = Provider.of<DiaryProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: '确认撕毁？',
        headerIcon: Icons.delete_forever,
        content: Text(
           '这段回忆将被永久抹去，无法从纸篓中捡回。\n确定要这么做吗？',
           textAlign: TextAlign.center,
           style: GoogleFonts.notoSerifSc(
             fontSize: 16,
             color: const Color(0xFF5D4037),
             height: 1.6,
           ),
        ),
        actions: [
          SkeuomorphicDialogButton(
             label: '彻底撕毁',
             isPrimary: false, 
             onPressed: () => Navigator.pop(ctx, true),
          ),
          SkeuomorphicDialogButton(
             label: '保留',
             isPrimary: true, 
             onPressed: () => Navigator.pop(ctx, false),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deleteEntry(widget.entry!.filename);
      // Delete success: Also clear draft if any
      await _draftService.clearDraft(widget.entry!.filename);
      
      if (mounted) Navigator.pop(context);
    }
  }

  bool get _hasChanges {
    // New entry: only dirty if there is content
    if (widget.entry == null) {
      return _titleController.text.isNotEmpty || _contentController.text.isNotEmpty;
    }
    // Existing entry: compare with initial values
    return _titleController.text != (widget.entry?.title ?? '') ||
           _contentController.text != (widget.entry?.content ?? '') ||
           _weather != (widget.entry?.weather ?? WeatherType.sunny) ||
           _mood != (widget.entry?.mood ?? MoodType.calm);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => SkeuomorphicDialog(
        title: '尚未保存',
        headerIcon: Icons.save_as,
        content: Text(
          '文字还未落到纸上，确认要丢弃刚才的修改吗？',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerifSc(
            fontSize: 16,
            color: const Color(0xFF5D4037),
            height: 1.6,
          ),
        ),
        actions: [
          SkeuomorphicDialogButton(
             label: '丢弃',
             isPrimary: false,
             onPressed: () async {
                 // Discard: Clear draft too!
                 final id = widget.entry?.filename ?? 'new';
                 await _draftService.clearDraft(id);
                 Navigator.pop(context, true);
             },
          ),
          SkeuomorphicDialogButton(
             label: '继续编辑',
             isPrimary: true,
             onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // ... (Keep existing build method unchanged)
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final textColor = AppTheme.getTextColor(theme);
    final secondaryColor = AppTheme.getTextSecondaryColor(theme);
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isAmber = theme == AppTheme.themeAmberLens;
    
    // 700px width constraint handled by PaperSheetWidget
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Background handled by Stack in main layout, but here we cover full screen?
        // Actually EditorPage is pushed, so it needs its own background
        body: Stack(
          children: [
            // Background（不再添加动画效果组件，由下层页面提供）
             Container(decoration: AppTheme.getBackground(theme)),
  
            // Main View
            Column(
              children: [
                // Top Bar
                _buildTopBar(context, theme, textColor),
                
                // Scrollable Paper
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 50),
                    child: RepaintBoundary(
                      key: _sheetKey,
                      child: PaperSheetWidget(
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.stretch,
                           children: [
                              // 1. Header (Title + Meta)
                              _buildHeader(textColor, secondaryColor),
                              const SizedBox(height: 30),
                              
                              // 2. Decorative Line
                              Center(
                                child: Container(
                                  width: 60,
                                  height: 2, 
                                  color: (isSeaFlower
                                      ? const Color(0xFFEC407A) 
                                      : (isAmber ? const Color(0xFFFF9800) : (theme == AppTheme.themeMidnight ? const Color(0xFF7986cb) : const Color(0xFFC0392B)))).withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 30),
  
                              // 3. Content Area
                              _buildContentArea(textColor, theme),
  
                              // 4. Footer
                              const SizedBox(height: 60),
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'CREATED WITH',
                                      style: GoogleFonts.courierPrime(
                                         fontSize: 10, 
                                         color: secondaryColor.withValues(alpha: 0.4),
                                         letterSpacing: 2
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '纸语 PaperWhisper',
                                      style: GoogleFonts.notoSerifSc(
                                         fontSize: 12,
                                         color: secondaryColor.withValues(alpha: 0.6),
                                         fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ],
                                ),
                              )
                           ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String theme, Color textColor) {
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isAmber = theme == AppTheme.themeAmberLens;
    
    final Color barBg;
    if (isSeaFlower) {
      barBg = Colors.white.withOpacity(0.2);
    } else if (theme == AppTheme.themeMidnight) {
      barBg = const Color(0xFF0D1117).withValues(alpha: 0.9);
    } else if (isAmber) {
      barBg = const Color(0xFF1E1E1E).withValues(alpha: 0.9);
    } else {
      barBg = const Color(0xFF281815).withValues(alpha: 0.75);
    }
        
    final Color iconColor = isSeaFlower || theme == AppTheme.themeMidnight || isAmber
        ? (isSeaFlower ? const Color(0xFF880E4F) : (isAmber ? const Color(0xFFFF9800) : const Color(0xFFc9d1d9)))
        : const Color(0xFFD7CCC8);
        
    final Border? border = isSeaFlower
        ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)))
        : (isAmber ? Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))) : null);

    Widget barContent = Container(
      // 移除固定高度，改用最小高度约束+padding适配
      constraints: BoxConstraints(
        minHeight: kToolbarHeight + MediaQuery.of(context).padding.top,
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top : 24,
        left: 10, 
        right: 20,
        bottom: 8, // 添加底部留白以保证美观
      ),
      decoration: BoxDecoration(
        color: barBg,
        border: border,
      ),
      child: Row(
        children: [
          TextButton.icon(
             icon: Icon(Icons.arrow_back, color: iconColor, size: 18),
             label: Text('返回列表', style: TextStyle(color: iconColor)),
             onPressed: () async {
                if (await _onWillPop()) {
                   if (context.mounted) Navigator.pop(context);
                }
             }, 
          ),
          const Spacer(),
          // Action Buttons
          IconButton(
            icon: Icon(Icons.share_outlined, color: iconColor), 
            onPressed: _captureAndSave,
            tooltip: '导出为图片',
          ),
          const SizedBox(width: 5),

          if (!_isEditing && widget.entry != null) ...[
             IconButton(
               icon: Icon(Icons.delete_outline, color: iconColor), 
               onPressed: _delete,
               tooltip: '撕毁',
             ),
             const SizedBox(width: 10),
          ],
          
          if (_isEditing)
             ElevatedButton.icon(
               icon: Text('✓', style: TextStyle(
                 color: isSeaFlower ? const Color(0xFFC2185B) : (isAmber ? Colors.black : const Color(0xFFC0392B)), 
                 fontWeight: FontWeight.bold
               )),
               label: Text('完成', style: TextStyle(
                 color: isSeaFlower ? const Color(0xFF880E4F) : (isAmber ? Colors.black : const Color(0xFF5D4037)), 
                 fontWeight: FontWeight.bold
               )),
               style: ElevatedButton.styleFrom(
                 backgroundColor: isSeaFlower ? Colors.white.withValues(alpha: 0.9) : (isAmber ? const Color(0xFFFF9800) : const Color(0xFFF7F1E3)),
                 elevation: 4,
               ),
               onPressed: _save,
             )
          else
             IconButton(
               icon: Icon(Icons.edit_outlined, color: iconColor),
               onPressed: () => setState(() => _isEditing = true),
               tooltip: '编辑',
             ),
        ],
      ),
    );
    
    // Apply blur for Sea Flower
    if (isSeaFlower) {
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: barContent,
        ),
      );
    }
    
    return barContent;
  }

  Widget _buildHeader(Color textColor, Color secondaryColor) {
    // Need theme context here for cursor color check
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower; // Re-declare for snippet context or use theme check directly
    return Column(
      children: [
         if (_isEditing)
           TextField(
             controller: _titleController,
             textAlign: TextAlign.center,
             style: GoogleFonts.notoSerifSc(
                fontSize: 36, 
                fontWeight: FontWeight.bold, 
                color: textColor // Use dynamic theme color
             ),
             cursorColor: theme == AppTheme.themeMidnight ? const Color(0xFF7986cb) : (theme == AppTheme.themeAmberLens ? const Color(0xFFFF9800) : const Color(0xFFC0392B)),
             decoration: InputDecoration(
               hintText: '在此输入标题...',
               hintStyle: TextStyle(color: theme == AppTheme.themeMidnight ? Colors.white24 : (theme == AppTheme.themeAmberLens ? Colors.grey : Colors.black26)),
               border: InputBorder.none,
             ),
           )
         else
           Text(
             _titleController.text.isEmpty ? '无题' : _titleController.text,
             style: GoogleFonts.notoSerifSc(
                fontSize: 36, 
                fontWeight: FontWeight.bold, 
                color: textColor // Use dynamic theme color
             ),
             textAlign: TextAlign.center,
           ),
         
         const SizedBox(height: 15),
         // Meta
         Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
              Text(_currentDateStr, style: _metaStyle(secondaryColor)),
              _metaSeparator(secondaryColor),
              _buildWeatherSelector(secondaryColor),
              _metaSeparator(secondaryColor),
              _buildMoodSelector(secondaryColor),
           ],
         )
      ],
    );
  }

  Widget _buildContentArea(Color textColor, String theme) {
    const double fontSize = 18.0;
    const double lineHeight = 32.0;
    
    // Strict alignment: height = 32/18 = 1.7777...
    
    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
         lineColor: theme == AppTheme.themeMidnight 
            ? Colors.white.withValues(alpha: 0.08) 
            : (theme == AppTheme.themeAmberLens ? const Color(0x1FFFFFFF) : const Color(0xFF5D4037).withValues(alpha: 0.12)),
         lineHeight: lineHeight,
      ),
      child: Container(
        padding: const EdgeInsets.only(top: 0), // Adjust if needed
        constraints: const BoxConstraints(minHeight: 300),
        child: _isEditing
           ? TextField(
                controller: _contentController,
               style: GoogleFonts.notoSerifSc(
                  fontSize: fontSize,
                  color: textColor,
                  height: lineHeight / fontSize,
               ),
               strutStyle: StrutStyle(
                 fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                 fontSize: fontSize,
                 height: (lineHeight / fontSize),
                 leading: 0,
                 forceStrutHeight: true,
                 leadingDistribution: TextLeadingDistribution.even,
               ),
               cursorColor: theme == AppTheme.themeMidnight ? const Color(0xFF7986cb) : (theme == AppTheme.themeAmberLens ? const Color(0xFFFF9800) : const Color(0xFFC0392B)),
               cursorHeight: 22, // Slightly increase cursor height to fill the line better or keep it same
               decoration: const InputDecoration(
                 border: InputBorder.none,
                 contentPadding: EdgeInsets.zero,
                 isCollapsed: true, // 移除所有默认内边距
                 isDense: true, // 使用紧凑模式
                 counterText: "", // Hide counter if any
               ),
               maxLines: null,
             )
           : Text(
               _contentController.text,
               style: GoogleFonts.notoSerifSc(
                  fontSize: fontSize,
                  color: textColor,
                  height: lineHeight / fontSize,
               ),
               strutStyle: StrutStyle(
                 fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                 fontSize: fontSize,
                 height: (lineHeight / fontSize),
                 leading: 0,
                 forceStrutHeight: true,
                 leadingDistribution: TextLeadingDistribution.even,
               ),
             ),
      ),
    );
  }

  // Helpers
  TextStyle _metaStyle(Color color) => GoogleFonts.courierPrime(fontSize: 14, color: color);
  
  Widget _metaSeparator(Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text('·', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
  );

  Widget _buildWeatherSelector(Color color) {
    if (!_isEditing) {
       return Text(_weather.name.toUpperCase(), style: _metaStyle(color));
    }
    // Simple dropdown for now
    return DropdownButton<WeatherType>(
       value: _weather,
       underline: const SizedBox(),
       icon: const SizedBox(), // Hide icon, make text clickable
       items: WeatherType.values.map((w) => DropdownMenuItem(
         value: w,
         child: Text(w.name.toUpperCase(), style: _metaStyle(color)),
       )).toList(),
       onChanged: (val) {
         if (val != null) setState(() => _weather = val);
       },
    ); 
  }

  Widget _buildMoodSelector(Color color) {
    if (!_isEditing) {
       return Text(_mood.name.toUpperCase(), style: _metaStyle(color));
    }
    return DropdownButton<MoodType>(
       value: _mood,
       underline: const SizedBox(),
       icon: const SizedBox(),
       items: MoodType.values.map((m) => DropdownMenuItem(
         value: m,
         child: Text(m.name.toUpperCase(), style: _metaStyle(color)),
       )).toList(),
       onChanged: (val) {
         if (val != null) setState(() => _mood = val);
       },
    );
  }

  // Export Logic
  final GlobalKey _sheetKey = GlobalKey();

  Future<void> _captureAndSave() async {
     try {
       // Wait for build
       await Future.delayed(const Duration(milliseconds: 50));

       RenderRepaintBoundary? boundary = _sheetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
       if (boundary == null) return;

       SkeuomorphicToast.info(context, '正在生成图片...');
       
       ui.Image image = await boundary.toImage(pixelRatio: 3.0);
       var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
       var pngBytes = byteData!.buffer.asUint8List();

       final directory = await getApplicationDocumentsDirectory(); 
       String exportPath;
      
       if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) {
           // Change to standard Pictures directory for Gallery visibility
           exportPath = '/storage/emulated/0/Pictures/PaperWhisper';
        } else {
           // Fallback to app specific external dir or standard docs
           final extDir = await getExternalStorageDirectory();
           // extDir is Android/data/.../files
           // Let's use a nice subfolder
           if (extDir != null) {
              exportPath = path.join(extDir.path, 'Exports');
           } else {
              exportPath = path.join(directory.path, 'Exports');
           }
        }
      } else {
        exportPath = path.join(directory.path, 'PaperWhisper_Exports');
      }
      
      final exportDir = Directory(exportPath);
      if (!await exportDir.exists()) {
        try {
          await exportDir.create(recursive: true);
        } catch (e) {
           // Final fallback
           final recoverDir = await getApplicationDocumentsDirectory();
           exportPath = path.join(recoverDir.path, 'Exports');
           await Directory(exportPath).create(recursive: true);
        }
      }
       
       String fileName = 'diary_${widget.entry?.filename ?? "new"}_${DateTime.now().millisecondsSinceEpoch}.png';
       final file = File(path.join(exportDir.path, fileName));
       await file.writeAsBytes(pngBytes);
       
       if (mounted) {
          await showExportSuccessDialog(context, file.path);
       }
     } catch (e) {
       if (mounted) {
         SkeuomorphicToast.error(context, '导出失败: $e');
       }
     }
  }
}



class LinedPaperPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;

  LinedPaperPainter({required this.lineColor, required this.lineHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    // Start drawing lines from top
    // We want the text to sit ON the line. Text height 1.77 * 18 ≈ 31.86 -> ~32px.
    // First line should be at roughly 32.
    // Draw lines until the end of the canvas + extra buffer to look nice
    // Fix: Draw slightly beyond height to ensure last line is covered
    for (double y = lineHeight + 2; y <= size.height + lineHeight; y += lineHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
