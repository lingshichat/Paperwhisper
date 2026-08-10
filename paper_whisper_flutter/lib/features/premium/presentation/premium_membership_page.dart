import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:paper_whisper_flutter/services/analytics_service.dart';
import 'package:paper_whisper_flutter/services/payment_service.dart';
import 'package:paper_whisper_flutter/widgets/skeuomorphic_toast.dart';
import 'package:paper_whisper_flutter/widgets/visual_effects.dart';

import 'widgets/stamp_animation.dart';

class PremiumMembershipPage extends StatefulWidget {
  const PremiumMembershipPage({super.key});

  @override
  State<PremiumMembershipPage> createState() => _PremiumMembershipPageState();
}

class _PremiumMembershipPageState extends State<PremiumMembershipPage> {
  final ScrollController _scrollController = ScrollController();
  bool _justStamped = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleMarkAsSponsor() {
    if (_justStamped) return;

    // Trigger local state update
    Provider.of<PaymentService>(context, listen: false).markAsSponsor();

    // Track Event
    AnalyticsService().trackEvent(
      'action_donate',
      metadata: {'source': 'stamp_click'},
    );

    setState(() {
      _justStamped = true;
    });

    // Sound effect could be added here
    HapticFeedback.heavyImpact();

    // Delayed toast
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        SkeuomorphicToast.success(context, '感谢您的支持，PaperWhisper 因您而更有温度！');
      }
    });
  }

  void _showDonationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DonationBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 监听 PaymentService 中的赞助状态
    final isSponsor = context.select<PaymentService, bool>((s) => s.isSponsor);
    final showStamp = isSponsor || _justStamped;

    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D), // The Desk
      appBar: AppBar(
        title: Text(
          'Developer\'s Letter',
          style: GoogleFonts.cinzel(
            color: const Color(0xFFE0E0E0),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. The Letter Paper
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
                    // --- HEADER ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
                      child: Column(
                        children: [
                          Icon(
                            isSponsor ? Icons.favorite : Icons.favorite_border,
                            size: 36,
                            color: const Color(0xFFB71C1C),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "A LETTER FROM\nPAPERWHISPER",
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
                            "你好呀，这里是纸语PaperWhisper的开发者！\n\n首先，感谢你能体验我们的软件，愿意触及这个拟物风日记本子~\n我们致力于软件整体交互的精致与美观，在此基础上不断完善现有功能，目前已经到达了一个可用的阶段！\n\n但是随着开发成本的上涨还有应用分发模式的限制，我们需要一份能够自给自足的方式，来支持软件的开发与维护。\n\n由于体量太小我们没有办法接入相关的支付平台，这也是做独立开发的限制，所以我们移除了在开发过程中原有的功能限制而转为打赏模式，让你可以不受打扰的在这个纸语的小世界尽情书写~\n\n如果有条件的话可以请我喝杯咖啡或者加根鸡腿，这会对于我们的开发运营工作有极大的助力~\n当然，使用软件本身这个行为就是对我们最大的支持了~\n\n感谢你能使用纸语PaperWhisper，我们会把这个记录的小世界打磨的更加精彩~",
                            style: GoogleFonts.notoSerifSc(
                              fontSize: 14,
                              color: const Color(0xFF5D4037),
                              height: 1.8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Divider(color: Color(0xFFD7CCC8), thickness: 1),
                    ),

                    // --- DONATION OPTIONS ---
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "支持开发者 (Voluntary Support)",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSerifSc(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Button: Donate
                          GestureDetector(
                            onTap: _showDonationSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8D6E63),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.coffee,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "请我喝杯咖啡 / 加个鸡腿",
                                    style: GoogleFonts.notoSerifSc(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- FOOTER / STAMP AREA ---
                    Container(
                      width: double.infinity,
                      color: const Color(
                        0xFFF0EAE0,
                      ), // Slightly darker footer area
                      padding: const EdgeInsets.all(32),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                "PaperWhisper Team",
                                style: GoogleFonts.dancingScript(
                                  fontSize: 24,
                                  color: const Color(0xFF3E2723),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (!showStamp)
                                GestureDetector(
                                  onTap: _handleMarkAsSponsor,
                                  child: Column(
                                    children: [
                                      Text(
                                        "我已支持 · 点亮勋章",
                                        style: GoogleFonts.notoSerifSc(
                                          fontSize: 12,
                                          color: const Color(0xFFB71C1C),
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      Text(
                                        "Click here if you supported",
                                        style: GoogleFonts.cinzel(
                                          fontSize: 10,
                                          color: const Color(
                                            0xFFB71C1C,
                                          ).withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Text(
                                  "THANK YOU",
                                  style: GoogleFonts.cinzel(
                                    fontSize: 12,
                                    color: const Color(
                                      0xFF3E2723,
                                    ).withValues(alpha: 0.5),
                                    letterSpacing: 2,
                                  ),
                                ),
                            ],
                          ),

                          // The Stamp
                          if (showStamp)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Transform.translate(
                                  offset: const Offset(0, -10),
                                  child: Transform.rotate(
                                    angle: -0.2,
                                    child: StampAnimation(
                                      isStamped: true,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(
                                              0xFFB71C1C,
                                            ).withValues(alpha: 0.8),
                                            width: 4,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'SPONSORED',
                                          style: GoogleFonts.blackOpsOne(
                                            fontSize: 32,
                                            color: const Color(
                                              0xFFB71C1C,
                                            ).withValues(alpha: 0.8),
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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

          // 2. Petal Rain
          if (_justStamped)
            const Positioned.fill(child: PetalRainWidget(burst: true)),
        ],
      ),
    );
  }
}

class _DonationBottomSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F4E6), // Paper color
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black26)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "选择支持方式",
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Select Payment Method",
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(fontSize: 12, color: Colors.black38),
          ),
          const SizedBox(height: 32),

          // Alipay
          _buildOption(
            context,
            icon: Icons.qr_code,
            color: const Color(0xFF1677FF),
            label: "支付宝 (Alipay)",
            desc: "推荐 · 直接唤起支付宝",
            onTap: () {
              Navigator.pop(context);
              Provider.of<PaymentService>(
                context,
                listen: false,
              ).donateViaAlipay();
            },
          ),

          const SizedBox(height: 16),

          // WeChat
          _buildOption(
            context,
            icon: Icons.chat_bubble_outline,
            color: const Color(0xFF07C160),
            label: "微信支付 (WeChat)",
            desc: "保存二维码 -> 打开微信扫一扫",
            onTap: () async {
              Navigator.pop(context); // Close sheet first
              try {
                final msg = await Provider.of<PaymentService>(
                  context,
                  listen: false,
                ).donateViaWeChat();
                if (context.mounted) {
                  SkeuomorphicToast.success(context, msg);
                }
              } catch (e) {
                if (context.mounted) {
                  SkeuomorphicToast.error(
                    context,
                    e.toString().replaceAll("Exception: ", ""),
                  );
                }
              }
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E2723),
                    ),
                  ),
                  Text(
                    desc,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
