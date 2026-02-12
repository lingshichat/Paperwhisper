import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/diary_provider.dart';
import '../providers/settings_provider.dart';
import '../config/app_theme.dart';
import '../widgets/visual_effects.dart';
import '../widgets/skeuomorphic_book.dart';
import '../widgets/smooth_cover_page_route.dart'; // SmoothCoverPageRoute
import 'book_directory_page.dart';
import '../widgets/skeuomorphic_dialog.dart';

class BookshelfPage extends StatefulWidget {
  final int? initialYear;
  const BookshelfPage({super.key, this.initialYear});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  PageController? _pageController;
  int _currentPage = 0; // Track current page to restore position on resize

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Access settings for theme
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text(
          '我的书籍', 
          style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent, 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Background (Syncs with Home Page)
          // Container(decoration: AppTheme.getBackground(theme)), // GLOBALIZED
          
          // 2. Visual Effects
          // if (theme == AppTheme.themeSeaFlower) const PetalRainWidget(), // GLOBALIZED
          // if (theme == AppTheme.themeMidnight) const StarrySkyWidget(), // GLOBALIZED
          
          // 3. Carousel Content with Responsive Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double height = constraints.maxHeight;
              
              // Responsive Logic
              // 1. Width Base: 85% of screen width
              double targetBookWidth = width * 0.85;
              
              // 2. Max Width Constraint: 420px (Prevent oversized books on desktop/large tablets)
              if (targetBookWidth > 420) {
                 targetBookWidth = 420;
              }
              
              // 3. Height Constraint: Ensure it fits vertically
              // Book Ratio = 0.7 (Width / Height) => Height = Width / 0.7
              // We want Book Height <= height * 0.8 (Leave 20% vertical buffer)
              // So: Width / 0.7 <= height * 0.8  =>  Width <= height * 0.8 * 0.7
              final double maxHeightBasedWidth = height * 0.8 * 0.7;
              if (targetBookWidth > maxHeightBasedWidth) {
                 targetBookWidth = maxHeightBasedWidth;
              }
              
              // Calculate viewport fraction
              // We add a small margin (e.g. 1.1x) to allow some spacing between items
              double fraction = (targetBookWidth * 1.1) / width;
              // Clamp fraction to be safe
              fraction = fraction.clamp(0.2, 0.9);
              
              // Re-initialize controller if fraction changes significantly
              if (_pageController == null || (_pageController!.viewportFraction - fraction).abs() > 0.01) {
                 // Defer controller creation to Consumer if dependent on data, 
                 // but we can start it here if we know the page index.
                 // Actually, we need the list of years to know the index.
                 // So we'll delay controller creation until inside Consumer.
              }

              return Consumer<DiaryProvider>(
                builder: (context, provider, child) {
                  final grouped = provider.getEntriesGroupedByYearMonth();
                  final years = grouped.keys.toList();
                  
                  final currentYear = DateTime.now().year;
                  if (!years.contains(currentYear)) {
                     years.add(currentYear);
                  }
                  
                  // Sort Ascending (Past -> Future)
                  years.sort();

                  // Find initial index
                  // Use widget.initialYear if provided, otherwise default logic
                  int targetYear = widget.initialYear ?? currentYear;
                  int initialIndex = years.indexOf(targetYear);
                  // If specified year not found, fallback to current year, then last year
                  if (initialIndex == -1) {
                     targetYear = currentYear;
                     initialIndex = years.indexOf(currentYear);
                  }
                  if (initialIndex == -1) initialIndex = years.length - 1;
                  
                  // Initialize PageController only once or if viewport fraction changes
                  if (_pageController == null || (_pageController!.viewportFraction - fraction).abs() > 0.01) {
                     _currentPage = initialIndex;
                     _pageController?.dispose();
                     _pageController = PageController(viewportFraction: fraction, initialPage: _currentPage);
                  }

                  return PageView.builder(
                    controller: _pageController,
                    itemCount: years.length,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      _currentPage = index;
                    },
                    itemBuilder: (context, index) {
                      final year = years[index];
                      final title = provider.getBookTitle(year);
                      final subtitle = provider.getBookSubtitle(year);
                      final coverPath = provider.getBookCoverPath(year);
                      
                      return Center(
                        child: SizedBox(
                          width: targetBookWidth,
                          child: AspectRatio(
                            aspectRatio: 0.7, // Pleasant book/card ratio
                            child: Hero(
                              tag: 'book_cover_$year',
                              child: SkeuomorphicBook(
                                year: year,
                                title: title,
                                subtitle: subtitle,
                                coverImagePath: coverPath,
                                onTap: () {
                                   Navigator.popUntil(context, (route) => route.isFirst);
                                   Navigator.push(
                                     context,
                                     SmoothCoverPageRoute(page: BookDirectoryPage(year: year)),
                                   );
                                },
                                onMenuAction: (action) async {
                                  switch (action) {
                                    case 'edit_cover':
                                      final ImagePicker picker = ImagePicker();
                                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                      if (image != null) {
                                         provider.setBookInfo(year, coverPath: image.path);
                                      }
                                      break;
                                    case 'edit_title':
                                      _showEditTitleDialog(context, provider, year, title, subtitle);
                                      break;
                                    case 'reset_cover':
                                      provider.resetBookInfo(year, cover: true);
                                      break;
                                    case 'reset_title':
                                      provider.resetBookInfo(year, title: true);
                                      break;
                                    case 'reset_subtitle':
                                      provider.resetBookInfo(year, subtitle: true);
                                      break;
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }
          ),
        ],
      ),
    );
  }

  void _showEditTitleDialog(BuildContext context, DiaryProvider provider, int year, String currentTitle, String currentSubtitle) {
    final titleController = TextEditingController(text: currentTitle);
    final subtitleController = TextEditingController(text: currentSubtitle);
    
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final dialogTheme = AppTheme.getDialogInputTheme(theme);
    final textColor = dialogTheme['textColor']!;
    final hintColor = dialogTheme['hintColor']!;
    final borderColor = dialogTheme['borderColor']!;
    final focusedBorderColor = dialogTheme['focusedBorderColor']!;

    showDialog(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: '编辑标题信息',
        headerIcon: Icons.edit_note,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const SizedBox(height: 16),
             TextField(
               controller: titleController,
               style: TextStyle(color: textColor), 
               decoration: InputDecoration(
                 labelText: '主标题 (默认为"你的专属故事")',
                 hintText: '例如：我的故事',
                 labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                 hintStyle: TextStyle(color: hintColor),
                 enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                 focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: focusedBorderColor, width: 2)),
                 border: const OutlineInputBorder(),
               ),
             ),
             const SizedBox(height: 16),
             TextField(
               controller: subtitleController,
               style: TextStyle(color: textColor), 
               decoration: InputDecoration(
                 labelText: '副标题',
                 hintText: '例如：2026年',
                 labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                 hintStyle: TextStyle(color: hintColor),
                 enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                 focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: focusedBorderColor, width: 2)),
                 border: const OutlineInputBorder(),
               ),
             ),
             const SizedBox(height: 8),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '取消',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          SkeuomorphicDialogButton(
            label: '保存',
            isPrimary: true,
            onPressed: () {
              provider.setBookInfo(
                year, 
                title: titleController.text, 
                subtitle: subtitleController.text,
              );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}


