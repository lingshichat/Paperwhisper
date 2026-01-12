import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/moment.dart';
import '../services/moment_service.dart';
import '../widgets/moment_card.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/ruler_date_picker.dart';
import '../widgets/moment_input_widget.dart';
import '../pages/diary_list_page.dart';

class MomentsPage extends StatefulWidget {
  const MomentsPage({super.key});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  final MomentService _momentService = MomentService();
  List<Moment> _allMoments = []; // Cache all
  List<Moment> _filteredMoments = [];
  bool _isLoading = true;
  Directory? _baseDir;
  DateTime _selectedDate = DateTime.now();

  late PageController _pageController;
  late FixedExtentScrollController _rulerController;
  
  final int _dayRange = 3650; 
  late DateTime _startDate;
  
  // Flags to prevent circular sync
  bool _isRulerActive = false;
  bool _isPageActive = false;

  @override
  void initState() {
    super.initState();
    _initDates();
    _initControllers();
    _loadData();
  }
  
  void _initDates() {
    // Same normalization logic as Ruler
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 365 * 5));
    
    // Initial Index
    final selectedNormalized = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day
    );
    int initialIndex = selectedNormalized.difference(_startDate).inDays;
    if (initialIndex < 0) initialIndex = 0;
    
    _pageController = PageController(initialPage: initialIndex);
    _rulerController = FixedExtentScrollController(initialItem: initialIndex);
  }

  void _initControllers() {
    // Sync Ruler -> Page (When user scrolls ruler)
    // Note: ListWheelScrollView physics might fight if we jump too often?
    // Let's us notification listener on Ruler side or just listener on controller?
    // Controller listener doesn't tell us source.
    // RulerDatePicker exposes controller. We need to wrap RulerDatePicker in NotificationListener
    // to detect if user is touching it.
    
    // Actually simpler: In build method, wrap RulerDatePicker with NotificationListener.
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _rulerController.dispose();
    super.dispose();
  }

  // Optimized helper
  List<Moment> _getMomentsForDate(DateTime date) {
    return _allMoments.where((m) {
      return m.createdAt.year == date.year &&
             m.createdAt.month == date.month &&
             m.createdAt.day == date.day;
    }).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _onDateChanged(DateTime date, {bool animate = true}) {
    if (_isSameDay(date, _selectedDate)) return;
    
    setState(() {
      _selectedDate = date;
    });
    
    // If caused by explicit selection (e.g. tap on ruler item not implemented yet but if any), sync page
    if (animate) {
      int index = date.difference(_startDate).inDays;
      if (_pageController.hasClients && _pageController.page?.round() != index) {
        _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      // Ruler auto-syncs via page listener? No, need to sync ruler too if page doesn't move ruler during animation?
      // Page animation will trigger scroll update, which syncs ruler. So just moving page is enough.
    }
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _handleSend(String content, List<XFile> images) async {
    // 1. Save images
    List<String> savedPaths = [];
    for (var img in images) {
      String path = await _momentService.saveImage(File(img.path));
      savedPaths.add(path);
    }
    
    // 2. Create Moment (Force time to be selected date? No, moments are "Now")
    // If user selected yesterday, adding a moment should probably be date of yesterday? 
    // Usually Moments are instantaneous. But for journal app, maybe user wants to backdate?
    // Let's assume write for Current Selected Date, current time.
    
    DateTime timestamp = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      DateTime.now().hour, DateTime.now().minute, DateTime.now().second
    );

    Moment newMoment = Moment.create(
      content: content,
      images: savedPaths,
      // Default weather/mood for quick input? Or random? Or none.
    );
    // Adjust timestamp
    // Moment.create uses DateTime.now(). We should probably allow overriding.
    // Since Moment.create doesn't support custom date in my previous impl, check model.
    // If model has only 'create' factory, I might need to edit it manually or just let it be Now.
    // Let's stick to "Now" for simplicity, or if Moment model allows, set createdAt.
    // Checking previous context... Moment model has createdAt final. 
    // I can't easily change it without refactoring Moment. 
    // But since it's "Suixinji" (Spontaneous), "Now" makes sense. 
    // If user is viewing yesterday and types, does it go to yesterday? 
    // Flomo usually acts as Inbox, always Now.
    // BUT user wants typical journal backdating often.
    // Let's assume "Now" for this iteration to match Flomo behavior unless specified.
    
    await _momentService.saveMoment(newMoment);
    await _loadData(); // visual refresh
    
    // If user is not on Today, maybe jump to Today? Or stay? Stay.
  }

  Future<void> _handleAggregation() async {
    // Show Dialog
    String title = "今日份的日记";
    String? result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String inputVal = "";
        return AlertDialog(
          title: Text('生成长文日记', style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('将今天的记录汇聚成篇，存入专注书写模块。', style: GoogleFonts.notoSerifSc(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '为日记起个名字',
                  hintText: '默认: 今日份的日记',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => inputVal = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('取消')
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, inputVal.isEmpty ? title : inputVal),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63)),
              child: const Text('生成', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }
    );

    if (result != null) {
      try {
        // Reuse service logic but we need to pass title!
        // The service method 'exportDailySummary' hardcoded title.
        // I might need to update service or just copy logic here.
        // Update service is cleaner. But for speed, I might just rely on service for now
        // OR better: Update service to accept title.
        
        await _momentService.exportDailySummary(_selectedDate, customTitle: result);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('生成成功，正在跳转...')));
        
        // Auto navigate to Writer
        Navigator.of(context).pushReplacement(
           PageRouteBuilder(
             pageBuilder: (_,__,___) => const DiaryListPage(),
             transitionDuration: const Duration(milliseconds: 500),
             transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)
           ) 
        );
        
      } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('生成失败: $e')));
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _momentService.init();
    final moments = await _momentService.getMoments();
    if (mounted) {
      setState(() {
        _allMoments = moments;
        _baseDir = _momentService.dataDir;
        _isLoading = false;
        // No pre-filtering needed
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4ECD8),
      drawer: const SidebarWidget(),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD7CCC8),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF5D4037)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          children: [
             Text(
               "${_selectedDate.year}年${_selectedDate.month}月",
               style: GoogleFonts.notoSerifSc(color: const Color(0xFF5D4037), fontSize: 13),
             ),
             Text(
               "随心记",
               style: GoogleFonts.notoSerifSc(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold, fontSize: 16),
             )
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, color: Color(0xFF5D4037)),
            tooltip: '生成今日日记',
            onPressed: _handleAggregation,
          )
        ],
      ),
      body: Column(
        children: [
          // Ruler with Sync Listener
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
               if (notification.depth == 0 && notification is ScrollUpdateNotification) {
                 if (_isPageActive) return false;
                 _isRulerActive = true;
                 
                 if (_pageController.hasClients && _rulerController.hasClients) {
                   double rulerOffset = _rulerController.offset;
                   double page = rulerOffset / 70.0;
                   double pageWidth = MediaQuery.of(context).size.width;
                   _pageController.jumpTo(page * pageWidth);
                 }
               } else if (notification is ScrollEndNotification) {
                 _isRulerActive = false;
                 // Date update is handled by PageView sync usually, or we can double check here
               }
               return false;
            },
            child: RulerDatePicker(
              selectedDate: _selectedDate, 
              onDateChanged: (d) => _onDateChanged(d),
              controller: _rulerController,
            ),
          ),
          
          // List (PageView)
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 && notification is ScrollUpdateNotification) {
                  if (_isRulerActive) return false;
                  _isPageActive = true;
                  
                  if (_pageController.hasClients && _rulerController.hasClients) {
                    double page = _pageController.page ?? 0;
                    double rulerOffset = page * 70.0; 
                    _rulerController.jumpTo(rulerOffset);
                  }
                } else if (notification is ScrollEndNotification) {
                   _isPageActive = false;
                   if (!_isRulerActive && _pageController.hasClients) {
                      int pageIndex = _pageController.page?.round() ?? 0;
                      DateTime targetDate = _startDate.add(Duration(days: pageIndex));
                      if (!_isSameDay(targetDate, _selectedDate)) {
                         _onDateChanged(targetDate, animate: false);
                      }
                   }
                }
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: _dayRange, 
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                   // Optional: Could trigger haptic feedback here
                },
                itemBuilder: (context, index) {
                   DateTime date = _startDate.add(Duration(days: index));
                   List<Moment> moments = _getMomentsForDate(date);
                   
                    if (moments.isEmpty) {
                      return _buildEmptyStateForDate(date);
                    }
                    
                    return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        itemCount: moments.length,
                        itemBuilder: (context, i) {
                           return MomentCard(
                             moment: moments[i],
                             baseDir: _baseDir,
                           );
                        },
                      );
                },
              ),
            ),
          ),
          
          // Input
          MomentInputWidget(onSend: _handleSend),
        ],
      ),
    );
  }

  Widget _buildEmptyStateForDate(DateTime date) {
    bool isToday = _isSameDay(date, DateTime.now());
    return Center(
      child: Opacity(
        opacity: 0.3,
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Icon(Icons.edit_note, size: 64, color: Colors.brown),
             const SizedBox(height: 16),
             Text(
               isToday ? "这一天不仅是空白，更是无限可能" : "这天没有留下记录", 
               style: GoogleFonts.notoSerifSc(fontSize: 14)
             ),
           ],
        ),
      ),
    );
  }
}
