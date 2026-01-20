
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';
import 'skeuomorphic_dialog.dart';
import 'skeuomorphic_toast.dart';

class PrivacyAgreementDialog extends StatelessWidget {
  final VoidCallback onAgree;
  final VoidCallback onDisagree;

  const PrivacyAgreementDialog({
    super.key,
    required this.onAgree,
    required this.onDisagree,
  });

  @override
  Widget build(BuildContext context) {
    // 获取当前主题颜色用于链接高亮
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final isSeaFlower = theme == AppTheme.themeSeaFlower;
    final isMidnight = theme == AppTheme.themeMidnight;

    final linkColor = isSeaFlower
        ? const Color(0xFFAD1457)
        : (isMidnight ? const Color(0xFF7986cb) : const Color(0xFF6D4C41));

    return PopScope(
      canPop: false, // 禁止返回键关闭
      child: SkeuomorphicDialog(
        title: '服务协议与隐私政策',
        headerIcon: Icons.privacy_tip_outlined,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '欢迎使用“纸语PaperWhisper”！',
              style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: GoogleFonts.notoSerifSc(
                  fontSize: 15,
                  height: 1.6,
                  color: isSeaFlower
                      ? const Color(0xFFAD1457)
                      : (isMidnight ? const Color(0xFFc9d1d9) : const Color(0xFF5D4037)),
                ),
                children: [
                  const TextSpan(text: '请您在使用前仔细阅读并同意'),
                  _buildLinkSpan(
                    context, 
                    '《用户协议》', 
                    'https://lingshichat.feishu.cn/docx/ODY0dLSF4okfuzximQuctlMon7g?from=from_copylink',
                    linkColor
                  ),
                  const TextSpan(text: '与'),
                  _buildLinkSpan(
                    context, 
                    '《隐私政策》', 
                    'https://lingshichat.feishu.cn/docx/Gd6sdvdmRonHO9x6fMccUr3qnXg?from=from_copylink',
                    linkColor
                  ),
                  const TextSpan(text: '。我们将严格遵守相关法律法规，采取相应安全保护措施，全力保障您的信息安全与合法权益。'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '如您同意以上协议，请点击“同意并继续”开始使用我们的服务。如不同意，很遗憾我们将无法为您提供服务。',
              style: GoogleFonts.notoSerifSc(
                fontSize: 14,
                color: isSeaFlower
                      ? const Color(0xFFAD1457).withOpacity(0.7)
                      : (isMidnight ? const Color(0xFF8b949e) : const Color(0xFF8D6E63)),
              ),
            ),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '不同意并退出',
            isPrimary: false,
            onPressed: onDisagree,
          ),
          SkeuomorphicDialogButton(
            label: '同意并继续',
            isPrimary: true,
            onPressed: onAgree,
          ),
        ],
      ),
    );
  }

  TextSpan _buildLinkSpan(BuildContext context, String text, String url, Color color) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => _launchUrl(context, url),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      // 1. 尝试应用内浏览器 (Chrome Custom Tabs / Safari VC)
      if (!await launchUrl(
        uri, 
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(showTitle: true),
      )) {
        // 2. 降级到 WebView (App内WebView)
        if (!await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
           webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
        )) {
           // 3. 降级到外部浏览器
           if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
             if (context.mounted) {
               SkeuomorphicToast.error(context, '无法打开链接');
             }
           }
        }
      }
    } catch (e) {
      if (context.mounted) {
        SkeuomorphicToast.error(context, '无法打开链接，请检查网络');
      }
    }
  }
}
