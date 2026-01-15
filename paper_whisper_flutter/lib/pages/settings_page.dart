import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../widgets/slide_page_route.dart';
import '../pages/trash_page.dart';
import '../services/storage_service.dart';
import 'sync_settings_page.dart';



class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isCheckingUpdate = false;
  String? _currentVersion;
  String _storageInfo = '计算中...';
  String _currentDataPath = '';
  String _internalStats = '';
  bool _hasInternalClutter = false;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    final service = StorageService();
    final cacheSize = await service.getCacheSize();
    final dataSize = await service.getUserDataSize();
    final path = await service.getDataPath();
    final total = cacheSize + dataSize;
    
    // Internal Check
    final internal = await service.getInternalStorageStats();
    final docSize = internal['doc'] as int? ?? 0;
    final supportSize = internal['support'] as int? ?? 0;
    final clutterSize = internal['clutter'] as int? ?? 0;
    
    // Check clutter: if using External path, but Internal has > 1MB *clutter* data (excl system files)
    bool usingExternal = path.contains('/storage/emulated/0'); // Simple heuristic
    bool hasClutter = usingExternal && clutterSize > 1024 * 1024; // >1MB clutter only

    if (mounted) {
      setState(() {
         _storageInfo = "内容占用: ${_formatSize(total)} (缓存: ${_formatSize(cacheSize)})";
         _currentDataPath = path;
         _internalStats = "Doc: ${_formatSize(docSize)} / Support: ${_formatSize(supportSize)}";
         _hasInternalClutter = hasClutter;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    // 获取主题信息，保持与 Sidebar 一致的设计语言
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;

    // 颜色定义 (参考 SidebarWidget)
    final Color titleColor = isSeaFlower
        ? const Color(0xFF880E4F)
        : (isMidnight ? const Color(0xFFe6edf3) : const Color(0xFFEEFFEB));
        
    final Color textColor = isSeaFlower
        ? const Color(0xFFAD1457)
        : (isMidnight ? const Color(0xFFc9d1d9) : const Color(0xFFD7CCC8));

    final Shadow titleShadow = isSeaFlower
        ? const Shadow(
            color: Color.fromRGBO(255, 255, 255, 0.5),
            offset: Offset(0, 1),
            blurRadius: 2,
          )
        : const Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            offset: Offset(0, 2),
            blurRadius: 4,
          );

    // 背景处理
    Widget background = Container(
      decoration: AppTheme.getBackground(theme),
    );

    // 毛玻璃容器
    Widget content = Scaffold(
      backgroundColor: Colors.transparent, // 让底层背景透出来
      appBar: AppBar(
        title: Text(
          '设置',
          style: GoogleFonts.notoSerifSc(
            color: titleColor,
            fontWeight: FontWeight.bold,
            shadows: [titleShadow],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildList(context, isSeaFlower, isMidnight, textColor, settings),
    );

    if (isSeaFlower) {
      // 海底花海：背景(渐变) + 全局模糊(可选，如果需要整页毛玻璃感) + 内容
      // Sidebar 是局部模糊。这里是整页。如果整页模糊，背景渐变会变糊。
      // 用户反馈"背景异常"，可能是指只有粉色底色。
      // 我们直接展示渐变背景，内容项自己有半透明背景。
      // 如果想要那种"磨砂玻璃板"的感觉覆盖全屏，可以在背景和 Scaffod 之间加一层模糊。
      // 但那样会把漂亮的渐变糊掉。
      // 让我们先只恢复背景渐变。
      return Stack(
        children: [
           Positioned.fill(child: background),
           // 可选：加一层极淡的白雾，增强通透感
           Positioned.fill(child: Container(color: Colors.white.withOpacity(0.1))),
           Positioned.fill(child: content),
        ],
      );
    } else {
      return Stack(
        children: [
          Positioned.fill(child: background),
          Positioned.fill(child: content),
        ],
      );
    }
  }

  Widget _buildList(BuildContext context, bool isSeaFlower, bool isMidnight, Color textColor, SettingsProvider settings) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('通用', textColor),
        const SizedBox(height: 10),
        _buildSettingsItem(
          context: context,
          icon: Icons.cloud_sync_outlined,
          title: '数据同步',
          subtitle: _getSyncStatusText(context),
          isSeaFlower: isSeaFlower,
          isMidnight: isMidnight,
          textColor: textColor,
          onTap: () {
            Navigator.push(
              context,
              SlidePageRoute(page: SyncSettingsPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        // Storage Setting
        _buildSettingsItem(
           context: context,
           icon: Icons.sd_storage_outlined,
           title: '用户数据管理',
           subtitle: _storageInfo, // Need to add this state
           isSeaFlower: isSeaFlower,
           isMidnight: isMidnight,
           textColor: textColor,
           onTap: () => _showStorageManager(context, isSeaFlower, isMidnight, textColor),
        ),
        const SizedBox(height: 12),
        // Recycle Bin
        _buildSettingsItem(
          context: context,
          icon: Icons.delete_outline,
          title: '回收站',
          subtitle: '找回误删的日记',
          isSeaFlower: isSeaFlower,
          isMidnight: isMidnight,
          textColor: textColor,
          onTap: () {
            Navigator.push(
              context,
              SlidePageRoute(page: TrashPage()),
            );
          },
        ),
        const SizedBox(height: 30),
        _buildSectionHeader('外观', textColor),
        const SizedBox(height: 10),
        // Theme Setting
        _buildSettingsItem(
          context: context,
          icon: Icons.palette_outlined,
          title: '主题风格',
          subtitle: _getThemeName(settings.currentTheme),
          isSeaFlower: isSeaFlower,
          isMidnight: isMidnight,
          textColor: textColor,
          onTap: () => _showThemePicker(context, settings),
        ),
        const SizedBox(height: 12),
        // Startup Page Setting
        _buildSettingsItem(
          context: context,
          icon: Icons.start_outlined,
          title: '启动页',
          subtitle: _getStartupPageName(settings.startupPage),
          isSeaFlower: isSeaFlower,
          isMidnight: isMidnight,
          textColor: textColor,
          onTap: () => _showStartupPagePicker(context, settings),
        ),
        const SizedBox(height: 30),
        _buildSectionHeader('关于', textColor),
        const SizedBox(height: 10),
        // 检测更新项
        _buildSettingsItem(
          context: context,
          icon: Icons.system_update_outlined,
          title: '检测更新',
          subtitle: _isCheckingUpdate ? '检测中...' : (_currentVersion != null ? 'v$_currentVersion' : '点击检查新版本'),
          isSeaFlower: isSeaFlower,
          isMidnight: isMidnight,
          textColor: textColor,
          isLoading: _isCheckingUpdate,
          onTap: _isCheckingUpdate ? () {} : () => _checkForUpdate(context),
        ),
        const SizedBox(height: 12),
        _buildSettingsItem(
          context: context,
          icon: Icons.info_outline,
          title: '关于纸语PaperWhisper',
          subtitle: '纸本无言，因你而语',
          isSeaFlower: isSeaFlower,
          isMidnight: isMidnight,
          textColor: textColor,
          onTap: () {
            // TODO: Show About Dialog
          },
        ),
      ],
    );
  }

  /// 手动检测更新
  Future<void> _checkForUpdate(BuildContext context) async {
    setState(() => _isCheckingUpdate = true);
    
    try {
      final updateService = UpdateService();
      final currentVersion = await updateService.getCurrentVersion();
      
      setState(() => _currentVersion = currentVersion);
      
      final updateInfo = await updateService.checkForUpdate();
      
      if (!mounted) return;
      
      if (updateInfo != null) {
        // 有新版本，显示更新弹窗
        UpdateDialog.show(
          context,
          updateInfo: updateInfo,
          currentVersion: currentVersion,
        );
      } else {
        // 已是最新版本
        SkeuomorphicToast.success(context, '已是最新版本 ✔');
      }
    } catch (e) {
      if (!mounted) return;
      SkeuomorphicToast.error(context, '检测更新失败，请检查网络');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  String _getSyncStatusText(BuildContext context) {
    // 监听 SyncProvider 状态
    final syncProvider = Provider.of<SyncProvider>(context);
    if (!syncProvider.isConfigured) return '未配置';
    if (syncProvider.status == SyncStatus.syncing) return '同步中...';
    if (syncProvider.status == SyncStatus.failed) return '同步失败';
    if (syncProvider.lastSyncTime != null) {
      return '上次同步: ${_formatTime(syncProvider.lastSyncTime!)}';
    }
    return '已开启';
  }

  String _formatTime(DateTime time) {
    return "${time.year}-${time.month}-${time.day} ${time.hour}:${time.minute}";
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 5),
      child: Text(
        title,
        style: GoogleFonts.notoSerifSc(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSeaFlower,
    required bool isMidnight,
    required Color textColor,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    // 容器样式
    final BoxDecoration decoration = BoxDecoration(
      color: isSeaFlower 
          ? Colors.white.withValues(alpha: 0.3) 
          : (isMidnight ? const Color(0xFF161b22).withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.05)),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isSeaFlower 
            ? Colors.white.withValues(alpha: 0.4) 
            : (isMidnight ? const Color(0xFF30363d) : Colors.white.withValues(alpha: 0.1)),
      ),
      boxShadow: [
        BoxShadow(
          color: isSeaFlower ? const Color(0xFFF48FB1).withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: decoration,
          child: Row(
            children: [
              Icon(icon, color: textColor.withOpacity(0.8), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 16,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 13,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // 加载中显示指示器，否则显示箭头
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor.withOpacity(0.6)),
                  ),
                )
              else
                Icon(Icons.arrow_forward_ios, color: textColor.withOpacity(0.4), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeName(String theme) {
    switch (theme) {
      case AppTheme.themeSeaFlower: return '海底花海';
      case AppTheme.themeMidnight: return '午夜深蓝';
      default: return '复古纸张';
    }
  }

  String _getStartupPageName(String page) {
    switch (page) {
      case 'moments': return '随心记';
      case 'writer': return '专注书写';
      case 'last': return '恢复上次状态';
      default: return '专注书写';
    }
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildGlassBottomSheet(
        context,
        title: '选择主题',
        children: [
          _buildRadioItem(ctx, '复古纸张', 'default', settings.currentTheme, (val) => settings.setTheme(val)),
          _buildRadioItem(ctx, '海底花海', 'sea_flower', settings.currentTheme, (val) => settings.setTheme(val)),
          _buildRadioItem(ctx, '午夜深蓝', 'midnight', settings.currentTheme, (val) => settings.setTheme(val)),
          _buildRadioItem(ctx, '琥珀光圈', 'amber_lens', settings.currentTheme, (val) => settings.setTheme(val)),
        ]
      )
    );
  }

  void _showStartupPagePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildGlassBottomSheet(
        context,
        title: '选择启动页',
        children: [
          _buildRadioItem(ctx, '专注书写', 'writer', settings.startupPage, (val) => settings.setStartupPage(val)),
          _buildRadioItem(ctx, '随心记', 'moments', settings.startupPage, (val) => settings.setStartupPage(val)),
          // _buildRadioItem(ctx, '恢复上次状态', 'last', settings.startupPage, (val) => settings.setStartupPage(val)),
        ]
      )
    );
  }

  void _showStorageManager(BuildContext context, bool isSeaFlower, bool isMidnight, Color ignoredTextColor) {
    // Force dark text color because bottom sheet background is always AntiqueWhite
    const Color sheetTextColor = Color(0xFF5D4037);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildGlassBottomSheet(
        context,
        title: '用户数据管理',
        children: [
           ListTile(
             leading: const Icon(Icons.delete_sweep, color: sheetTextColor),
             title: Text('清理无用图片 (深度清理)', style: GoogleFonts.notoSerifSc(color: sheetTextColor)),
             subtitle: Text('扫描并删除未被任何随心记引用的冗余图片', style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.6), fontSize: 12)),
             onTap: () async {
               Navigator.pop(ctx);
               SkeuomorphicToast.info(context, '正在深度清理...');
               int freed = await StorageService().cleanOrphanImages();
               await _loadStorageInfo(); // Refresh
               if (context.mounted) {
                   SkeuomorphicToast.success(context, '清理完成，释放 ${_formatSize(freed)} 空间');
               }
             },
           ),
           Divider(color: sheetTextColor.withOpacity(0.1)),
           ListTile(
             leading: const Icon(Icons.cleaning_services, color: sheetTextColor),
             title: Text('立即清理缓存', style: GoogleFonts.notoSerifSc(color: sheetTextColor)),
             subtitle: Text('清理产生的临时文件 (不影响数据)', style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.6), fontSize: 12)),
             onTap: () async {
               Navigator.pop(ctx);
               await StorageService().cleanTemporaryCache();
               await _loadStorageInfo(); // Refresh
               if (context.mounted) {
                   SkeuomorphicToast.success(context, '缓存已清理');
               }
             },
           ),
           const SizedBox(height: 10),
           // Debug Info
           const SizedBox(height: 10),
           // System Data Section
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: Colors.black.withOpacity(0.05),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: Colors.black.withOpacity(0.05)),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                      Icon(Icons.perm_device_information, size: 16, color: sheetTextColor.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text('系统运行数据 (App必须)', style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 13)),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Text(
                   '包含字体缓存 (Support) 及 App 资源文件 (Doc)。\n此部分数据维持 App 正常运行，无需清理。',
                   style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.6), fontSize: 11, height: 1.4),
                 ),
                 const SizedBox(height: 8),
                 Divider(color: Colors.black.withOpacity(0.05), height: 1),
                 const SizedBox(height: 8),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('占用空间: $_internalStats', style: GoogleFonts.notoSerifSc(color: sheetTextColor.withOpacity(0.5), fontSize: 10)),
                     // Keep Font Cache clean as a hidden/advanced action if needed, or just small icon
                   ],
                 ),
                 
                 // Actions
                   if (_hasInternalClutter)
                     Padding(
                       padding: const EdgeInsets.only(top: 8),
                       child: InkWell(
                         onTap: () async {
                            Navigator.pop(ctx);
                            SkeuomorphicToast.info(context, '正在清理私有残留...');
                            int freed = await StorageService().cleanInternalClutter();
                            await _loadStorageInfo();
                            if (context.mounted) SkeuomorphicToast.success(context, '清理了 ${_formatSize(freed)} 旧数据');
                         },
                         child: Text('>> 发现残留数据，点击清理', style: GoogleFonts.notoSerifSc(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                       ),
                     ),
                   if (_internalStats.contains('Support') && !(_internalStats.contains('0 B')))
                     Padding(
                       padding: const EdgeInsets.only(top: 8),
                       child: InkWell(
                         onTap: () async {
                            Navigator.pop(ctx);
                            SkeuomorphicToast.info(context, '正在清理字体缓存...');
                            int freed = await StorageService().cleanFontCache();
                            await _loadStorageInfo();
                            if (context.mounted) SkeuomorphicToast.success(context, '字体缓存已清除 (下次启动将自动重新下载)'); 
                         },
                         child: Text('>> 强制清除字体缓存 (修复显示异常)', style: GoogleFonts.notoSerifSc(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 10)),
                       ),
                     )
               ],
             ),
           )
        ]
      )
    );
  }
  
  Widget _buildGlassBottomSheet(BuildContext context, {required String title, required List<Widget> children}) {
    // Simple styled bottom sheet with fixed AntiqueWhite background
    // We enforce dark text color inside because the background is always light.
    const Color bgColor = Color(0xFFFAEBD7); 
    const Color titleColor = Color(0xFF5D4037);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -2))
        ]
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.notoSerifSc(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRadioItem(BuildContext context, String label, String value, String groupValue, Function(String) onChanged) {
    final isSelected = value == groupValue;
    // Force dark colors for bottom sheet
    final color = isSelected ? const Color(0xFF8D6E63) : const Color(0xFF5D4037).withOpacity(0.8);
    
    return InkWell(
      onTap: () {
        onChanged(value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
             Text(label, style: GoogleFonts.notoSerifSc(fontSize: 16, color: color)),
             const Spacer(),
             if (isSelected) const Icon(Icons.check, color: Color(0xFF8D6E63))
          ],
        ),
      ),
    );
  }
}
