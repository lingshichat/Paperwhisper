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
    // We'll trust the parent or context presence for highlighting
    bool isWriter = context.findAncestorWidgetOfExactType<DiaryListPage>() != null;
    bool isMoments = context.findAncestorWidgetOfExactType<MomentsPage>() != null;
    
    // Theme logic for Leather texture or simple color
    // For now, hardcoded dark leather vibe as per design
    
    return Container(
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
               
               // Menu Items
               _buildMenuItem(
                 context, 
                 icon: Icons.edit_note, 
                 label: "专注书写", 
                 onTap: () {
                    // Only pop if in Drawer (Mobile)
                    if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                       Navigator.pop(context);
                    }
                    
                    if (!isWriter) {
                      Navigator.pushReplacement(
                          context, 
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const DiaryListPage(),
                            transitionDuration: const Duration(milliseconds: 300),
                            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                          )
                      );
                    }
                 },
                 isActive: isWriter
               ),
               
               const SizedBox(height: 12),
               
               _buildMenuItem(
                 context, 
                 // icon: Icons.camera_alt_outlined, 
                 icon: Icons.photo_library_outlined,
                 label: "随心记", 
                 onTap: () {
                    if (context.findAncestorWidgetOfExactType<Drawer>() != null) {
                       Navigator.pop(context);
                    }
                    
                    if (!isMoments) {
                      Navigator.pushReplacement(
                          context, 
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const MomentsPage(),
                            transitionDuration: const Duration(milliseconds: 300),
                            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                          )
                      );
                    }
                 },
                 isActive: isMoments
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
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive 
                  ? const Color(0xFF222222) // Pressed effect
                  : Colors.transparent, 
              boxShadow: isActive 
                  ? [
                      const BoxShadow(color: Colors.white10, offset: Offset(0, 1), blurRadius: 0),
                      const BoxShadow(color: Colors.black87, offset: Offset(0, -2), blurRadius: 1) // Inner shadow simulation
                    ] 
                  : [],
              border: isActive 
                  ? Border.all(color: Colors.transparent)
                  : Border.all(color: Colors.transparent), // Placeholder
            ),
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
    );
  }
}
