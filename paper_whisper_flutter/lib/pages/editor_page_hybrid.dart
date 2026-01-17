  Widget _buildBrandingFooter(Color secondaryColor) {
      return Center(
        child: Column(
          children: [
            if (_isEditing) ...[
               TextButton.icon(
                 onPressed: _save,
                 icon: Icon(Icons.check, size: 16, color: secondaryColor),
                 label: Text('完成', style: _metaStyle(secondaryColor)),
               ),
               const SizedBox(height: 20),
            ],
            Text(
              'CREATED WITH',
              style: GoogleFonts.courierPrime(
                 fontSize: 10, 
                 color: secondaryColor.withValues(alpha: 0.4),
                 letterSpacing: 2
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '纸语 PaperWhisper',
              style: GoogleFonts.notoSerifSc(
                 fontSize: 12,
                 color: secondaryColor.withValues(alpha: 0.6),
                 fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 10), // Bottom padding
          ],
        ),
      );
  }

  Widget _buildAdaptiveContent(Color textColor, Color secondaryColor, String theme) {
      // Threshold for switching to performance mode
      // ~200 lines or ~5000 chars
      bool usePerformanceMode = _contentController.text.length > 3000; 

      if (usePerformanceMode) {
         // --- Performance Mode (Slivers) ---
         return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0), // Full height for long text
              child: RepaintBoundary(
                key: _sheetKey,
                child: PaperSheetWidget(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildHeader(textColor, secondaryColor),
                        ),
                      ),
                      SliverToBoxAdapter(
                           child: Padding(
                             padding: const EdgeInsets.only(bottom: 30),
                             child: Center(
                               child: Container(
                                 width: 60,
                                 height: 2, 
                                 color: (theme == AppTheme.themeSeaFlower
                                     ? const Color(0xFFEC407A) 
                                     : (theme == AppTheme.themeAmberLens ? const Color(0xFFFF9800) : (theme == AppTheme.themeMidnight ? const Color(0xFF7986cb) : const Color(0xFFC0392B)))).withValues(alpha: 0.5),
                               ),
                             ),
                           ),
                        ),
                      _buildContentSliver(textColor, theme),
                      SliverToBoxAdapter(child: const SizedBox(height: 60)),
                      SliverToBoxAdapter(
                         child: _buildBrandingFooter(secondaryColor),
                      ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                    ],
                  ),
                ),
              ),
            ),
         );
      } else {
         // --- Standard Mode (SingleChildScrollView) ---
         // Preserves the "Floating Card" look for shorter entries
         return Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 50), // Bottom padding for "floating" look
              child: RepaintBoundary(
                key: _sheetKey,
                child: PaperSheetWidget(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                       _buildHeader(textColor, secondaryColor),
                       const SizedBox(height: 30),
                       Center(
                         child: Container(
                           width: 60,
                           height: 2, 
                           color: (theme == AppTheme.themeSeaFlower
                               ? const Color(0xFFEC407A) 
                               : (theme == AppTheme.themeAmberLens ? const Color(0xFFFF9800) : (theme == AppTheme.themeMidnight ? const Color(0xFF7986cb) : const Color(0xFFC0392B)))).withValues(alpha: 0.5),
                         ),
                       ),
                       const SizedBox(height: 30),
                       // Standard Content Area (TextField/Text)
                       _buildContentArea(textColor, theme),
                       const SizedBox(height: 60),
                       _buildBrandingFooter(secondaryColor),
                    ],
                  ),
                ),
              ),
            ),
         );
      }
  }
