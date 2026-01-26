import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';

class SkeuomorphicSearchBar extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autoFocus;

  const SkeuomorphicSearchBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = '搜索记忆碎片...',
    this.autoFocus = false,
  });

  @override
  State<SkeuomorphicSearchBar> createState() => _SkeuomorphicSearchBarState();
}

class _SkeuomorphicSearchBarState extends State<SkeuomorphicSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SkeuomorphicSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<SettingsProvider>(context).currentTheme;

    // Theme Configuration
    final themeConfig = AppTheme.getSearchTheme(theme);
    
    Color bgColor = themeConfig.isNotEmpty ? themeConfig['bgColor'] : (theme == AppTheme.themeSeaFlower ? const Color(0xFFF8BBD0).withOpacity(0.3) : (theme == AppTheme.themeMidnight ? const Color(0xFF010409) : (theme == AppTheme.themeAmberLens ? const Color(0xFF1E1E1E) : const Color(0xFF2D1E1B))));
    Color textColor = themeConfig.isNotEmpty ? themeConfig['textColor'] : (theme == AppTheme.themeSeaFlower ? const Color(0xFF880E4F) : (theme == AppTheme.themeMidnight ? const Color(0xFFc9d1d9) : (theme == AppTheme.themeAmberLens ? const Color(0xFFE0E0E0) : const Color(0xFFD7CCC8))));
    Color hintColor = themeConfig.isNotEmpty ? themeConfig['hintColor'] : (theme == AppTheme.themeSeaFlower ? const Color(0xFFAD1457).withOpacity(0.5) : (theme == AppTheme.themeMidnight ? const Color(0xFF8b949e) : (theme == AppTheme.themeAmberLens ? const Color(0xFF757575) : const Color(0xFFA1887F))));
    Color iconColor = themeConfig.isNotEmpty ? themeConfig['iconColor'] : (theme == AppTheme.themeSeaFlower ? const Color(0xFF880E4F) : (theme == AppTheme.themeMidnight ? const Color(0xFF7986cb) : (theme == AppTheme.themeAmberLens ? const Color(0xFFFFB74D) : const Color(0xFFD7CCC8))));
    Border? border = themeConfig.isNotEmpty ? themeConfig['border'] : (theme == AppTheme.themeSeaFlower ? Border.all(color: Colors.white.withOpacity(0.4), width: 1) : (theme == AppTheme.themeMidnight ? Border.all(color: Colors.white10) : (theme == AppTheme.themeAmberLens ? Border.all(color: Colors.black, width: 1) : Border.all(color: Colors.black26))));

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Stack(
        alignment: Alignment.centerLeft, // Start centering vertically
        children: [
          // Simulated Inner Shadow (Top & Left)
          if (theme != AppTheme.themeSeaFlower) 
            Positioned(
              left: 0, top: 0, right: 0, height: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: theme == AppTheme.themeAfterRain 
                        ? [const Color(0xFF0288D1).withValues(alpha: 0.15), Colors.transparent] // Blue shadow for After Rain
                        : [Colors.black.withValues(alpha: 0.2), Colors.transparent],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            ),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Ensure children are centered vertically
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlignVertical: TextAlignVertical.center, 
                  style: GoogleFonts.notoSerifSc(
                    color: textColor,
                    fontSize: 15,
                    height: 1.0, // Reset height to normal or 1.0 for better centering with textAlignVertical
                  ),
                  cursorColor: iconColor,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: GoogleFonts.notoSerifSc(
                      color: hintColor,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      height: 1.0,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    // Use a small vertical padding to help centering if font metrics are odd, 
                    // but with alignment.centerLeft on Stack and CrossAlign.center on Row, it should be good.
                    contentPadding: const EdgeInsets.symmetric(vertical: 8), 
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.close, color: hintColor, size: 18),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
