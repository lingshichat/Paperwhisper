import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/hitokoto_service.dart';
import '../config/app_theme.dart';
import '../pages/diary_list_page.dart';
import '../pages/moments_page.dart';
import '../pages/settings_page.dart';
import '../widgets/slide_page_route.dart';
import '../providers/settings_provider.dart';

class SidebarWidget extends StatefulWidget {
  const SidebarWidget({super.key});

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  HitokotoLine? _hitokoto;
  final HitokotoService _hitokotoService = HitokotoService();
  int _tempActiveIndex = -1; // Added for animation override

  @override
  void initState() {
    super.initState();
    _fetchHitokoto();
  }

  Future<void> _fetchHitokoto() async {
    final hitokoto = await _hitokotoService.fetchHitokoto();
    if (mounted) {
      setState(() {
        _hitokoto = hitokoto;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine active route logic
    bool isWriter = context.findAncestorWidgetOfExactType<DiaryListPage>() != null;
    bool isMoments = context.findAncestorWidgetOfExactType<MomentsPage>() != null;
    
    int activeIndex = -1;
    if (isWriter) activeIndex = 0;
    if (isMoments) activeIndex = 1;
    
    // Item Height: Padding(16*2) + Icon(24) = 56. Spacing = 12.
    // Top offsets: 0, 68...
    
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 280, // Default width if not constrained
        decoration: const BoxDecoration(
            color: Color(0xFF2C2C2C),
            image: DecorationImage(
              image: AssetImage('assets/textures/leather_dark.png'),
              fit: BoxFit.cover,
              opacity: 0.5,
            ),
            boxShadow: [
               BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(5, 0))
            ]
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
               // Header
               Padding(
                 padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       "纸语",
                       style: GoogleFonts.notoSerifSc(
                         color: const Color(0xFFD7CCC8),
                         fontSize: 28,
                         fontWeight: FontWeight.bold,
                         shadows: [
                           const Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 4)
                         ]
                       ),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       "PaperWhisper",
                       style: GoogleFonts.playfairDisplay(
                         color: const Color(0xFFA1887F),
                         fontSize: 14,
                         fontStyle: FontStyle.italic,
                       ),
                     ),
                   ],
                 ),
               ),
               
                // Menu Area with Animated Pill
                Stack(
                  children: [
                     // Selection Pill (Hero)
                     // Use _tempActiveIndex if set, otherwise activeIndex
                     if (_tempActiveIndex != -1 || activeIndex != -1)
                       AnimatedPositioned(
                         duration: const Duration(milliseconds: 300),
                         curve: Curves.easeOutBack, // In-page animation (e.g. initial load correction)
                         top: (_tempActiveIndex != -1 ? _tempActiveIndex : activeIndex) * 68.0,
                         left: 16,
                         right: 16,
                         height: 56,
                         child: Hero(
                           tag: 'sidebar_selection_pill',
                           child: Container(
                             decoration: BoxDecoration(
                               color: const Color(0xFF222222),
                               borderRadius: BorderRadius.circular(12),
                                 boxShadow: [
                                   const BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
                                   const BoxShadow(color: Colors.black87, offset: Offset(0, -2), blurRadius: 1) 
                                 ]
                             ),
                           ),
                         ),
                       ),
                       
                     // Menu Items
                     Column(
                       children: [
                          _buildMenuItem(
                            context, 
                            icon: Icons.edit_note, 
                            label: "专注书写", 
                            onTap: () async {
                              bool isDrawer = context.findAncestorWidgetOfExactType<Drawer>() != null;
                               
                              // 1. If currently Writer, just close drawer if mobile?
                              if (isWriter) {
                                if (isDrawer) Navigator.pop(context);
                                return;
                              }
                              
                              // 2. Animate Locally First
                              if (mounted) {
                                setState(() => _tempActiveIndex = 0);
                              }
                              
                              // 3. Wait for animation
                              await Future.delayed(const Duration(milliseconds: 400));
                              
                              // 4. Navigate
                              if (mounted) {
                                 // Close existing drawer? NO, user wants to keep open visually
                                 // But pushReplacement will destroy current page (and drawer).
                                 // We must open new drawer on destination.
                                 
                                 Navigator.pushReplacement(
                                     context, 
                                     PageRouteBuilder(
                                       pageBuilder: (_, __, ___) => const DiaryListPage(autoOpenDrawer: true),
                                       transitionDuration: Duration.zero,
                                       reverseTransitionDuration: Duration.zero,
                                       transitionsBuilder: (_, a, __, c) => c,
                                     )
                                 );
                              }
                            },
                            isActive: (_tempActiveIndex != -1 ? _tempActiveIndex == 0 : isWriter)
                          ),
                          
                          const SizedBox(height: 12),
                          
                          _buildMenuItem(
                            context, 
                            // icon: Icons.camera_alt_outlined, 
                            icon: Icons.photo_library_outlined,
                            label: "随心记", 
                            onTap: () async {
                               bool isDrawer = context.findAncestorWidgetOfExactType<Drawer>() != null;
                               
                               if (isMoments) {
                                 if (isDrawer) Navigator.pop(context);
                                 return;
                               }
                               
                               if (mounted) {
                                 setState(() => _tempActiveIndex = 1);
                               }
                               
                               await Future.delayed(const Duration(milliseconds: 400));
                               
                               if (mounted) {
                                 Navigator.pushReplacement(
                                     context, 
                                     PageRouteBuilder(
                                       pageBuilder: (_, __, ___) => const MomentsPage(autoOpenDrawer: true),
                                       transitionDuration: Duration.zero,
                                       reverseTransitionDuration: Duration.zero,
                                       transitionsBuilder: (_, a, __, c) => c,
                                     )
                                 );
                               }
                            },
                            isActive: (_tempActiveIndex != -1 ? _tempActiveIndex == 1 : isMoments)
                          ),
                       ],
                     ),
                  ],
                ),
               
               const Spacer(),

               // Hitokoto
               Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hitokoto?.hitokoto ?? '正在获取一言...',
                        style: GoogleFonts.notoSerifSc(
                          color: const Color(0xFFBCAAA4),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                      if (_hitokoto != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '—— ${_hitokoto!.from}',
                            style: GoogleFonts.notoSerifSc(
                              color: const Color(0xFF8D6E63),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
               ),
               
               const Divider(color: Colors.white10, height: 1),
               
               // Settings
               Padding(
                 padding: const EdgeInsets.symmetric(vertical: 10),
                 child: _buildMenuItem(
                   context, 
                   icon: Icons.settings_outlined, 
                   label: "设置", 
                   onTap: () {
                      if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                         Navigator.pop(context);
                      }
                      Navigator.push(context, SlidePageRoute(page: const SettingsPage()));
                   },
                   isActive: false
                 ),
               ),
               const SizedBox(height: 10),
            ],
          ),
      ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, bool isActive = false}) {
    // Inner height: 16*2 + 24 = 56
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
               // Background is handled by Stack Pill
               // But we can add transparent debug color if needed
            ),
            child: Hero(
              tag: 'sidebar_item_$label', // Unique tag per item
              child: Material(
                type: MaterialType.transparency,
                child: Row(
                  children: [
                    Icon(icon, color: isActive ? const Color(0xFFFFB74D) : const Color(0xFF9E9E9E), size: 24),
                    const SizedBox(width: 20),
                    Text(
                      label,
                      style: GoogleFonts.notoSerifSc(
                        color: isActive ? const Color(0xFFFFB74D) : const Color(0xFFBDBDBD),
                        fontSize: 16,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        letterSpacing: 1,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
