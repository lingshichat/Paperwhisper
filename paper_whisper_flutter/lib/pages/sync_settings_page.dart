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
    _autoSync = config.autoSync;
    _compressImages = config.compressImages;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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

    // 颜色定义 (与 SettingsPage 保持一致)
    final Color titleColor = isSeaFlower
        ? const Color(0xFF880E4F)
        : (isMidnight ? const Color(0xFFe6edf3) : const Color(0xFFEEFFEB));
    final Color textColor = isSeaFlower
        ? const Color(0xFFAD1457)
        : (isMidnight ? const Color(0xFFc9d1d9) : const Color(0xFFD7CCC8));
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
              'WebDAV 设置',
              style: GoogleFonts.notoSerifSc(
                color: titleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
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
                  _buildSectionTitle('服务器配置', textColor),
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
                      activeColor: isSeaFlower ? const Color(0xFFAD1457) : (isMidnight ? const Color(0xFF7986cb) : const Color(0xFF5D4037)),
                      activeTrackColor: isSeaFlower ? const Color(0xFFF48FB1) : (isMidnight ? const Color(0xFF9FA8DA) : const Color(0xFFA1887F)),
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
                               value: provider.currentFileProgress > 0 ? provider.currentFileProgress : null, // Null = Indeterminate
                               backgroundColor: textColor.withOpacity(0.1),
                               color: isSeaFlower ? const Color(0xFFD81B60) : (isMidnight ? const Color(0xFF7986cb) : const Color(0xFF795548)),
                               minHeight: 6,
                             ),
                           ),
                           
                           // Speed Text
                             Padding(
                               padding: const EdgeInsets.only(top: 8),
                               child: Text(
                                 provider.currentFileSpeed,
                                 style: GoogleFonts.robotoMono( // Monospace for numbers
                                   color: textColor.withOpacity(0.6),
                                   fontSize: 12,
                                 ),
                               ),
                             ),
                         ],
                       ),
                     ),
                     
                  const SizedBox(height: 40),
                  _buildTips(textColor, isMidnight),
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
    final borderSide = BorderSide(
      color: isSeaFlower 
          ? const Color(0xFFEC407A).withOpacity(0.3) 
          : (isMidnight ? const Color(0xFF30363d) : Colors.white.withOpacity(0.3)),
    );
    
    final fillColor = isSeaFlower 
        ? Colors.white.withOpacity(0.4) 
        : (isMidnight ? const Color(0xFF0D1117).withOpacity(0.5) : Colors.black.withOpacity(0.1));

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

  Widget _buildButton({
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
    required bool isSeaFlower,
    required bool isMidnight,
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
      } else {
        color = const Color(0xFF5D4037); // 复古棕
      }
    } else {
      // Secondary
      if (isSeaFlower) {
         color = Colors.white.withOpacity(0.5);
         textColor = const Color(0xFF880E4F);
      } else if (isMidnight) {
         color = const Color(0xFF21262d);
         textColor = const Color(0xFFc9d1d9);
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
                    : (isMidnight ? const Color(0xFF283593).withOpacity(0.4) : Colors.black26),
                blurRadius: 6,
                offset: const Offset(0, 3)
              )
            ] : null,
            border: !isPrimary ? Border.all(
              color: isSeaFlower ? const Color(0xFFAD1457).withOpacity(0.2) : Colors.white.withOpacity(0.1)
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

  Widget _buildTips(Color textColor, bool isMidnight) {
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
            '1. 推荐使用坚果云 WebDAV 服务。\n'
            '2. 坚果云服务器地址通常为：https://dav.jianguoyun.com/dav/ \n'
            '3. 密码必须使用坚果云生成的"第三方应用密码"，不可使用登录密码。\n'
            '4. 同步策略：本地和云端双向合并，默认保留最新的修改。',
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
