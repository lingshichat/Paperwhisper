
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_service.dart';
import '../widgets/skeuomorphic_toast.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/stamp_animation.dart';
import '../widgets/visual_effects.dart';

class PremiumMembershipPage extends StatefulWidget {
  const PremiumMembershipPage({super.key});

  @override
  State<PremiumMembershipPage> createState() => _PremiumMembershipPageState();
}

class _PremiumMembershipPageState extends State<PremiumMembershipPage> {
  final TextEditingController _orderController = TextEditingController();
  bool _isLoading = false;
  bool _justStamped = false; // Flag to trigger animation just once

  @override
  void dispose() {
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _verifyOrder() async {
    final orderId = _orderController.text.trim();
    if (orderId.isEmpty) {
      SkeuomorphicToast.warning(context, '请填写爱发电订单号');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await Provider.of<PaymentService>(context, listen: false).verifyOrder(orderId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _justStamped = true; // Trigger animation
        });
        
        // 延迟显示成功 Toast，让印章先盖上去
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) SkeuomorphicToast.success(context, result.message);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SkeuomorphicToast.error(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  void _launchSponsor() {
    launchUrl(Uri.parse("https://afdian.com/a/lingshichat"), mode: LaunchMode.externalApplication);
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
            _buildStep(1, "前往爱发电 App 或网站 (afdian.com)"),
            _buildStep(2, "点击 \"我的\" -> \"我的订单\""),
            _buildStep(3, "找到您赞助的那笔订单"),
            _buildStep(4, "复制 【订单号】 (以 202... 开头)"),
            const SizedBox(height: 10),
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

  Widget _buildStep(int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
             width: 20, height: 20,
             alignment: Alignment.center,
             decoration: BoxDecoration(
               color: const Color(0xFF8D6E63),
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
    final isPro = context.select<PaymentService, bool>((s) => s.isPro);
    
    // 如果是刚刚激活瞬间，或者已经是 Pro，则显示 Stamp
    final showStamp = isPro || _justStamped;

    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D), // Dark table background
      appBar: AppBar(
        title: Text('会员证书', style: GoogleFonts.notoSerifSc(color: const Color(0xFFE0E0E0))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
      ),
      body: Stack(
        children: [
          // 1. Table texture (simple noise or color)
          
          // 2. The Certificate Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   _buildCertificate(context, showStamp, isPro),
                   const SizedBox(height: 30),
                   if (!isPro) _buildSponsorTicket(),
                ],
              ),
            ),
          ),

          // 3. Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              ),
            ),
            
          // 4. Petal Rain for celebration
          if (_justStamped)
            const Positioned.fill(child: PetalRainWidget(burst: true)),
        ],
      ),
    );
  }

  Widget _buildCertificate(BuildContext context, bool showStamp, bool isPro) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F4E6), // Cream paper
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
        // Border design
        border: Border.all(color: const Color(0xFFD4AF37), width: 4), // Gold border
      ),
      child: Stack(
        children: [
          // Background Pattern (Watermark)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Center(
                child: Icon(Icons.verified_user, size: 200, color: Colors.black),
              ),
            ),
          ),
          
          // Content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Icon(Icons.workspace_premium, size: 48, color: Color(0xFFD4AF37)), // Gold Icon
              const SizedBox(height: 16),
              Text(
                'CERTIFICATE OF\nMEMBERSHIP',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E2723),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PaperWhisper',
                style: GoogleFonts.dancingScript(
                  fontSize: 20,
                  color: const Color(0xFF5D4037),
                ),
              ),
              const Divider(color: Color(0xFFD4AF37), thickness: 2, height: 40),

              // Status Text
              Text(
                isPro ? '此证书证明您是\n纸语尊享会员' : '请输入爱发电订单号\n激活会员资格',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 16,
                  color: const Color(0xFF3E2723),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 30),

              // Input Area (Only if not Pro)
              if (!isPro) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: const Color(0xFF5D4037).withOpacity(0.5), width: 2)),
                  ),
                  child: TextField(
                    controller: _orderController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.courierPrime(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E2723),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Order ID (e.g. 2026...)',
                      hintStyle: GoogleFonts.courierPrime(color: Colors.black26),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showHelpDialog,
                  child: Text(
                    "如何找到我的订单号？",
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      color: const Color(0xFF5D4037).withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Verify Button (Seal Style)
                GestureDetector(
                  onTap: _verifyOrder,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF8D6E63),
                      boxShadow: [
                         BoxShadow(color: Colors.black26, offset: Offset(2,2), blurRadius: 4)
                      ]
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.fingerprint, color: Colors.white, size: 32),
                  ),
                ),
                Text('点击指纹验证', style: TextStyle(fontSize: 10, color: Colors.black38, height: 2)),
              ],

              if (isPro) ...[
                 SizedBox(height: 60), // Space for stamp
                 Text(
                   'Thank you for your support.',
                   style: GoogleFonts.dancingScript(fontSize: 18, color: Colors.black45),
                 ),
              ]
            ],
          ),

          // The Stamp (Overlay on top)
          if (showStamp)
            Positioned.fill(
              child: Center(
                child: StampAnimation(
                  isStamped: true,
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFB71C1C).withOpacity(0.8), width: 5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'APPROVED',
                        style: GoogleFonts.blackOpsOne(
                          fontSize: 40,
                          color: const Color(0xFFB71C1C).withOpacity(0.8),
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSponsorTicket() {
    return GestureDetector(
      onTap: _launchSponsor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF81C784), // Ticket green
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
             BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_activity_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '前往爱发电支持',
              style: GoogleFonts.notoSerifSc(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16
              ),
            ),
          ],
        ),
      ),
    );
  }
}
