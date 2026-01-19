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
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final PageController _pageController = PageController(viewportFraction: 0.85);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Access settings for theme
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow background to extend behind AppBar
      appBar: AppBar(
        title: Text(
          '我的书籍', 
          style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent, 
        // Ensure icon color adapts to theme if needed, or stick to default themes
      ),
      body: Stack(
        children: [
          // 1. Background (Syncs with Home Page)
          Container(decoration: AppTheme.getBackground(theme)),
          
          // 2. Visual Effects
          if (theme == AppTheme.themeSeaFlower) const PetalRainWidget(),
          if (theme == AppTheme.themeMidnight) const StarrySkyWidget(),
          
          // 3. Carousel Content
          Consumer<DiaryProvider>(
            builder: (context, provider, child) {
              final grouped = provider.getEntriesGroupedByYearMonth();
              final years = grouped.keys.toList();
              
              final currentYear = DateTime.now().year;
              if (!years.contains(currentYear)) {
                 years.insert(0, currentYear);
              }

              return PageView.builder(
                controller: _pageController,
                itemCount: years.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final year = years[index];
                  final title = provider.getBookTitle(year);
                  final subtitle = provider.getBookSubtitle(year);
                  final coverPath = provider.getBookCoverPath(year);
                  
                  return Center(
                    child: AspectRatio(
                      aspectRatio: 0.7, // Pleasant book/card ratio
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                        child: Hero(
                          tag: 'book_cover_$year',
                          child: SkeuomorphicBook(
                            year: year,
                            title: title,
                            subtitle: subtitle,
                            coverImagePath: coverPath,
                            onTap: () {
                               // First, pop until we're back to the root DiaryListPage
                               Navigator.popUntil(context, (route) => route.isFirst);
                               // Then push the directory
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
          ),
        ],
      ),
    );
  }

  void _showEditTitleDialog(BuildContext context, DiaryProvider provider, int year, String currentTitle, String currentSubtitle) {
    final titleController = TextEditingController(text: currentTitle);
    final subtitleController = TextEditingController(text: currentSubtitle);
    
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
               style: const TextStyle(color: Colors.black87), // Ensure dark text
               decoration: const InputDecoration(
                 labelText: '主标题 (默认为"你的专属故事")',
                 hintText: '例如：我的故事',
                 labelStyle: TextStyle(color: Colors.black87),
                 hintStyle: TextStyle(color: Colors.black38),
                 enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                 focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black54, width: 2)),
                 border: OutlineInputBorder(),
               ),
             ),
             const SizedBox(height: 16),
             TextField(
               controller: subtitleController,
               style: const TextStyle(color: Colors.black87), // Ensure dark text
               decoration: const InputDecoration(
                 labelText: '副标题',
                 hintText: '例如：2026年',
                 labelStyle: TextStyle(color: Colors.black87),
                 hintStyle: TextStyle(color: Colors.black38),
                 enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
                 focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black54, width: 2)),
                 border: OutlineInputBorder(),
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


