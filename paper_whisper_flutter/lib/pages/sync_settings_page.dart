import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/sync_config.dart';
import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/skeuomorphic_toast.dart';

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final config = Provider.of<SyncProvider>(context, listen: false).config;
    _serverController = TextEditingController(text: config.serverUrl);
    _usernameController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);
    _autoSync = config.autoSync;
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
     await provider.sync();
     if (mounted) {
       setState(() => _isLoading = false);
       if (provider.status == SyncStatus.success) {
         SkeuomorphicToast.success(context, '同步完成');
       } else {
         SkeuomorphicToast.error(context, '同步失败: ${provider.lastError}');
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
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

    // 背景图
    Widget background = Container(
      decoration: AppTheme.getBackground(theme),
    );
    
    // 如果是 SeaFlower，可以在背景之上加一层极淡的白色遮罩，增加层次感，但不要模糊背景，
    // 因为这会把渐变弄成一团浆糊，且消耗性能。
    if (isSeaFlower) {
       background = Stack(
         children: [
            background,
            Container(color: Colors.white.withOpacity(0.1)),
         ],
       );
    }

    return Stack(
      children: [
        Positioned.fill(child: background),
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
          body: SingleChildScrollView(
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
                  
                  if (_isLoading)
                     Padding(
                       padding: const EdgeInsets.only(top: 20),
                       child: Center(
                         child: CircularProgressIndicator(color: titleColor),
                       ),
                     ),
                     
                  const SizedBox(height: 40),
                  _buildTips(textColor, isMidnight),
                ],
              ),
            ),
          ),
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
