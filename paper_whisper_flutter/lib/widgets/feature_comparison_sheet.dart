import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeatureComparisonSheet extends StatefulWidget {
  final bool isEmbedded;

  const FeatureComparisonSheet({super.key, this.isEmbedded = false});

  @override
  State<FeatureComparisonSheet> createState() => _FeatureComparisonSheetState();
}

class _FeatureComparisonSheetState extends State<FeatureComparisonSheet> {
  bool _isExpanded = false;

  // Fixed column widths to support horizontal scrolling
  final double col1Width = 130;
  final double colWidth = 110;

  @override
  Widget build(BuildContext context) {
    // Embedded mode: Transparent, no border, blend into paper
    // Standalone mode: Card style
    final decoration = widget.isEmbedded
        ? const BoxDecoration(color: Colors.transparent)
        : BoxDecoration(
            color: const Color(0xFFFDFBF7), // Off-white specs paper
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
            border: Border.all(color: const Color(0xFFD7CCC8), width: 0.5),
          );

    final headerDecoration = widget.isEmbedded
        ? BoxDecoration(
             border: Border(bottom: BorderSide(color: _isExpanded ? const Color(0xFF8D6E63).withOpacity(0.3) : Colors.transparent, width: 0.5)),
          )
        : BoxDecoration(
            border: Border(bottom: BorderSide(color: _isExpanded ? const Color(0xFFD7CCC8) : Colors.transparent, width: 0.5)),
            color: const Color(0xFFFFFDE7).withOpacity(0.3),
          );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      margin: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.only(top: 10, bottom: 20),
      decoration: decoration,
      child: Column(
        children: [
          // Header (Clickable)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: headerDecoration,
                child: Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: const Color(0xFF8D6E63),
                      size: 20
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "权益对比清单 (Specifications)",
                      style: GoogleFonts.notoSerifSc(
                        color: const Color(0xFF5D4037),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    // In embedded mode, maybe show a small icon or nothing
                    if (!widget.isEmbedded)
                      const Icon(Icons.attachment, color: Colors.black12, size: 16),
                  ],
                ),
              ),
            ),
          ),

          // Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.topCenter,
            curve: Curves.easeInOut,
            child: _isExpanded
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _buildHeaderRow(),
                         Container(
                           width: col1Width + colWidth * 3, 
                           height: 1.5, 
                           color: const Color(0xFF8D6E63),
                           margin: const EdgeInsets.symmetric(vertical: 12),
                         ),
                         
                         // Strictly following the table in commercial_strategy.md
                         _buildRow("专注写作", "✅ 无限篇数", "✅ 无限", "✅ 无限"),
                         _buildRow("目录标题自定义", "✅ 支持", "✅ 支持", "✅ 支持"),
                         _buildRow("书籍封面/标题自定义", "✅ 支持", "✅ 支持", "✅ 支持"),
                         _buildRow("安全锁", "✅ 数字密码", "✅ 指纹 + 密码", "✅ 指纹 + 密码"),
                         _buildRow("拟物主题", "✅ 4款精选", "✅ 4款+2款专属", "✅ 所有+月更"),
                         
                         _buildDivider(),
                         
                         _buildRow("随心记 (Moments)", "每日 3 条", "✅ 无限创作", "✅ 无限创作"),
                         _buildRow("随心记转长文", "✅ 一键转换", "✅ 一键转换", "✅ 一键转换"),
                         _buildRow("标签管理", "✅ 手动", "✅ 手动", "✅ 手动+AI自动"),
                         _buildRow("语音转文字", "- (仅录音)", "- (仅录音)", "✅ AI自动转写"),
                         
                         _buildDivider(),

                         _buildRow("WebDAV/S3 同步", "✅ 本地+WebDAV", "✅ WebDAV+S3", "✅ WebDAV+S3"),
                         _buildRow("高级个性化", "- (默认)", "✅ (Coming Soon)", "✅ (Coming Soon)"),
                         
                         _buildDivider(),

                         _buildRow("AI 智能服务", "", "", ""),
                         _buildRow("  ├─ 智能分类", "-", "-", "✅ 自动标签"),
                         _buildRow("  ├─ 情绪分析", "-", "-", "✅ 月度报告"),
                         _buildRow("  ├─ 智能润色", "-", "-", "✅ 文案优化"),
                         
                         _buildRow("官方省心云同步", "-", "-", "✅ 支持(Coming Soon)"),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: col1Width + colWidth * 3, 
      height: 0.5, 
      color: const Color(0xFFD7CCC8),
      margin: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildHeaderRow() {
    return SizedBox(
      width: col1Width + colWidth * 3,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: col1Width, child: Text("功能特性", style: _headerStyle())), 
          SizedBox(width: colWidth, child: Center(child: Text("免费版\n(Free)", textAlign: TextAlign.center, style: _headerStyle()))),
          SizedBox(
            width: colWidth, 
            child: Center(
              child: Text("功能特性赞助\n(买断)", textAlign: TextAlign.center, style: _headerStyle().copyWith(color: const Color(0xFFD84315)))
            )
          ),
          SizedBox(
            width: colWidth, 
            child: Center(
              child: Text("订阅赞助\n(订阅)", textAlign: TextAlign.center, style: _headerStyle().copyWith(color: const Color(0xFF1565C0)))
            )
          ), 
        ],
      ),
    );
  }

  Widget _buildRow(String label, String v1, String v2, String v3) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: col1Width, 
            child: Text(label, style: GoogleFonts.notoSerifSc(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4E342E)))
          ),
          SizedBox(
            width: colWidth, 
            child: Text(v1, textAlign: TextAlign.center, style: _valueStyle())
          ),
          SizedBox(
            width: colWidth, 
            child: Text(v2, textAlign: TextAlign.center, style: _valueStyle().copyWith(fontWeight: FontWeight.bold))
          ),
          SizedBox(
            width: colWidth, 
            child: Text(v3, textAlign: TextAlign.center, style: _valueStyle().copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey[800]))
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.notoSerifSc(
      fontSize: 11,
      fontWeight: FontWeight.bold, 
      color: Colors.black45,
      height: 1.1
    );
  }

  TextStyle _valueStyle() {
    return GoogleFonts.notoSerifSc(
      fontSize: 10,
      color: const Color(0xFF5D4037),
      height: 1.2,
    );
  }
}
