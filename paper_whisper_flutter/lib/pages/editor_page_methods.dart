  Widget _buildContentSliver(Color textColor, String theme) {
    if (_isEditing) {
      return SliverToBoxAdapter(
        child: _buildEditorField(textColor, theme),
      );
    } else {
      // Split content into lines for performance
      final lines = _contentController.text.split('\n');
      // If empty, show at least one empty line
      if (lines.isEmpty) lines.add('');
      
      // Calculate line height based on style
      const double fontSize = 16.0;
      const double heightFactor = 1.8;
      const double lineHeight = fontSize * heightFactor;

      final style = GoogleFonts.notoSerifSc(
        fontSize: fontSize,
        height: heightFactor,
        color: textColor,
      );

      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final line = lines[index];
            return CustomPaint(
              foregroundPainter: LinedPaperPainter(
                lineColor: AppTheme.getLineColor(theme),
                lineHeight: lineHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16), // Match Header padding
                child: Text(
                  line.isEmpty ? ' ' : line, // Ensure empty lines have height
                  style: style,
                  strutStyle: StrutStyle(
                     fontSize: fontSize,
                     height: heightFactor,
                     forceStrutHeight: true,
                  ),
                ),
              ),
            );
          },
          childCount: lines.length,
        ),
      );
    }
  }

  Widget _buildEditorField(Color textColor, String theme) {
     final style = GoogleFonts.notoSerifSc(
          fontSize: 16,
          height: 1.8,
          color: textColor,
      );
      
     return CustomPaint(
        foregroundPainter: LinedPaperPainter(
          lineColor: AppTheme.getLineColor(theme),
          lineHeight: 16 * 1.8,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _contentController,
            focusNode: _focusNode,
            maxLines: null,
            style: style,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            cursorColor: textColor,
          ),
        ),
      );
  }
  
  Widget _buildFooter(Color textColor, Color secondaryColor) {
     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
       child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_contentController.text.length} 字',
              style: _metaStyle(secondaryColor),
            ),
            if (_isEditing)
               TextButton.icon(
                 onPressed: _save,
                 icon: Icon(Icons.check, size: 16, color: textColor),
                 label: Text('完成', style: _metaStyle(textColor)),
               )
          ],
       ),
     );
  }
