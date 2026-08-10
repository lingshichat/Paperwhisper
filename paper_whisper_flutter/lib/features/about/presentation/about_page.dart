import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:paper_whisper_flutter/config/app_theme.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/services/update_service.dart';
import 'package:paper_whisper_flutter/widgets/skeuomorphic_toast.dart';
import 'package:paper_whisper_flutter/widgets/visual_effects.dart';

/// 关于纸语页面
/// 信纸风格展示项目信息、外部链接和开源协议
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// 动态读取应用版本号
  Future<void> _loadVersion() async {
    try {
      final version = await UpdateService().getCurrentVersion();
      if (mounted) {
        setState(() => _version = version);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _version = '未知');
      }
    }
  }

  /// 打开外部链接
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      // 优先尝试应用内浏览器
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      );

      if (!launched) {
        // 降级到 WebView
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        return;
      }

      if (!launched) {
        // 最后降级到系统浏览器
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (!mounted) return;
          SkeuomorphicToast.error(context, '无法打开链接');
        }
      }
    } catch (e) {
      if (!mounted) return;
      // 尝试降级打开
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {}
      if (!mounted) return;
      SkeuomorphicToast.error(context, '无法打开链接: $e');
    }
  }

  /// 显示 MIT 协议全文
  void _showMitLicense() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final settingsTheme = ThemeRegistry.get(theme).settings;
    final Color bgColor = settingsTheme.sheetBackgroundColor;
    final Color textColor = settingsTheme.sheetTextColor;
    final Color titleColor = settingsTheme.sheetTitleColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black26)],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: titleColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'MIT License',
              style: GoogleFonts.cinzel(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  _mitLicenseText,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.8),
                    height: 1.6,
                  ),
                ),
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
    final theme = settings.currentTheme;
    final settingsTheme = ThemeRegistry.get(theme).settings;

    final Color titleColor = settingsTheme.titleColor;
    final Shadow titleShadow = settingsTheme.titleShadow;

    // 信纸内容使用 sheet 系列颜色（适配深色背景主题下的浅色信纸）
    final Color sheetBgColor = settingsTheme.sheetBackgroundColor;
    final Color sheetTextColor = settingsTheme.sheetTextColor;
    final Color sheetTitleColor = settingsTheme.sheetTitleColor;
    final Color sheetTapeColor = settingsTheme.sheetTapeColor;

    Widget content = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          '关于纸语',
          style: GoogleFonts.notoSerifSc(
            color: titleColor,
            fontWeight: FontWeight.bold,
            shadows: [titleShadow],
          ),
        ),
        backgroundColor: Colors.transparent,
        systemOverlayStyle: AppTheme.getSystemUiOverlayStyle(theme),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: sheetBgColor,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 信纸顶部装饰（胶带） ---
                _buildTapeDecoration(sheetTapeColor),

                // --- 头部信息 ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                  child: Column(
                    children: [
                      // App 英文名
                      Text(
                        '~ PaperWhisper ~',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: sheetTitleColor,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // App 中文名
                      Text(
                        '纸语',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: sheetTitleColor,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Slogan
                      Text(
                        '"纸本无言，因你而语"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: sheetTextColor,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 版本号
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sheetTitleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sheetTitleColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'v$_version',
                          style: GoogleFonts.notoSerifSc(
                            fontSize: 12,
                            color: sheetTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- 分割线 ---
                _buildDivider(sheetTextColor),

                // --- 链接区域 ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 8),
                  child: Text(
                    '链接',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      color: sheetTextColor,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildLinkItem(
                        icon: Icons.language,
                        title: '官方网站',
                        subtitle: 'paperwhisper.lingshichat.top',
                        accentColor: sheetTitleColor,
                        textColor: sheetTitleColor,
                        secondaryColor: sheetTextColor,
                        onTap: () =>
                            _launchUrl('https://paperwhisper.lingshichat.top/'),
                      ),
                      _buildLinkItem(
                        icon: Icons.code,
                        title: 'GitHub',
                        subtitle: 'lingshichat/Paperwhisper',
                        accentColor: sheetTitleColor,
                        textColor: sheetTitleColor,
                        secondaryColor: sheetTextColor,
                        onTap: () => _launchUrl(
                          'https://github.com/lingshichat/Paperwhisper',
                        ),
                      ),
                      _buildLinkItem(
                        icon: Icons.camera_alt_outlined,
                        title: '小红书',
                        subtitle: '关注我们的动态',
                        accentColor: sheetTitleColor,
                        textColor: sheetTitleColor,
                        secondaryColor: sheetTextColor,
                        onTap: () => _launchUrl(
                          'https://www.xiaohongshu.com/user/profile/6115f765000000000101d9b6',
                        ),
                      ),
                    ],
                  ),
                ),

                // --- 分割线 ---
                _buildDivider(sheetTextColor),

                // --- 开源协议 ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 8),
                  child: Text(
                    '开源协议',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      color: sheetTextColor,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildLinkItem(
                    icon: Icons.description_outlined,
                    title: 'MIT License',
                    subtitle: '点击查看协议全文',
                    accentColor: sheetTitleColor,
                    textColor: sheetTitleColor,
                    secondaryColor: sheetTextColor,
                    onTap: _showMitLicense,
                  ),
                ),

                const SizedBox(height: 24),

                // --- 底部签名区域（含火漆印章） ---
                Container(
                  width: double.infinity,
                  color: sheetBgColor.withValues(alpha: 0.9),
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                  child: Column(
                    children: [
                      // 火漆印章装饰
                      Text(
                        'Since 2026.1',
                        style: GoogleFonts.dancingScript(
                          fontSize: 18,
                          color: sheetTextColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 团队签名
                      Text(
                        'PaperWhisper Team',
                        style: GoogleFonts.dancingScript(
                          fontSize: 24,
                          color: sheetTitleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Made with love',
                        style: GoogleFonts.cinzel(
                          fontSize: 10,
                          color: sheetTextColor,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 返回带背景和视觉特效的 Stack
    return Stack(
      children: [
        // 1. 主题背景
        Positioned.fill(
          child: Container(decoration: AppTheme.getBackground(theme)),
        ),
        // 2. 视觉特效
        if (settingsTheme.showPetalRain)
          const Positioned.fill(child: PetalRainWidget()),
        if (settingsTheme.showStarrySky)
          const Positioned.fill(child: StarrySkyWidget()),
        // 3. 页面内容
        Positioned.fill(child: content),
      ],
    );
  }

  /// 构建顶部胶带装饰
  Widget _buildTapeDecoration(Color accentColor) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        const SizedBox(height: 20),
        Positioned(
          top: -8,
          child: Transform.rotate(
            angle: -0.03,
            child: Container(
              width: 80,
              height: 24,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建分割线
  Widget _buildDivider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Divider(color: color.withValues(alpha: 0.3), thickness: 1),
    );
  }

  /// 构建链接项
  Widget _buildLinkItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color textColor,
    required Color secondaryColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 11,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: secondaryColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MIT 协议全文
const String _mitLicenseText = '''MIT License

Copyright (c) PaperWhisper Team

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.''';
