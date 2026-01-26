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

class PremiumMembershipPage extends StatefulWidget {
  const PremiumMembershipPage({super.key});

  @override
  State<PremiumMembershipPage> createState() => _PremiumMembershipPageState();
}

class _PremiumMembershipPageState extends State<PremiumMembershipPage> {
  final TextEditingController _orderController = TextEditingController();
  bool _isLoading = false;
  bool _justStamped = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _inputKey = GlobalKey();

  @override
  void dispose() {
    _orderController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToInput() {
     if (_inputKey.currentContext != null) {
       Scrollable.ensureVisible(
         _inputKey.currentContext!, 
         duration: const Duration(milliseconds: 600), 
         curve: Curves.easeInOutCubic
       );
       // Optional: Focus the text field
     }
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
          _justStamped = true;
        });
        
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
    final isPro = context.select<PaymentService, bool>((s) => s.isPro);
    final showStamp = isPro || _justStamped;

    return Scaffold(
      backgroundColor: const Color(0xFF2D2D2D), // The Desk
      appBar: AppBar(
        title: Text(
          'Royal Invitation', 
          style: GoogleFonts.cinzel(color: const Color(0xFFE0E0E0), fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. The Desk Texture (Optional subtle noise could go here, for now solid color)
          
          // 2. The Letter Paper
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
                              "你好呀，这里是纸语PaperWhisper的开发者！\n\n首先，感谢你能体验我们的软件，愿意触及这个拟物风日记本子~\n我们致力于软件整体交互的精致与美观，在此基础上不断完善现有功能，目前已经到达了一个可用的阶段！\n\n但是随着开发成本的上涨还有应用分发模式的限制，我们需要一份能够自给自足的方式，来支持软件的开发与维护\n\n所以我们处于蛮纠结的情绪下为你呈递上这份只属于纸语PaperWhisper的赞助邀请函\n为了感谢你的支持，我们准备了七日全功能解锁的试用期，希望你能喜欢💓",
                              style: GoogleFonts.notoSerifSc(
                                fontSize: 13,
                                color: const Color(0xFF5D4037),
                                height: 1.6,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Divider(color: Color(0xFFD7CCC8), thickness: 1),
                    ),

                    // --- OPTIONS ---
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("您的专属权益方案", style: GoogleFonts.notoSerifSc(fontSize: 14, color: Colors.black38)),
                          const SizedBox(height: 16),
                          
                          // Method 0: Trial (The Hook)
                          _buildTrialOption(isPro),

                          const SizedBox(height: 24),

                          // Option 1: Lifetime (The Ticket)
                          _buildLifetimeTicket(isPro),

                          const SizedBox(height: 24),

                          // Option 2: Subscription
                          _buildSubscriptionOption(),

                          const SizedBox(height: 24),

                          // Note
                          Text(
                            "* 当前为早鸟特惠阶段，支持一次性买断终身权益。随着 AI 等高级功能的加入，未来可能会调整价格策略，但您目前拥有的权益将永久保留。",
                            style: GoogleFonts.notoSerifSc(
                              fontSize: 11,
                              color: const Color(0xFFA1887F),
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- SPECS ---
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: FeatureComparisonSheet(isEmbedded: true),
                    ),
                    
                    const SizedBox(height: 20),

                    // --- FOOTER / CERTIFICATE ---
                    _buildCertificateFooter(context, showStamp, isPro),
                  ],
                ),
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

          // 4. Petal Rain
          if (_justStamped)
            const Positioned.fill(child: PetalRainWidget(burst: true)),
        ],
      ),
    );
  }

  Widget _buildLifetimeTicket(bool isPro) {
    // Real Lifetime Product URL provided by user
    const String lifetimeUrl = "https://afdian.com/item/f723bc80fa8811f0bea05254001e7c00"; 

    return GestureDetector(
      onTap: isPro ? null : () => _launchSponsor(url: lifetimeUrl),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFECB3).withOpacity(0.3), // Pale gold bg
          border: Border.all(color: isPro ? const Color(0xFF2E7D32) : const Color(0xFFD4AF37), width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        "功能特性赞助 · 终身版",
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold, 
                          color: const Color(0xFF3E2723)
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: isPro ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C)),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          isPro ? "ACTIVATED" : "EARLY BIRD",
                          style: GoogleFonts.oswald(
                            fontSize: 10, 
                            color: isPro ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C), 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "无限随心记 / WebDAV同步 / 指纹解锁 / 专属信纸",
                    style: GoogleFonts.notoSerifSc(fontSize: 12, color: const Color(0xFF5D4037)),
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "¥38",
                    style: GoogleFonts.cinzel(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: const Color(0xFF3E2723)
                    ),
                  ),
                  Text(
                    "原价 ¥68",
                    style: GoogleFonts.cinzel(
                      fontSize: 11, 
                      decoration: TextDecoration.lineThrough,
                      color: Colors.black26
                    ),
                  ),
                  if (!isPro) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("购买", style: GoogleFonts.notoSerifSc(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 2),
                          const Icon(Icons.open_in_new, size: 9, color: Colors.white),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _scrollToInput,
                      child: Text(
                        "已有订单?激活", 
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 9, 
                          color: const Color(0xFFD4AF37), 
                          decoration: TextDecoration.underline
                        )
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOption() {
    return Consumer<PaymentService>(
      builder: (context, payment, child) {
        final subExpiry = payment.subscriptionExpiry;
        final isActive = payment.isSubscriptionActive;
        
        // Real Monthly Plan URL (Public Link constructed from ID)
        // User provided: 0e639c44f8cc11f0bfaa52540025c377
        const String subscriptionUrl = "https://afdian.com/a/lingshichat?plan_id=0e639c44f8cc11f0bfaa52540025c377";

        return GestureDetector(
          onTap: isActive ? null : () => _launchSponsor(url: subscriptionUrl), // Main action: Go Pay
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFEBE9), // Light grayish brown paper for "Library Card"
              border: Border.all(color: isActive ? const Color(0xFF2E7D32) : const Color(0xFF8D6E63), width: 1.5),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                // Top Header Strip
                 Container(
                   width: double.infinity,
                   padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                   decoration: BoxDecoration(
                     color: isActive ?  const Color(0xFFA5D6A7) : const Color(0xFFA1887F), // Greenish if active, else brown
                     borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                   ),
                   child: Row(
                     children: [
                       Icon(Icons.local_library, size: 16, color: isActive ? const Color(0xFF1B5E20) : Colors.white),
                       const SizedBox(width: 8),
                       Text(
                         "PAPERWHISPER CLUB PASS",
                         style: GoogleFonts.oswald(
                           fontSize: 12,
                           color: isActive ? const Color(0xFF1B5E20) : Colors.white,
                           fontWeight: FontWeight.bold,
                           letterSpacing: 1.5,
                         ),
                       ),
                       const Spacer(),
                       if (isActive)
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                           decoration: BoxDecoration(
                             border: Border.all(color: const Color(0xFF1B5E20)),
                             borderRadius: BorderRadius.circular(2),
                           ),
                           child: const Text("VALID", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                         ),
                     ],
                   ),
                 ),
                 
                 // Content
                 Padding(
                   padding: const EdgeInsets.all(16),
                   child: Row(
                     children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "加入·纸语俱乐部",
                                style: GoogleFonts.notoSerifSc(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  color: const Color(0xFF3E2723)
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "每月一杯咖啡，支持持续创新",
                                style: GoogleFonts.notoSerifSc(fontSize: 12, color: const Color(0xFF5D4037), fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 12),
                              // Features List
                              _buildSubFeatureItem("包含【功能会员】所有权益"),
                              _buildSubFeatureItem("设计师主题与信纸 (持续更新)"),
                              _buildSubFeatureItem("AI 智能分类 & 润色 (即将更新)"),
                              _buildSubFeatureItem("官方省心云同步 (即将更新)"),
                            ],
                          ),
                        ),
                        
                        // Right Side: Price or Status
                        Flexible(
                          flex: 0, // Don't expand, just take needed space
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               if (isActive) ...[
                                 Text(
                                   "有效期至",
                                   style: GoogleFonts.notoSerifSc(fontSize: 10, color: Colors.black38),
                                 ),
                                 const SizedBox(height: 4),
                                 Text(
                                   "${subExpiry!.year}.${subExpiry.month}.${subExpiry.day}",
                                   style: GoogleFonts.courierPrime(
                                     fontSize: 14,
                                     fontWeight: FontWeight.bold, 
                                     color: const Color(0xFF2E7D32)
                                   ),
                                 ),
                                 const SizedBox(height: 8),
                                 const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32), size: 24),
                               ] else ...[
                                 Column(
                                   crossAxisAlignment: CrossAxisAlignment.end,
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Text("月度", style: GoogleFonts.notoSerifSc(fontSize: 10, color: Colors.black38)),
                                     Text("¥6", style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))),
                                     const SizedBox(height: 2),
                                     Text("季度¥15/年度¥50", style: GoogleFonts.notoSerifSc(fontSize: 8, color: Colors.black45)),
                                   ],
                                 ),
                                 const SizedBox(height: 6),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFF8D6E63),
                                     borderRadius: BorderRadius.circular(16),
                                   ),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Text("订阅", style: GoogleFonts.notoSerifSc(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                       const SizedBox(width: 2),
                                       const Icon(Icons.open_in_new, size: 9, color: Colors.white),
                                     ],
                                   ),
                                 ),
                                 const SizedBox(height: 6),
                                 GestureDetector(
                                   onTap: _scrollToInput,
                                   child: Text(
                                     "已有订单?激活", 
                                     style: GoogleFonts.notoSerifSc(
                                       fontSize: 9, 
                                       color: const Color(0xFF8D6E63), 
                                       decoration: TextDecoration.underline
                                     )
                                   ),
                                 ),
                               ]
                            ],
                          ),
                        ),
                     ],
                   ),
                 ),
              ],
            ),
          ),
        );
      }
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
                       '请填写爱发电订单号',
                       textAlign: TextAlign.center,
                       style: GoogleFonts.notoSerifSc(
                         fontSize: 12,
                         color: const Color(0xFF5D4037),
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     const SizedBox(height: 2),
                     Text(
                       'Enter your Afdian Order ID',
                       textAlign: TextAlign.center,
                       style: GoogleFonts.cinzel(
                         fontSize: 9,
                         color: Colors.black38,
                         letterSpacing: 0.6,
                       ),
                     ),
                     const SizedBox(height: 8),
                     Container(
                       key: _inputKey,
                       width: 200,
                       /*decoration: BoxDecoration(
                         border: Border(bottom: BorderSide(color: Color(0xFF5D4037), width: 1.5))
                       ),*/
                       child: TextField(
                          controller: _orderController,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.courierPrime(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3E2723),
                          ),
                          decoration: InputDecoration(
                            hintText: '202501260000000000',
                            hintStyle: GoogleFonts.cinzel(color: Colors.black12, fontSize: 14),
                            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8D6E63))),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3E2723), width: 2)),
                            isDense: true,
                          ),
                       ),
                     ),
                     const SizedBox(height: 8),
                     GestureDetector(
                        onTap: () {
                           // Try verify
                           _verifyOrder();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '点此签署并核验',
                              style: GoogleFonts.notoSerifSc(
                                fontSize: 11,
                                color: const Color(0xFFB71C1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Tap to sign & verify',
                              style: GoogleFonts.cinzel(
                                fontSize: 9,
                                color: const Color(0xFFB71C1C).withOpacity(0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                     ),
                     const SizedBox(height: 4),
                     GestureDetector(
                       onTap: _showHelpDialog,
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Text(
                             '如何获取订单号？',
                             style: GoogleFonts.notoSerifSc(
                               fontSize: 10,
                               color: Colors.black26,
                               decoration: TextDecoration.underline,
                             ),
                           ),
                           Text(
                             'Where to find it?',
                             style: GoogleFonts.cinzel(
                               fontSize: 9,
                               color: Colors.black26,
                               decoration: TextDecoration.underline,
                               letterSpacing: 0.6,
                             ),
                           ),
                         ],
                       ),
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
