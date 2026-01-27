import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';
import '../services/trial_service.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/stamp_animation.dart';
import '../widgets/visual_effects.dart'; // Assuming PetalRainWidget is here
import '../widgets/feature_comparison_sheet.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';


class PremiumMembershipPage extends StatefulWidget {
  const PremiumMembershipPage({super.key});

  @override
  State<PremiumMembershipPage> createState() => _PremiumMembershipPageState();
}

class _PremiumMembershipPageState extends State<PremiumMembershipPage> with TickerProviderStateMixin {
  final TextEditingController _orderController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _inputKey = GlobalKey();
  
  bool _isLoading = false;
  bool _justStamped = false;
  bool _showCelebration = false;
  
  late AnimationController _stampController;
  late Animation<double> _stampAnimation;

  @override
  void initState() {
    super.initState();
    _stampController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _stampAnimation = CurvedAnimation(parent: _stampController, curve: Curves.bounceOut);
  }

  @override
  void dispose() {
    _orderController.dispose();
    _scrollController.dispose();
    _stampController.dispose();
    super.dispose();
  }

  void _scrollToInput() {
     if (_inputKey.currentContext != null) {
       Scrollable.ensureVisible(
         _inputKey.currentContext!, 
         duration: const Duration(milliseconds: 600), 
         curve: Curves.easeInOutCubic
       );
     }
  }

