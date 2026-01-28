import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/sync_config.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../services/payment_service.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../widgets/visual_effects.dart';
import 'premium_membership_page.dart';
import '../widgets/slide_page_route.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serverController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  
  // S3 Controllers
  late TextEditingController _s3EndPointController;
  late TextEditingController _s3AccessKeyController;
  late TextEditingController _s3SecretKeyController;
  late TextEditingController _s3BucketController;
  late TextEditingController _s3RegionController;
  
  bool _autoSync = false;
  bool _compressImages = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final config = Provider.of<SyncProvider>(context, listen: false).config;
    _serverController = TextEditingController(text: config.serverUrl);
    _usernameController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);
    
    _s3EndPointController = TextEditingController(text: config.s3EndPoint);
    _s3AccessKeyController = TextEditingController(text: config.s3AccessKey);
    _s3SecretKeyController = TextEditingController(text: config.s3SecretKey);
    _s3BucketController = TextEditingController(text: config.s3BucketName);
    _s3RegionController = TextEditingController(text: config.s3Region ?? '');
    
    _autoSync = config.autoSync;
    _compressImages = config.compressImages;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _s3EndPointController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    _s3BucketController.dispose();
    _s3RegionController.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final provider = Provider.of<SyncProvider>(context, listen: false);
    final newConfig = provider.config.copyWith(
      serverUrl: _serverController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      autoSync: _autoSync,
      compressImages: _compressImages,
      enabled: true, // 保存即尝试启用
      // S3 Fields
      s3EndPoint: _s3EndPointController.text.trim(),
      s3AccessKey: _s3AccessKeyController.text.trim(),
      s3SecretKey: _s3SecretKeyController.text.trim(),
      s3BucketName: _s3BucketController.text.trim(),
      s3Region: _s3RegionController.text.trim().isEmpty ? null : _s3RegionController.text.trim(),
    );

    // 先保存设置
    await provider.saveConfig(newConfig);

    // 测试连接
    final success = await provider.connect();
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        SkeuomorphicToast.success(context, '连接成功！');
      } else {
        SkeuomorphicToast.error(context, '连接失败，请检查配置');
      }
      
      // 如果连接成功且已启用，自动触发一次同步
      if (success && newConfig.enabled) {
        _syncNow();
      }
    }
  }

  Future<void> _syncNow() async {
     setState(() => _isLoading = true);
     final provider = Provider.of<SyncProvider>(context, listen: false);
     try {
       await provider.sync(context: context);
       if (mounted) {
         setState(() => _isLoading = false);
         // Feedback is already handled inside provider.sync with specific error messages
         // But we can check status just in case
         if (provider.status == SyncStatus.success) {
           // SkeuomorphicToast.success(context, '同步完成'); // provider.sync does this now
         }
       }
     } catch (e) {
       if (mounted) {
         setState(() => _isLoading = false);
         // Error toast is also handled in provider.sync usually, but safe to show if not
         // provider.sync throws, so we catch here to stop loading state
       }
     }
  }

  Widget _buildLockCard(BuildContext context, Color textColor, bool isSeaFlower, bool isMidnight) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: textColor.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text('需要赞助才能使用 WebDAV 同步', style: GoogleFonts.notoSerifSc(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('赞助后即可多端同步日记与随心记', style: GoogleFonts.notoSerifSc(color: textColor.withOpacity(0.7), fontSize: 14)),
            const SizedBox(height: 24),
            Material(
              color: isSeaFlower ? const Color(0xFFAD1457) : (isMidnight ? const Color(0xFF7986cb) : const Color(0xFF5D4037)),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => Navigator.push(context, SlidePageRoute(page: const PremiumMembershipPage())),
                borderRadius: BorderRadius.circular(10),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), child: Text('去赞助', style: GoogleFonts.notoSerifSc(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final provider = Provider.of<SyncProvider>(context);
    final canUse = Provider.of<PaymentService>(context, listen: true).canUseProFeatures;
    final theme = settings.currentTheme;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;
    final bool isAfterRain = theme == AppTheme.themeAfterRain;

    // 颜色定义 (与 SettingsPage 保持一致)
    final themeConfig = AppTheme.getSettingsTheme(theme);
    
    final Color titleColor = themeConfig.isNotEmpty
        ? themeConfig['titleColor']
        : (isSeaFlower
            ? const Color(0xFF880E4F)
            : (isMidnight ? const Color(0xFFe6edf3) : const Color(0xFFEEFFEB)));
            
    final Color textColor = themeConfig.isNotEmpty
        ? themeConfig['textColor']
        : (isSeaFlower
            ? const Color(0xFFAD1457)
            : (isMidnight ? const Color(0xFFc9d1d9) : const Color(0xFFD7CCC8)));
            
    final Color hintColor = textColor.withOpacity(0.5);

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
              '数据同步',
              style: GoogleFonts.notoSerifSc(
                color: titleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: AppTheme.getSystemUiOverlayStyle(theme),
            iconTheme: IconThemeData(color: titleColor),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: canUse
            ? SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 协议选择器
                  // 协议选择器 (拟物化滑块)
                  _buildSlidingSwitch(provider, isSeaFlower, isMidnight, isAfterRain),

                  if (provider.config.syncType == SyncType.webdav) ...[
                    _buildSectionTitle('WebDAV 服务器配置', textColor),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _serverController,
                      label: '服务器地址',
                      hint: '例如: https://dav.jianguoyun.com/dav/',
                      textColor: textColor,
                      hintColor: hintColor,
                      isSeaFlower: isSeaFlower,
                      isMidnight: isMidnight,
                      icon: Icons.link,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _usernameController,
                      label: '账号 (Email)',
                      hint: '您的 WebDAV 账号邮箱',
                      textColor: textColor,
                      hintColor: hintColor,
                      isSeaFlower: isSeaFlower,
                      isMidnight: isMidnight,
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _passwordController,
                      label: '密码 / 应用授权码',
                      hint: '坚果云请使用"第三方应用密码"',
                      textColor: textColor,
                      hintColor: hintColor,
                      isSeaFlower: isSeaFlower,
                      isMidnight: isMidnight,
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                  ] else ...[
                     _buildSectionTitle('S3 对象存储配置', textColor),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _s3EndPointController,
                      label: 'Endpoint (API 地址)',
                      hint: '例如: play.min.io 或 oss-cn-hangzhou.aliyuncs.com',
                      textColor: textColor,
                      hintColor: hintColor,
                      isSeaFlower: isSeaFlower,
                      isMidnight: isMidnight,
                      icon: Icons.dns_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _s3BucketController,
                      label: 'Bucket (存储桶名称)',
                      hint: '例如: paper-whisper-backup',
                      textColor: textColor,
                      hintColor: hintColor,
                      isSeaFlower: isSeaFlower,
                      isMidnight: isMidnight,
                      icon: Icons.folder_open_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _s3AccessKeyController,
                      label: 'Access Key (访问密钥)',
                      hint: 'AK...',
                      textColor: textColor,
                      hintColor: hintColor,
                      isSeaFlower: isSeaFlower,
                      isMidnight: isMidnight,
                      icon: Icons.vpn_key_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _s3SecretKeyController,
                      label: 'Secret Key (私有密钥)',
                      hint: 'SK...',
                      textColor: textColor,
                      hintColor: hintColor,
                      isSeaFlower: isSeaFlower,
                      isMidnight: isMidnight,
                      icon: Icons.password_outlined,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                       controller: _s3RegionController,
                       label: 'Region (区域 - 可选)',
                       hint: '默认自动，如 us-east-1',
                       textColor: textColor,
                       hintColor: hintColor,
                       isSeaFlower: isSeaFlower,
                       isMidnight: isMidnight,
                       icon: Icons.map_outlined,
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // 图片压缩开关
                  Container(
                    decoration: BoxDecoration(
                      color: isSeaFlower ? Colors.white.withOpacity(0.4) : (isMidnight ? const Color(0xFF0D1117).withOpacity(0.5) : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: textColor.withOpacity(0.1)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: SwitchListTile(
                      value: _compressImages,
                      onChanged: (val) => setState(() => _compressImages = val),
                      activeColor: AppTheme.getSettingsTheme(theme).isNotEmpty ? AppTheme.getSettingsTheme(theme)['activeSwitchColor'] : (isSeaFlower ? const Color(0xFFAD1457) : (isMidnight ? const Color(0xFF7986cb) : const Color(0xFF5D4037))),
                      activeTrackColor: AppTheme.getSettingsTheme(theme).isNotEmpty ? AppTheme.getSettingsTheme(theme)['activeTrackColor'] : (isSeaFlower ? const Color(0xFFF48FB1) : (isMidnight ? const Color(0xFF9FA8DA) : const Color(0xFFA1887F))),
                      title: Text(
                        '开启图片压缩',
                        style: GoogleFonts.notoSerifSc(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '开启后将压缩上传，显著节省云端存储和流量 (推荐)。\n关闭则上传原图，画质更好但耗流量。',
                          style: GoogleFonts.notoSerifSc(color: textColor.withOpacity(0.7), fontSize: 12),
                        ),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 功能按钮区
                  Row(
                    children: [
                      Expanded(
                        child: _buildButton(
                          label: '测试连接',
                          onTap: _isLoading ? null : _saveAndTest,
                          isPrimary: false,
                          isSeaFlower: isSeaFlower,
                          isMidnight: isMidnight,
                          isAfterRain: isAfterRain,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildButton(
                          label: '立即同步',
                          onTap: _isLoading ? null : _syncNow,
                          isPrimary: true,
                          isSeaFlower: isSeaFlower,
                          isMidnight: isMidnight,
                          isAfterRain: isAfterRain,
                        ),
                      ),
                    ],
                  ),
                  
                   if (_isLoading || provider.status == SyncStatus.syncing)
                     Padding(
                       padding: const EdgeInsets.only(top: 24),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           // Action Text
                           Text(
                             provider.progressMessage.isEmpty ? '正在处理...' : provider.progressMessage,
                             style: GoogleFonts.notoSerifSc(
                               color: textColor.withOpacity(0.9),
                               fontSize: 14,
                               fontWeight: FontWeight.bold,
                             ),
                             textAlign: TextAlign.center,
                           ),
                           const SizedBox(height: 12),
                           
                           // Progress Bar
                           ClipRRect(
                             borderRadius: BorderRadius.circular(4),
                             child: LinearProgressIndicator(
                               value: provider.totalProgress > 0 ? provider.totalProgress : null, // Total Progress
                               backgroundColor: textColor.withOpacity(0.1),
                               color: isSeaFlower ? const Color(0xFFD81B60) : (isMidnight ? const Color(0xFF7986cb) : (isAfterRain ? const Color(0xFF0288D1) : const Color(0xFF795548))),
                               minHeight: 6,
                             ),
                           ),
                           
                           // Speed & ETA Text
                             Padding(
                               padding: const EdgeInsets.only(top: 8),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   Text(
                                     provider.currentFileSpeed,
                                     style: GoogleFonts.robotoMono(
                                       color: textColor.withOpacity(0.6),
                                       fontSize: 12,
                                     ),
                                   ),
                                   if (provider.etaMessage.isNotEmpty) ...[
                                      Text(
                                        '  |  ',
                                        style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12),
                                      ),
                                      Text(
                                        provider.etaMessage,
                                        style: GoogleFonts.notoSerifSc(
                                          color: textColor.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                   ],
                                 ],
                               ),
                             ),
                         ],
                       ),
                     ),
                     
                  const SizedBox(height: 40),
                  _buildTips(textColor, isMidnight, provider.config.syncType),
                ],
              ),
            ),
          )
            : _buildLockCard(context, textColor, isSeaFlower, isMidnight),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.notoSerifSc(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color textColor,
    required Color hintColor,
    required bool isSeaFlower,
    required bool isMidnight,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Builder(
      builder: (context) {
        final theme = Provider.of<SettingsProvider>(context).currentTheme;
        final themeConfig = AppTheme.getSettingsTheme(theme);
        
        final borderSide = BorderSide(
          color: themeConfig.isNotEmpty
              ? themeConfig['groupDecoration'].border.top.color 
              : (isSeaFlower
                  ? const Color(0xFFEC407A).withOpacity(0.3)
                  : (isMidnight ? const Color(0xFF30363d) : Colors.white.withOpacity(0.3))),
        );
        
        final fillColor = themeConfig.isNotEmpty
            ? themeConfig['groupDecoration'].color 
            : (isSeaFlower
                ? Colors.white.withOpacity(0.4)
                : (isMidnight ? const Color(0xFF0D1117).withOpacity(0.5) : Colors.black.withOpacity(0.1)));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.notoSerifSc(
                color: textColor.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.fromBorderSide(borderSide),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: TextFormField(
                controller: controller,
                obscureText: obscureText,
                style: TextStyle(color: textColor),
                validator: (v) => v == null || v.isEmpty ? '不能为空' : null,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: hintColor, fontSize: 13),
                  prefixIcon: Icon(icon, color: textColor.withOpacity(0.6), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
    required bool isSeaFlower,
    required bool isMidnight,
    required bool isAfterRain,
  }) {
    // 按钮样式
    Gradient? gradient;
    Color? color;
    Color textColor = Colors.white;

    if (isPrimary) {
      if (isSeaFlower) {
        gradient = const LinearGradient(colors: [Color(0xFFF06292), Color(0xFFAD1457)]);
      } else if (isMidnight) {
        gradient = const LinearGradient(colors: [Color(0xFF7986cb), Color(0xFF283593)]);
      } else if (isAfterRain) {
        gradient = const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)]);
      } else {
        color = const Color(0xFF5D4037); 
      }
    } else {
      // Secondary
      if (isSeaFlower) {
         color = Colors.white.withOpacity(0.5);
         textColor = const Color(0xFF880E4F);
      } else if (isMidnight) {
         color = const Color(0xFF21262d);
         textColor = const Color(0xFFc9d1d9);
      } else if (isAfterRain) {
         color = Colors.white.withOpacity(0.6);
         textColor = const Color(0xFF0277BD);
      } else {
         color = Colors.white.withOpacity(0.2);
         textColor = const Color(0xFF3E2723);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isPrimary ? [
              BoxShadow(
                color: isSeaFlower 
                    ? const Color(0xFFAD1457).withOpacity(0.3) 
                    : (isMidnight 
                        ? const Color(0xFF283593).withOpacity(0.4) 
                        : (isAfterRain ? const Color(0xFF0288D1).withOpacity(0.3) : Colors.black26)),
                blurRadius: 6,
                offset: const Offset(0, 3)
              )
            ] : null,
            border: !isPrimary ? Border.all(
              color: isSeaFlower 
                  ? const Color(0xFFAD1457).withOpacity(0.2) 
                  : (isAfterRain ? const Color(0xFF0288D1).withOpacity(0.2) : Colors.white.withOpacity(0.1))
            ) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              color: onTap == null ? textColor.withOpacity(0.5) : textColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlidingSwitch(
    SyncProvider provider, bool isSeaFlower, bool isMidnight, bool isAfterRain) {
    // 1. Determine Colors
    Color trackColor;
    Color thumbColor;
    Color activeTextColor;
    Color inactiveTextColor;

    if (isSeaFlower) {
      trackColor = Colors.pink[50]!; 
      thumbColor = Colors.white;
      activeTextColor = const Color(0xFFAD1457);
      inactiveTextColor = const Color(0xFFAD1457).withOpacity(0.5);
    } else if (isMidnight) {
      trackColor = const Color(0xFF0D1117); 
      thumbColor = const Color(0xFF37474F); 
      activeTextColor = const Color(0xFF7986cb); 
      inactiveTextColor = Colors.white54;
    } else if (isAfterRain) {
      trackColor = Colors.lightBlue[50]!;
      thumbColor = Colors.white;
      activeTextColor = const Color(0xFF0288D1);
      inactiveTextColor = const Color(0xFF0288D1).withOpacity(0.5);
    } else {
      // Vintage / Default
      trackColor = const Color(0xFFD7CCC8); 
      thumbColor = const Color(0xFFEFEBE9); 
      activeTextColor = const Color(0xFF5D4037);
      inactiveTextColor = const Color(0xFF5D4037).withOpacity(0.5);
    }

    final isWebDav = provider.config.syncType == SyncType.webdav;

    return Center(
      child: Container(
        height: 44, 
        margin: const EdgeInsets.only(bottom: 24),
        width: double.infinity, 
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(isMidnight ? 0.3 : 0.05),
               offset: const Offset(0, 1),
               blurRadius: 1,
             ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final segmentWidth = width / 2;

            return Stack(
              children: [
                // 1. Thumb (Animated)
                AnimatedAlign(
                  alignment: isWebDav ? Alignment.centerLeft : Alignment.centerRight,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack, 
                  child: Container(
                    width: segmentWidth,
                    height: double.infinity,
                    margin: const EdgeInsets.all(4), 
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isMidnight ? 0.3 : 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Labels (Interactive)
                Row(
                  children: [
                    _buildSwitchLabel('WebDAV', isWebDav, activeTextColor, inactiveTextColor, () {
                      if (!isWebDav) provider.saveConfig(provider.config.copyWith(syncType: SyncType.webdav));
                    }),
                    _buildSwitchLabel('S3 存储', !isWebDav, activeTextColor, inactiveTextColor, () {
                      if (isWebDav) provider.saveConfig(provider.config.copyWith(syncType: SyncType.s3));
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSwitchLabel(String text, bool isActive, Color activeColor, Color inactiveColor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque, 
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.notoSerifSc(
              color: isActive ? activeColor : inactiveColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _buildTips(Color textColor, bool isMidnight, SyncType syncType) {
    String tips;
    if (syncType == SyncType.webdav) {
      tips = '1. 推荐使用坚果云 WebDAV 服务。\n'
           '2. 坚果云服务器地址通常为：https://dav.jianguoyun.com/dav/ \n'
           '3. 密码必须使用坚果云生成的"第三方应用密码"，不可使用登录密码。\n'
           '4. 同步策略：本地和云端双向合并，默认保留最新的修改。';
    } else {
      tips = '1. 支持 MinIO, AWS S3, 阿里云 OSS 等兼容 S3 的对象存储。\n'
           '2. Endpoint 为 API 域名 (例如 play.min.io)，Bucket 需提前创建。\n'
           '3. 请确保 Access Key 和 Secret Key 拥有该 Bucket 的读写权限。\n'
           '4. 开启"图片压缩"可显著节省存储空间和流量。';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMidnight ? const Color(0xFF161b22).withOpacity(0.8) : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: textColor.withOpacity(0.8), size: 18),
              const SizedBox(width: 8),
              Text('小贴士', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tips,
            style: GoogleFonts.notoSerifSc(
              color: textColor.withOpacity(0.7),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
