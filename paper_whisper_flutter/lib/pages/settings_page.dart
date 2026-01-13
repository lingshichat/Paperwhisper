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
import 'sync_settings_page.dart';



class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isCheckingUpdate = false;
  String? _currentVersion;

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
          title: '关于 PaperWhisper',
          subtitle: 'v1.0.0',
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
  
  Widget _buildGlassBottomSheet(BuildContext context, {required String title, required List<Widget> children}) {
    // Simple styled bottom sheet
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAEBD7), // Antiquewhite-ish
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.notoSerifSc(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
          const SizedBox(height: 16),
          ...children
        ],
      ),
    );
  }
  
  Widget _buildRadioItem(BuildContext context, String label, String value, String groupValue, Function(String) onChanged) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () {
        onChanged(value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
             Text(label, style: GoogleFonts.notoSerifSc(fontSize: 16, color: isSelected ? const Color(0xFF8D6E63) : Colors.black54)),
             const Spacer(),
             if (isSelected) const Icon(Icons.check, color: Color(0xFF8D6E63))
          ],
        ),
      ),
    );
  }
}