  Future<void> _activateHonestyMode() async {
    setState(() => _isLoading = true);
    
    // 1. Play Stamp Animation
    await _stampController.forward();
    
    // 2. Trigger Activation
    await Provider.of<PaymentService>(context, listen: false).activateHonestyMode();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _justStamped = true;
        _showCelebration = true; // Trigger Petal Rain
      });
      
      SkeuomorphicToast.success(context, "诚信激活成功！\n感谢您的支持与信任");
      
      // Auto-hide celebration after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showCelebration = false);
      });
    }
  }

  Future<void> _payWithAlipay() async {
     // User provided code
     const String alipayQrCode = 'https://qr.alipay.com/fkx187002hv2e7taukh965a'; 
     final Uri alipayScheme = Uri.parse(
        'alipays://platformapi/startapp?saId=10000007&clientVersion=3.7.0.0718&qrcode=${Uri.encodeComponent(alipayQrCode)}'
     );

     try {
       if (await canLaunchUrl(alipayScheme)) {
          await launchUrl(alipayScheme, mode: LaunchMode.externalApplication);
       } else {
          SkeuomorphicToast.warning(context, "未找到支付宝，请手动扫码");
          _showQrCodeDialog("支付宝支付", "assets/images/alipay_qr_payment.jpg");
       }
     } catch (e) {
        SkeuomorphicToast.error(context, "无法跳转支付宝: $e");
     }
  }

  Future<void> _payWithWeChat() async {
    try {
      // 1. Load asset data
      final ByteData data = await rootBundle.load('assets/images/wechat_qr_payment.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // 2. Save to temp file first (Gal needs a file path)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/wechat_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);
      
      // 3. Save to gallery using Gal
      await Gal.putImage(tempFile.path, album: 'PaperWhisper');
      
      // 4. Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      SkeuomorphicToast.success(context, "二维码已保存到相册");
      
      // 5. Launch WeChat
      final Uri wechatScheme = Uri.parse('weixin://');
      if (await canLaunchUrl(wechatScheme)) {
          await Future.delayed(const Duration(milliseconds: 1000));
          await launchUrl(wechatScheme, mode: LaunchMode.externalApplication);
      } else {
          SkeuomorphicToast.warning(context, "未找到微信客户端");
      }
      
    } catch (e) {
      SkeuomorphicToast.error(context, "操作失败: $e");
      debugPrint("WeChat Pay Error: $e");
    }
  }

  void _showQrCodeDialog(String title, String assetPath) {
    showDialog(
      context: context,
      builder: (context) => SkeuomorphicDialog(
        title: title,
        headerIcon: Icons.qr_code,
        content: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: Image.asset(assetPath, width: 200, height: 200),
            ),
            const SizedBox(height: 10),
            Text("请使用相应App扫码支付", style: GoogleFonts.notoSerifSc(fontSize: 12)),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(label: "关闭", onPressed: () => Navigator.pop(context))
        ],
      )
    );
  }



  // NOTE: Removed duplicate subscription dialog logic as per user request

  void _launchSponsor({String? url}) {
    // Default to main profile page if specific url is not provided
    final target = url ?? "https://afdian.com/a/lingshichat";
    launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => SkeuomorphicDialog(
        title: '如何找到订单号？',
        headerIcon: Icons.help_outline,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHelpStep(1, "前往爱发电 App 或网站 (afdian.com)"),
            _buildHelpStep(2, "点击 \"我的\" -> \"我的订单\""),
            _buildHelpStep(3, "找到您赞助的那笔订单"),
            _buildHelpStep(4, "复制 【订单号】 (以 202... 开头)"),
            const SizedBox(height: 10),
            Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: const Color(0xFFE8F5E9),
                 border: Border.all(color: const Color(0xFF43A047)),
                 borderRadius: BorderRadius.circular(4),
               ),
               child: const Text(
                 "提示：如果您拥有爱发电【兑换码】，请先在爱发电官网/App兑换，成功后也会生成订单号。",
                 style: TextStyle(fontSize: 12, color: Color(0xFF1B5E20)),
               ),
            ),
            const SizedBox(height: 8),
            Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: const Color(0xFFFFF3E0),
                 border: Border.all(color: const Color(0xFFFFB74D)),
                 borderRadius: BorderRadius.circular(4),
               ),
               child: const Text(
                 "注意：请不要使用 \"商户单号\"，那是微信/支付宝的流水号，无法验证。",
                 style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
               ),
            ),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '我知道了',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
             width: 20, height: 20,
             alignment: Alignment.center,
             decoration: const BoxDecoration(
               color: Color(0xFF8D6E63),
               shape: BoxShape.circle,
             ),
             child: Text("$index", style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentService = Provider.of<PaymentService>(context);
    final isPro = paymentService.isPro;
    final showStamp = isPro || _justStamped;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0), // Paper white
      appBar: AppBar(
        title: Text(
          "Premium Membership", 
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
      ),
      body: Stack(
        children: [
          // 1. Content Layer
          Center(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F4E6), // Paper color
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- HEADER ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
                      child: Column(
                        children: [
                          const Icon(Icons.auto_awesome, size: 36, color: Color(0xFFD4AF37)),
                          const SizedBox(height: 16),
                          Text(
                            "INVITATION TO\nPAPERWHISPER CLUB",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cinzel(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3E2723),
                              letterSpacing: 3,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "你好呀，这里是纸语PaperWhisper的开发者！\n\n首先，感谢你能体验我们的软件，愿意触及这个拟物风日记本子~\n\n我们相信每一位用户都是真诚的。纸语采用【诚信解锁】机制 —— 滑动到页面底部，点击「我已支付」即可永久解锁所有功能，无需任何验证。\n\n使用我们的软件，就是对我们最大的鼓励。若能支持几块钱请开发者喝杯咖啡，我们将不胜感激 ☕",
                            style: GoogleFonts.notoSerifSc(
                              fontSize: 13,
                              color: const Color(0xFF5D4037),
                              height: 1.8,
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ],
                      ),
                    ),

                    constDivider(color: Color(0xFFD7CCC8), height: 1),

                    // --- FEATURES (FeatureComparisonSheet) ---
                    // Using a simplified inline version or the widget if it fits
                    const Padding(
                       padding: EdgeInsets.symmetric(vertical: 20),
                       child: FeatureComparisonSheet(isEmbedded: true),
                    ),

                    constDivider(color: Color(0xFFD7CCC8), height: 1),

                    // --- PAYMENT OPTIONS ---
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: _buildPaymentOptions(),
                    ),

                    constDivider(color: Color(0xFFD7CCC8), height: 1),

                    // --- TIP JAR ---
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: _buildTipJarSection(),
                    ),

                     // --- FOOTER (Certificate) ---
                    _buildCertificateFooter(context, showStamp, isPro),
                  ],
                ),
              ),
            ),
          ),

          // 2. Celebration Overlay
          if (_showCelebration)
            const IgnorePointer(
              child: PetalRainWidget(burst: true),
            ),
        ],
      ),
    );
  }

  // Helper for Divider
  Widget constDivider({required Color color, required double height}) {
    return Container(height: height, color: color);
  }


  Widget _buildPaymentOptions() {
    return Column(
      children: [
        _buildLifetimeTicket(),
        const SizedBox(height: 20),
        _buildSubscriptionTicket(),
      ],
    );
  }

  Widget _buildLifetimeTicket() {
    return GestureDetector(
      onTap: () {
        // Show Payment QR Code Dialog (Mixed Payment)
        _showPaymentDialog();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F6F0), // Paper white
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF8D6E63), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Left: Icon Ticket Stub
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF3E2723),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.stars, color: Color(0xFFFFD700), size: 32),
            ),
            const SizedBox(width: 16),
            // Middle: Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "终身会员 (Lifetime)",
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E2723),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "一次性买断 · 永久更新",
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      color: const Color(0xFF5D4037),
                    ),
                  ),
                ],
              ),
            ),
            // Right: Price & Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "¥ 38.00",
                  style: GoogleFonts.cinzel(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E2723),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "P A Y",
                    style: GoogleFonts.cinzel(
                      fontSize: 10,
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
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

  Widget _buildSubscriptionTicket() {
    return Opacity(
      opacity: 0.6,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey, width: 1, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_today, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "年度订阅 (Yearly)",
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "灵活订阅 · 随时取消",
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
             Transform.rotate(
               angle: -0.2,
               child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[700]!, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "COMING SOON",
                  style: GoogleFonts.blackOpsOne(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
             ),
          ],
        ),
      ),
    );
  }

  // Mixed Payment Dialog (Alipay + WeChat)
  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => SkeuomorphicDialog(
        title: "选择支付方式",
        headerIcon: Icons.payment,
        content: Column(
          children: [
            Text(
              "感谢您的支持",
              style: GoogleFonts.notoSerifSc(
                fontSize: 14,
                color: const Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPaymentButton(
                  label: "支付宝",
                  color: const Color(0xFF1677FF),
                  icon: Icons.account_balance_wallet,
                  onTap: () {
                     Navigator.pop(context);
                     _payWithAlipay();
                  }
                ),
                _buildPaymentButton(
                  label: "微信支付",
                  color: const Color(0xFF09BB07),
                  icon: Icons.chat_bubble,
                  onTap: () {
                     Navigator.pop(context);
                     _payWithWeChat();
                  }
                ),
              ],
            ),
             const SizedBox(height: 16),
             Text(
               "微信支付需保存二维码后扫码",
               style: GoogleFonts.notoSerifSc(fontSize: 10, color: Colors.black38),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton({
    required String label, 
    required Color color, 
    required IconData icon, 
    required VoidCallback onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
              ]
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.notoSerifSc(
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3E2723)
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSubFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          const Icon(Icons.star_rate_rounded, size: 14, color: Color(0xFFA1887F)),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.notoSerifSc(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  /// 投喂区 - Tip Jar Section
  Widget _buildTipJarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            const Icon(Icons.volunteer_activism, size: 20, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Text(
              "请开发者喝杯咖啡 ☕",
              style: GoogleFonts.notoSerifSc(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5D4037),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "您的支持是我们前进的动力，任何金额都是莫大的鼓励",
          style: GoogleFonts.notoSerifSc(
            fontSize: 11,
            color: const Color(0xFFA1887F),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 20),

        // 投喂选项
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTipButton(
              emoji: "🍗",
              label: "鸡腿",
              amount: "¥5",
              color: const Color(0xFFFF8A65),
            ),
            _buildTipButton(
              emoji: "☕",
              label: "咖啡",
              amount: "¥10",
              color: const Color(0xFF8D6E63),
            ),
            _buildTipButton(
              emoji: "🍰",
              label: "蛋糕",
              amount: "¥20",
              color: const Color(0xFFE91E63),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTipButton({
    required String emoji,
    required String label,
    required String amount,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _showPaymentDialog(),
      child: Container(
        width: 85,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.notoSerifSc(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5D4037),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              amount,
              style: GoogleFonts.cinzel(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateFooter(BuildContext context, bool showStamp, bool isPro) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF0EAE0), // Slightly darker footer area
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
           // Signature Line
           Padding(
             padding: const EdgeInsets.only(bottom: 24),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.center,
                   children: [
                     Text(
                       "PaperWhisper Team", 
                       style: GoogleFonts.dancingScript(fontSize: 20, color: const Color(0xFF3E2723))
                     ),
                     Container(height: 1, width: 120, color: const Color(0xFF3E2723)),
                     const SizedBox(height: 4),
                     Text("ISSUED BY", style: GoogleFonts.cinzel(fontSize: 10, color: Colors.black38)),
                   ],
                 ),
               ],
             ),
           ),

           const SizedBox(height: 20),

           // Interaction Area
           Stack(
             alignment: Alignment.center,
             children: [
               // Base Content
               Column(
                 children: [
                   Text(
                     isPro ? "CERTIFIED MEMBER" : "AWAITING SIGNATURE",
                     style: GoogleFonts.cinzel(
                       fontSize: 18, 
                       fontWeight: FontWeight.bold, 
                       color: isPro ? const Color(0xFF3E2723) : Colors.black26,
                       letterSpacing: 2
                     )
                   ),
                   const SizedBox(height: 16),
                   if (!isPro && !Provider.of<PaymentService>(context).isSubscriptionActive) ...[
                     Text(
                       '如果您已完成支付',
                       textAlign: TextAlign.center,
                       style: GoogleFonts.notoSerifSc(
                         fontSize: 12,
                         color: const Color(0xFF5D4037),
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     const SizedBox(height: 2),
                     Text(
                       'Please confirm your payment',
                       textAlign: TextAlign.center,
                       style: GoogleFonts.cinzel(
                         fontSize: 9,
                         color: Colors.black38,
                         letterSpacing: 0.6,
                       ),
                     ),
                     const SizedBox(height: 16),
                     
                     // Activation Button (Stamp Style)
                     GestureDetector(
                        key: _inputKey, // Keep key for scrolling if needed
                        onTap: _activateHonestyMode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB71C1C),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFB71C1C).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                            ]
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "我已支付，开启权益",
                                style: GoogleFonts.notoSerifSc(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                     ),
                     
                     const SizedBox(height: 12),
                     Text(
                       "诚信为本 · 感谢支持",
                       style: GoogleFonts.notoSerifSc(fontSize: 10, color: Colors.black26),
                     ),

                   ] else ...[
                     Text(
                       "Officially welcomed to the club.",
                       style: GoogleFonts.dancingScript(fontSize: 16, color: const Color(0xFF5D4037)),
                     )
                   ]
                 ],
               ),

               // The Stamp
               if (showStamp)
                IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(40, -10),
                    child: Transform.rotate(
                      angle: -0.2,
                      child: StampAnimation(
                        isStamped: true,
                         child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFB71C1C).withOpacity(0.8), width: 4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'APPROVED',
                            style: GoogleFonts.blackOpsOne(
                              fontSize: 32,
                              color: const Color(0xFFB71C1C).withOpacity(0.8),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
             ],
           ),
        ],
      ),
    );
  }

  Widget _buildTrialOption(bool isPro) {
    if (isPro) return const SizedBox.shrink();

    final trialService = TrialService();
    final hasStarted = trialService.hasTrialBeenStarted;
    final isInTrial = trialService.isInTrial;
    final daysLeft = trialService.trialDaysLeft;

    if (!hasStarted) {
      return GestureDetector(
        onTap: _startTrial,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2F1).withOpacity(0.5), // Teal light
            border: Border.all(color: const Color(0xFF00796B), width: 1.5, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
               const Icon(Icons.timer_outlined, color: Color(0xFF00796B), size: 28),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text("开启 7 天全功能试用", style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold, color: const Color(0xFF004D40), fontSize: 15)),
                     Text("体验所有 Pro 功能，试用结束后自动转为免费版", style: GoogleFonts.notoSerifSc(fontSize: 11, color: const Color(0xFF00695C))),
                   ],
                 ),
               ),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: const Color(0xFF00796B),
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: Text("立即开启", style: GoogleFonts.notoSerifSc(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
               )
            ],
          ),
        ),
      );
    } else if (isInTrial) {
       return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9), // Green light
            border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
             children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF2E7D32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "试用生效中，剩余 $daysLeft 天。喜欢请支持买断版。", 
                    style: GoogleFonts.notoSerifSc(color: const Color(0xFF1B5E20), fontSize: 12)
                  )
                ),
             ],
          ),
       );
    } else {
       // Trial ended/Expired
       return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE), // Red light
            border: Border.all(color: const Color(0xFFC62828).withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
             children: [
                const Icon(Icons.info_outline, color: Color(0xFFC62828)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "试用已结束。感谢您的体验，希望能支持我们继续前行。", 
                    style: GoogleFonts.notoSerifSc(color: const Color(0xFFB71C1C), fontSize: 12)
                  )
                ),
             ],
          ),
       );
    }
  }

  Future<void> _startTrial() async {
     setState(() => _isLoading = true);
     
     // Simulate small network delay
     await Future.delayed(const Duration(milliseconds: 600));
     
     await TrialService().startTrial();
     
     if (mounted) {
        // Refresh PaymentService state
        Provider.of<PaymentService>(context, listen: false).refreshState();
        
        setState(() {
           _isLoading = false;
           _justStamped = true; // Show petal effect
        });
        SkeuomorphicToast.success(context, '试用已开启，尽情书写吧！');
     }
}
}
