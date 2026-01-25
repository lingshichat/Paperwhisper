import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/moment.dart';
import '../services/moment_service.dart';
import '../widgets/moment_card.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/ruler_date_picker.dart';
import '../widgets/moment_input_widget.dart';
import '../pages/diary_list_page.dart';
import '../providers/settings_provider.dart'; // Added
import '../providers/sync_provider.dart'; // Added
import '../config/app_theme.dart'; // Added
import '../widgets/skeuomorphic_toast.dart'; // Added
import '../widgets/skeuomorphic_dialog.dart'; // Added
import 'package:flutter_svg/flutter_svg.dart'; // Added


import '../providers/diary_provider.dart'; // Added
import '../widgets/skeuomorphic_search_bar.dart'; // Added
import '../widgets/visual_effects.dart'; // Added for petal effects
import '../services/payment_service.dart';
import '../pages/premium_membership_page.dart';
import '../widgets/slide_page_route.dart';

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

  // Search State
  bool _isSearching = false; 
  
  // Focus Management
  final FocusNode _inputFocusNode = FocusNode();
  
  // Dynamic Input Height
  double _inputHeight = 80.0;

  @override
  void initState() {
    super.initState();
    _initDates();
    _initControllers();
    _loadData();
    
    // Listen to focus changes to rebuild UI (toggle dismiss layer)
    _inputFocusNode.addListener(() {
        if (mounted) setState(() {});
    });
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
    _inputFocusNode.dispose(); // Dispose focus node
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

  Future<void> _handleSend(String content, List<XFile> images, {String? audioPath, String? audioTitle, int? audioDuration}) async {
    // 会员 / 试用：免费用户当日限 3 条
    final pay = Provider.of<PaymentService>(context, listen: false);
    if (!pay.canUseProFeatures) {
      final todayCount = _getMomentsForDate(DateTime.now()).length;
      if (todayCount >= 3) {
        if (!mounted) return;
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => SkeuomorphicDialog(
            title: '今日额度已用完',
            headerIcon: Icons.lock_outline,
            content: const Text('免费版每日 3 条随心记。赞助后解锁无限创作、WebDAV 同步与更多能力。'),
            actions: [
              SkeuomorphicDialogButton(label: '取消', isPrimary: false, onPressed: () => Navigator.pop(ctx, false)),
              SkeuomorphicDialogButton(label: '去赞助', onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        );
        if (go == true && mounted) {
          Navigator.push(context, SlidePageRoute(page: const PremiumMembershipPage()));
        }
        return;
      }
    }

    // 1. Save images
    List<String> savedPaths = [];
    for (var img in images) {
      String path = await _momentService.saveImage(File(img.path));
      savedPaths.add(path);
    }
    
    // 2. Save Audio
    String? savedAudioPath;
    if (audioPath != null) {
      try {
        savedAudioPath = await _momentService.saveAudio(audioPath);
      } catch (e) {
        debugPrint("Error saving audio: $e");
      }
    }
    
    // 3. Create Moment
    // ...
    
    DateTime timestamp = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      DateTime.now().hour, DateTime.now().minute, DateTime.now().second
    );

    Moment newMoment = Moment.create(
      content: content,
      images: savedPaths,
      audioPath: savedAudioPath,
      audioTitle: audioTitle,
      audioDuration: audioDuration,
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
    
    if (mounted) {
       final syncProvider = context.read<SyncProvider>();
       if (syncProvider.isConfigured) {
           SkeuomorphicToast.info(context, '记录已保存，准备同步...');
           syncProvider.checkNotificationPermission(context).then((_) {
              if (mounted) syncProvider.requestAutoSync(force: true, context: context); // Force immediate sync
           });
       } else {
           SkeuomorphicToast.success(context, '记录已保存');
       }
    }
  }

  Future<void> _handleAggregation() async {
    if (!Provider.of<PaymentService>(context, listen: false).canUseProFeatures) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => SkeuomorphicDialog(
title: '需要赞助',
            headerIcon: Icons.lock_outline,
            content: const Text('「随心记转长文」赞助后可用。'),
            actions: [
              SkeuomorphicDialogButton(label: '取消', isPrimary: false, onPressed: () => Navigator.pop(ctx, false)),
              SkeuomorphicDialogButton(label: '去赞助', onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.push(context, SlidePageRoute(page: const PremiumMembershipPage()));
      }
      return;
    }

    // Show Dialog
    String title = "今日份的日记";
    String inputVal = "";

    // Prepare theme-aware colors
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final isMidnight = theme == AppTheme.themeMidnight;
    
    final inputBg = isMidnight ? Colors.black.withOpacity(0.3) : Colors.white.withValues(alpha: 0.5);
    final inputBorder = isMidnight ? Colors.white.withOpacity(0.1) : Colors.brown.shade300;
    final hintColor = isMidnight ? Colors.white38 : Colors.brown.shade700;
    final textColor = isMidnight ? Colors.white70 : Colors.brown.shade900;
    final descColor = isMidnight ? Colors.white60 : Colors.black87;

    String? result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SkeuomorphicDialog(
          title: '生成长文日记',
          headerIcon: Icons.auto_awesome, // Magic icon
          content: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('将今天的记录汇聚成篇，存入专注书写模块。', style: GoogleFonts.notoSerifSc(fontSize: 14, color: descColor)),
               const SizedBox(height: 20),
               
               // Skeuomorphic Input Field (Simple version)
               Container(
                 decoration: BoxDecoration(
                   color: inputBg,
                   border: Border(bottom: BorderSide(color: inputBorder, width: 2)),
                 ),
                 child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '为日记起个名字',
                      hintText: '默认: 今日份的日记',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      labelStyle: GoogleFonts.notoSerifSc(color: hintColor),
                      hintStyle: GoogleFonts.notoSerifSc(color: hintColor.withOpacity(0.5)),
                    ),
                    style: GoogleFonts.notoSerifSc(color: textColor),
                    onChanged: (v) => inputVal = v,
                 ),
               )
             ],
          ),
          actions: [
            SkeuomorphicDialogButton(
               label: '取消', 
               isPrimary: false,
               onPressed: () => Navigator.pop(ctx)
            ),
            SkeuomorphicDialogButton(
               label: '生成', 
               isPrimary: true,
               onPressed: () => Navigator.pop(ctx, inputVal.isEmpty ? title : inputVal)
            ),
          ],
        );
      }
    );

    if (result != null) {
      try {
        await _momentService.exportDailySummary(_selectedDate, customTitle: result);
        
        if (!mounted) return;
        
        final syncProvider = context.read<SyncProvider>();
        if (syncProvider.isConfigured) {
            syncProvider.requestAutoSync(context: context);
        }

        SkeuomorphicToast.success(context, '生成成功，正在跳转...');
        
        // Auto navigate to Writer
        Navigator.of(context).pushReplacement(
           PageRouteBuilder(
             pageBuilder: (_,__,___) => const DiaryListPage(),
             transitionDuration: const Duration(milliseconds: 500),
             transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)
           ) 
        );
        
      } catch (e) {
         if (mounted) SkeuomorphicToast.error(context, '生成失败: $e');
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
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    final bool isMidnight = theme == AppTheme.themeMidnight;
    final bool isAmber = theme == AppTheme.themeAmberLens;

    // Theme Colors
    // Theme Colors
    Color appBarIconColor;
    Color appBarTextColor;

    if (isSeaFlower) {
      appBarIconColor = const Color(0xFFD81B60); // Pink 600
      appBarTextColor = const Color(0xFF880E4F); // Pink 900
    } else if (isMidnight || isAmber) {
      appBarIconColor = Colors.white70;
      appBarTextColor = Colors.white;
    } else {
      // Vintage
      appBarIconColor = const Color(0xFFD7CCC8); // Beige Light
      appBarTextColor = const Color(0xFFD7CCC8);
    }

    final Color rulerAccent = AppTheme.getAccentColor(theme);

    // Ruler Colors Configuration
    Color? rulerBg;
    Color? rulerTextColor;
    Color? rulerInactiveTextColor;
    Color? rulerSubTextColor;
    Color? rulerInactiveSubTextColor;
    Color? rulerIndicatorColor;
    Color? rulerShadowColor;
    Color? rulerBorderColor;

    if (isSeaFlower) {
      // 拟物风：浅白色半透明磨砂质感
      rulerBg = Colors.white.withOpacity(0.9);
      rulerTextColor = const Color(0xFF880E4F);
      rulerInactiveTextColor = const Color(0xFF880E4F).withOpacity(0.4);
      rulerSubTextColor = const Color(0xFF880E4F);
      rulerInactiveSubTextColor = const Color(0xFF880E4F).withOpacity(0.4);
      rulerIndicatorColor = const Color(0xFFF50057);
      rulerShadowColor = const Color(0x1F880E4F); // 柔和粉色阴影
      rulerBorderColor = Colors.transparent;
    }
    
    // Search Integration
    final diaryProvider = Provider.of<DiaryProvider>(context);
    final String searchQuery = diaryProvider.searchQuery;
    final bool isSearchActive = searchQuery.isNotEmpty;

    // Filter Logic if searching
    if (isSearchActive) {
      // Filter _allMoments
      _filteredMoments = _allMoments.where((m) {
        // Basic match: content or plain text
        // Moment has content string.
        return m.content.contains(searchQuery);
      }).toList();
      // Sort by latest first for search
      _filteredMoments.sort((a,b) => b.createdAt.compareTo(a.createdAt));
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 800;
        final canUse = Provider.of<PaymentService>(context, listen: true).canUseProFeatures;
        final showLimitBanner = !canUse && _getMomentsForDate(DateTime.now()).length >= 3;
        debugPrint("LayoutBuilder Constraints: ${constraints.maxWidth} (isDesktop: $isDesktop)");
        
        // 简化 content 结构：直接使用 SafeArea + Column，避免嵌套 Stack 导致的渲染问题
        final Widget content = SafeArea(
          top: !isDesktop, 
          bottom: isDesktop, 
          child: Column(
            children: [
                // On Desktop, we need a Header (replacement for AppBar)
                if (isDesktop) 
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       _buildDesktopHeader(appBarTextColor, appBarIconColor),
                       // 恢复尺子
                       SizedBox(
                         height: 85,
                         child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                               if (notification is ScrollUpdateNotification) {
                                  // 仅处理尺子自身的滚动，不与列表联动(因为列表是全量的)
                                  // 这里主要依靠 RulerDatePicker 内部或者 controller 变动来触发 _onDateChanged
                                  // 但原逻辑是靠 PageView 驱动 Ruler，或 Ruler 驱动 PageView
                                  // 这里我们让 Ruler 独立工作，只改变 _selectedDate
                                  return false;
                               }
                               return false;
                            },
                            child: RulerDatePicker(
                              selectedDate: _selectedDate, 
                              onDateChanged: (d) => _onDateChanged(d, animate: false), // 不驱动 PageView
                              controller: _rulerController,
                              accentColor: rulerAccent,
                              backgroundColor: rulerBg,
                              textColor: rulerTextColor,
                              inactiveTextColor: rulerInactiveTextColor,
                              subTextColor: rulerSubTextColor,
                              inactiveSubTextColor: rulerInactiveSubTextColor,
                              indicatorColor: rulerIndicatorColor,
                              shadowColor: rulerShadowColor,
                              borderColor: rulerBorderColor,
                            ),
                         ),
                       ),
                    ],
                  ),
                  
                // If searching, show result list. Else show regular layout.
                if (isSearchActive) 
                   Expanded(child: _buildSearchResults(theme, textColor: rulerTextColor))
                else if (isDesktop)
                   // Desktop Waterfall Layout
                   Expanded(
                     child: Stack(
                       children: [
                         // Grid - 联动尺子日期
                         _buildDesktopWaterfall(context, _getMomentsForDate(_selectedDate)),
                         
                         // Floating Input (Bottom Center) - 拟物化悬浮岛设计
                         Align(
                           alignment: Alignment.bottomCenter,
                           child: Padding(
                             padding: const EdgeInsets.only(bottom: 30),
                             child: Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 if (showLimitBanner) _buildLimitBanner(context),
                                 Container(
                                   width: 600,
                                   decoration: BoxDecoration(
                                     borderRadius: BorderRadius.circular(24),
                                     boxShadow: [
                                       BoxShadow(
                                         color: Colors.black.withOpacity(0.2), // Deep shadow
                                         blurRadius: 15,
                                         offset: const Offset(0, 8),
                                       ),
                                       BoxShadow(
                                         color: Colors.black.withOpacity(0.1), // Ambient shadow
                                         blurRadius: 5,
                                         offset: const Offset(0, 0),
                                       ),
                                     ],
                                   ),
                                   child: ClipRRect(
                                     borderRadius: BorderRadius.circular(24), // Rounded corners for the widget
                                     child: MomentInputWidget(onSend: _handleSend),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         )
                       ],
                     )
                   )
                else ...[
                  // Mobile Layout (Ruler + List)
                  // Ruler with Sync Listener
                  NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                       if (notification.depth == 0 && notification is ScrollUpdateNotification) {
                         if (_isPageActive) return false;
                         _isRulerActive = true;
                         
                         if (_pageController.hasClients && _rulerController.hasClients) {
                           double rulerOffset = _rulerController.offset;
                           double page = rulerOffset / 70.0;
                           double pageWidth = _pageController.position.viewportDimension;
                           _pageController.jumpTo(page * pageWidth);
                         }
                       } else if (notification is ScrollEndNotification) {
                         _isRulerActive = false;
                       }
                       return false;
                    },
                    child: RulerDatePicker(
                      selectedDate: _selectedDate, 
                      onDateChanged: (d) => _onDateChanged(d),
                      controller: _rulerController,
                      accentColor: rulerAccent,
                      backgroundColor: rulerBg,
                      textColor: rulerTextColor,
                      inactiveTextColor: rulerInactiveTextColor,
                      subTextColor: rulerSubTextColor,
                      inactiveSubTextColor: rulerInactiveSubTextColor,
                      indicatorColor: rulerIndicatorColor,
                      shadowColor: rulerShadowColor,
                      borderColor: rulerBorderColor,
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
                                padding: EdgeInsets.only(top: 20, bottom: _inputHeight + 20), 
                                itemCount: moments.length,
                                itemBuilder: (context, i) {
                                   return MomentCard(
                                     moment: moments[i],
                                     baseDir: _baseDir,
                                     onDelete: () async {
                                        await _momentService.deleteMoment(moments[i].uuid);
                                        // Refresh
                                        await _loadData();
                                        if (mounted) {
                                           SkeuomorphicToast.success(context, '随心记已删除');
                                        }
                                     },
                                   );
                                },
                              );
                        },
                      ),
                    ),
                  ),
                ],
            ],
          ),
        );

        if (isDesktop) {
          return Scaffold(
             backgroundColor: Colors.transparent, 
             body: Stack(
               children: [
                 // 1. Background
                 Container(decoration: AppTheme.getBackground(theme)),
                 
                 // 2. Visual Effects
                 if (isSeaFlower) const PetalRainWidget(),
                 if (isMidnight) const StarrySkyWidget(),
                 
                 // 3. Main Layout
                 Row(
                   children: [
                      const SizedBox(width: 300, child: SidebarWidget()),
                      Expanded(child: content),
                   ],
                 )
               ],
             ),
           );
        }

        // Mobile Header Logic
        Widget headerTitle;
        if (_isSearching) {
           headerTitle = SkeuomorphicSearchBar(
             value: searchQuery,
             onChanged: (val) => diaryProvider.setSearchQuery(val),
             autoFocus: true,
           );
        } else {
           headerTitle = Column(
              children: [
                 Text(
                   "${_selectedDate.year}年${_selectedDate.month}月",
                   style: GoogleFonts.notoSerifSc(color: appBarTextColor.withOpacity(0.8), fontSize: 13),
                 ),
                 Text(
                   "随心记",
                   style: GoogleFonts.notoSerifSc(color: appBarTextColor, fontWeight: FontWeight.bold, fontSize: 16),
                 )
              ],
           );
        }

        return Scaffold(
          extendBodyBehindAppBar: true, 
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          drawerScrimColor: isSeaFlower ? Colors.transparent : Colors.black54, // 统一遮罩逻辑
          drawer: const Drawer(
             width: 300,
             elevation: 0,
             backgroundColor: Colors.transparent,
             child: SidebarWidget(),
          ),
          appBar: AppBar(
            backgroundColor: isSeaFlower 
                ? const Color(0xFFFCE4EC).withOpacity(0.8) 
                : const Color(0xFF1E1E1E).withOpacity(0.5), 
            elevation: 0,
            leading: Builder(
              builder: (context) {
                 if (_isSearching) {
                   return IconButton(
                     icon: Icon(Icons.arrow_back, color: appBarIconColor),
                     onPressed: () {
                        setState(() { _isSearching = false; });
                        diaryProvider.setSearchQuery('');
                     }
                   );
                 }
                 return IconButton(
                    icon: Icon(Icons.menu, color: appBarIconColor),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                 );
              }
            ),
            title: AnimatedSwitcher(
               duration: const Duration(milliseconds: 300),
               child: headerTitle,
            ),
            centerTitle: true,
            actions: [
               if (!_isSearching)
                 IconButton(
                    icon: Icon(Icons.search, color: appBarIconColor),
                    onPressed: () => setState(() => _isSearching = true),
                 ),
               
               if (!_isSearching)
                 IconButton(
                   key: const ValueKey('mobile_generate_btn'),
                   icon: Icon(Icons.description_outlined, color: appBarIconColor),
                   tooltip: '生成今日日记',
                   onPressed: _handleAggregation,
                 )
            ],
          ),
          body: Builder(
            builder: (bodyContext) {
              final bottomInset = MediaQuery.of(bodyContext).viewInsets.bottom;
              final isKeyboardOpen = bottomInset > 0;
              
              return Stack(
                children: [
                  // 0. Background
                  Positioned.fill(
                    child: Container(decoration: AppTheme.getBackground(theme))
                  ),
                  
                  // 0.5. Visual Effects
                  if (isSeaFlower) Positioned.fill(child: const PetalRainWidget()),
                  if (isMidnight) Positioned.fill(child: const StarrySkyWidget()),

                  // 1. Main Content
                  // Use AnimatedPositioned for smooth resizing content area
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: isKeyboardOpen ? bottomInset : 0, 
                    child: content
                  ),
                  
                  // 2. Dismiss Layer
                  if (isKeyboardOpen || _inputFocusNode.hasFocus)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque, 
                        onTap: () {
                          _inputFocusNode.unfocus(); 
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  
                  // 3. Input Widget
                  // Use AnimatedPositioned to smooth out the jump if ViewInsets updates late
                  if (!isSearchActive)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      left: 0,
                      right: 0,
                      bottom: bottomInset, // Will animate to this target
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showLimitBanner) _buildLimitBanner(bodyContext),
                          MomentInputWidget(
                              onSend: _handleSend, 
                              focusNode: _inputFocusNode,
                              onHeightChanged: (h) {
                                 if ((_inputHeight - h).abs() > 1) { // Debounce/Throttling check
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                       if (mounted) setState(() => _inputHeight = h);
                                    });
                                 }
                              },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }
          ),
        );
      }
    );
  }

  Widget _buildLimitBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8D6E63).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5D4037)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '今日随心记已用完 (3/3)，赞助后解锁无限创作',
              style: GoogleFonts.notoSerifSc(color: Colors.white, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, SlidePageRoute(page: const PremiumMembershipPage())),
            child: Text('去赞助', style: GoogleFonts.notoSerifSc(color: const Color(0xFFFFE0B2), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(String theme, {Color? textColor}) {
    // 使用透明容器，确保背景可以穿透显示
    return Container(
      color: Colors.transparent, // 透明背景
      child: _filteredMoments.isEmpty
        ? Center(
            child: Opacity(
              opacity: 0.7,
              child: Text(
                '没有找到相关记忆...',
                style: GoogleFonts.notoSerifSc(
                  color: textColor?.withOpacity(0.7) ?? Colors.white70,
                  fontSize: 16
                )
              ),
            )
          )
        : ListView.builder(
            padding: EdgeInsets.only(top: 20, bottom: _inputHeight + 20),
            itemCount: _filteredMoments.length,
            itemBuilder: (context, i) {
               return MomentCard(
                 moment: _filteredMoments[i],
                 baseDir: _baseDir,
                 onDelete: () async {
                    await _momentService.deleteMoment(_filteredMoments[i].uuid);
                    await _loadData();
                 },
               );
            },
          ),
    );
  }

  Widget _buildDesktopHeader(Color textColor, Color iconColor) {
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
       decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05), // Subtle bg for header
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
       ),
       child: Row(
         children: [
           // Leading (empty or back?) - No drawer icon needed
           const SizedBox(width: 48), // Spacer to center title if needed, or just let it adjust
           
           Expanded(
             child: Column(
                children: [
                   Text(
                     "${_selectedDate.year}年${_selectedDate.month}月",
                     style: GoogleFonts.notoSerifSc(color: textColor.withOpacity(0.8), fontSize: 13),
                   ),
                   Text(
                     "随心记",
                     style: GoogleFonts.notoSerifSc(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                   )
                ],
             ),
           ),
           
           IconButton(
             key: const ValueKey('desktop_generate_btn'),
             icon: Icon(Icons.description_outlined, color: iconColor),
             tooltip: '生成今日日记',
             onPressed: _handleAggregation,
           )
         ],
       ),
    );
  }

  Widget _buildEmptyStateForDate(DateTime date) {
    bool isToday = _isSameDay(date, DateTime.now());
    final theme = Provider.of<SettingsProvider>(context, listen: false).currentTheme;
    
    // 简洁拟物化配置 - 仅颜色适配
    Color iconColor;
    Color textColor;
    
    switch (theme) {
      case AppTheme.themeMidnight:
        iconColor = const Color(0xFF7986cb);
        textColor = const Color(0xFFc9d1d9);
        break;
      case AppTheme.themeSeaFlower:
        iconColor = const Color(0xFFF50057);
        textColor = const Color(0xFF880E4F);
        break;
      case AppTheme.themeAmberLens:
        iconColor = const Color(0xFFFF9800);
        textColor = const Color(0xFFE0E0E0);
        break;
      default: // Vintage
        // 适配专注写作的风格：暖灰色/半透明白
        iconColor = const Color(0xFFD7CCC8).withValues(alpha: 0.5);
        textColor = const Color(0xFFD7CCC8).withValues(alpha: 0.8); 
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isToday ? Icons.lightbulb_outline : Icons.edit_note,
            size: 80,
            color: iconColor.withValues(alpha: 0.7), // 叠加透明度
          ),
          const SizedBox(height: 24),
          Text(
            isToday ? "这一天不仅是空白，更是无限可能" : "这天没有留下记录",
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 16,
              color: textColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWaterfall(BuildContext context, List<Moment> moments) {
    if (moments.isEmpty) {
      // Just pick a random date or today for empty state logic
      return _buildEmptyStateForDate(DateTime.now());
    }

    // Sort by latest first for waterfall (Spontaneous inputs matter most)
    final sortedMoments = List<Moment>.from(moments);
    sortedMoments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Logic from DiaryListPage
        int columnCount = 1;
        if (width > 1200) { // Slightly wider for moments card
          columnCount = 3;
        } else if (width > 750) {
          columnCount = 2;
        }

        // Masonry Logic
        List<List<Moment>> columns = List.generate(columnCount, (_) => []);
        for (int i = 0; i < sortedMoments.length; i++) {
          columns[i % columnCount].add(sortedMoments[i]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 20, 40, 100), // Bottom padding for input widget
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < columnCount; i++)
                Expanded(
                  child: Padding(
                    padding: i < columnCount - 1 
                        ? const EdgeInsets.only(right: 24) 
                        : EdgeInsets.zero,
                    child: Column(
                      children: columns[i].map((moment) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: MomentCard(
                             moment: moment,
                             baseDir: _baseDir,
                             onDelete: () async {
                                await _momentService.deleteMoment(moment.uuid);
                                await _loadData();
                             },
                           ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
