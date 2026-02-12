import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';

class SkeuomorphicDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const SkeuomorphicDatePicker({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<SkeuomorphicDatePicker> createState() => _SkeuomorphicDatePickerState();
}

class _SkeuomorphicDatePickerState extends State<SkeuomorphicDatePicker> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  late PageController _pageController;
  late FixedExtentScrollController _yearScrollController;
  
  // Infinite scroll baseline
  static const int _initialPage = 5000;
  
  // Year Selection Mode
  bool _isYearSelection = false;
  
  // Years range
  final int _startYear = 1900;
  final int _endYear = 2100;
  List<int> get _years => List.generate(_endYear - _startYear + 1, (index) => _startYear + index);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    // Normalize to first day of month
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    
    _pageController = PageController(initialPage: _initialPage);
    
    // Initialize Year Controller
    int initialYearIndex = _years.indexOf(widget.initialDate.year);
    if (initialYearIndex == -1) initialYearIndex = 0;
    _yearScrollController = FixedExtentScrollController(initialItem: initialYearIndex);
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _yearScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_isYearSelection) return; // Ignore page changes if in year mode
    final offset = index - _initialPage;
    setState(() {
      _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month + offset);
    });
  }

  void _changeMonthPage(int offset) {
    _pageController.animateToPage(
      _pageController.page!.round() + offset, 
      duration: const Duration(milliseconds: 400), 
      curve: Curves.easeInOut,
    );
  }

  void _confirmYearSelection(int yearIndex) {
     final year = _years[yearIndex];
     // Calculate target page
     final targetDate = DateTime(year, _currentMonth.month);
     final monthsFromStart = (targetDate.year - widget.initialDate.year) * 12 + (targetDate.month - widget.initialDate.month);
     final targetPage = _initialPage + monthsFromStart;
     
     setState(() {
        _currentMonth = targetDate;
        _isYearSelection = false;
        // Recreate controller because the old one lost its client (PageView was unmounted)
        // and we need to start at the specific new page.
        _pageController.dispose();
        _pageController = PageController(initialPage: targetPage);
     });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<SettingsProvider>(context).currentTheme;
    final isSeaFlower = theme == AppTheme.themeSeaFlower;
    final isMidnight = theme == AppTheme.themeMidnight;
    final isAmber = theme == AppTheme.themeAmberLens;

    // Theme Colors
    Color dialogBg;
    Color headerBg;
    Color headerText;
    Color bodyText;
    Color accentColor;
    Color weekDayColor;
    BoxBorder? border;
    List<BoxShadow> shadows;

    if (isSeaFlower) {
      dialogBg = const Color(0xFFFFF0F5);
      headerBg = const Color(0xFFF8BBD0);
      headerText = const Color(0xFF880E4F);
      bodyText = const Color(0xFF880E4F);
      accentColor = const Color(0xFFF50057);
      weekDayColor = const Color(0xFFAD1457);
      border = Border.all(color: Colors.white, width: 2);
      shadows = AppTheme.cardShadow;
    } else if (isMidnight) {
      dialogBg = const Color(0xFF161b22);
      headerBg = const Color(0xFF0D1117);
      headerText = const Color(0xFFe6edf3);
      bodyText = const Color(0xFFc9d1d9);
      accentColor = const Color(0xFF7986cb);
      weekDayColor = const Color(0xFF8b949e);
      border = Border.all(color: const Color(0xFF30363d));
      shadows = [
         BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))
      ];
    } else if (isAmber) {
      dialogBg = const Color(0xFF1E1E1E);
      headerBg = Colors.black;
      headerText = const Color(0xFFE0E0E0);
      bodyText = const Color(0xFFBDBDBD);
      accentColor = const Color(0xFFFF9800);
      weekDayColor = const Color(0xFFFB8C00);
      border = Border.all(color: const Color(0xFFFF9800), width: 1);
      shadows = [
      ];
    } else if (theme == AppTheme.themeAfterRain) {
      dialogBg = const Color(0xFFF0F8FF); // Alice Blue
      headerBg = const Color(0xFFB3E5FC); // Lighter Blue
      headerText = const Color(0xFF455A64);
      bodyText = const Color(0xFF455A64);
      accentColor = const Color(0xFF0288D1); // Deep Blue Accent
      weekDayColor = const Color(0xFF0277BD);
      border = Border.all(color: Colors.white, width: 2);
      shadows = [
         BoxShadow(color: const Color(0xFF81D4FA).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
      ];
    } else if (theme == AppTheme.themeTwilight) {
      dialogBg = const Color(0xFF352044);
      headerBg = const Color(0xFF2E1A3C);
      headerText = const Color(0xFF4DD0E1);
      bodyText = const Color(0xFFB39DDB);
      accentColor = const Color(0xFF4DD0E1);
      weekDayColor = const Color(0xFF90CAF9);
      border = Border.all(color: const Color(0xFF4DD0E1).withOpacity(0.3), width: 1);
      shadows = [
         BoxShadow(color: const Color(0xFF4DD0E1).withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 5))
      ];
    } else if (theme == AppTheme.themeGardenOfWords) {
      dialogBg = const Color(0xFFF0F4F2); // Mist White
      headerBg = const Color(0xFF2E4A35); // Kotonoha Green
      headerText = const Color(0xFFF0F4F2); // Mist White
      bodyText = const Color(0xFF5A6B72); // Rainy Slate
      accentColor = const Color(0xFF8BC34A); // Fresh Leaf
      weekDayColor = const Color(0xFF1B3321); // Dark Green
      border = Border.all(color: const Color(0xFF8BC34A).withValues(alpha: 0.3), width: 1);
      shadows = [
         BoxShadow(color: const Color(0xFF8BC34A).withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 5))
      ];
    } else {
      // Vintage / Default
      dialogBg = const Color(0xFFF4ECD8);
      headerBg = const Color(0xFF5D4037);
      headerText = const Color(0xFFF4ECD8);
      bodyText = const Color(0xFF5D4037);
      accentColor = const Color(0xFFD32F2F);
      weekDayColor = const Color(0xFF795548);
      border = Border.all(color: const Color(0xFF3E2723), width: 1);
      shadows = AppTheme.cardShadow;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 340,
        height: 520, 
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(12),
          border: border,
          boxShadow: shadows,
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(headerBg, headerText, accentColor),
            
            // Content with Transition
            Expanded(
               child: AnimatedSwitcher(
                 duration: const Duration(milliseconds: 400),
                 transitionBuilder: (child, animation) {
                   return FadeTransition(
                     opacity: animation,
                     child: ScaleTransition(
                       scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
                         parent: animation, curve: Curves.easeOutBack
                       )),
                       child: child,
                     ),
                   );
                 },
                 child: _isYearSelection 
                     ? _buildYearWheel(bodyText, accentColor)
                     : _buildPageView(bodyText, accentColor, weekDayColor),
               ),
            ),
            
            // Footer
            _buildFooter(bodyText, accentColor),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(Color bg, Color text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           // Prevent navigation when in Year mode
           AnimatedOpacity(
             opacity: _isYearSelection ? 0 : 1,
             duration: const Duration(milliseconds: 200),
             child: IconButton(
               icon: Icon(Icons.chevron_left, color: text),
               onPressed: _isYearSelection ? null : () => _changeMonthPage(-1),
             ),
           ),
           
           GestureDetector(
             onTap: () {
                setState(() => _isYearSelection = !_isYearSelection);
                
                if (_isYearSelection) {
                   // Sync wheel to current year
                   int index = _years.indexOf(_currentMonth.year);
                   if (index != -1 && _yearScrollController.hasClients) {
                      _yearScrollController.jumpToItem(index);
                   }
                }
             },
             child: Row(
               children: [
                  Text(
                    DateFormat.yMMMM('zh_CN').format(_currentMonth),
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isYearSelection ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: text.withValues(alpha: 0.7),
                    ),
                  )
               ],
             ),
           ),
           
           AnimatedOpacity(
             opacity: _isYearSelection ? 0 : 1,
             duration: const Duration(milliseconds: 200),
             child: IconButton(
               icon: Icon(Icons.chevron_right, color: text),
               onPressed: _isYearSelection ? null : () => _changeMonthPage(1),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildPageView(Color bodyText, Color accentColor, Color weekDayColor) {
     return Column(
        key: const ValueKey('calendar_view'),
        children: [
           // Weekday Header
           Padding(
             padding: const EdgeInsets.only(top: 16, bottom: 8),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceAround,
               children: ['日', '一', '二', '三', '四', '五', '六'].map((day) {
                 return SizedBox(
                   width: 32,
                   child: Text(
                     day,
                     textAlign: TextAlign.center,
                     style: GoogleFonts.notoSerifSc(
                       fontSize: 14,
                       fontWeight: FontWeight.bold,
                       color: weekDayColor,
                     ),
                   ),
                 );
               }).toList(),
             ),
           ),
           
           Expanded(
             child: PageView.builder(
               controller: _pageController,
               onPageChanged: _onPageChanged,
               itemBuilder: (context, index) {
                  final offset = index - _initialPage;
                  final monthDate = DateTime(widget.initialDate.year, widget.initialDate.month + offset);
                  return _buildCalendarGrid(monthDate, bodyText, accentColor);
               },
             ),
           ),
        ],
     );
  }

  Widget _buildCalendarGrid(DateTime monthDate, Color textColor, Color accentColor) {
    final daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
    final firstDayOffset = DateUtils.firstDayOffset(monthDate.year, monthDate.month, MaterialLocalizations.of(context));
    
    final List<Widget> dayWidgets = [];
    
    // Empty slots for previous month
    for (int i = 0; i < firstDayOffset; i++) {
       dayWidgets.add(const SizedBox(width: 32, height: 32));
    }
    
    // Days
    for (int i = 1; i <= daysInMonth; i++) {
       final date = DateTime(monthDate.year, monthDate.month, i);
       final isSelected = DateUtils.isSameDay(date, _selectedDate);
       final isToday = DateUtils.isSameDay(date, DateTime.now());
       
       dayWidgets.add(
         GestureDetector(
           onTap: () {
             setState(() => _selectedDate = date);
             widget.onDateSelected(date);
             Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) Navigator.pop(context);
             });
           },
           child: Stack(
             alignment: Alignment.center,
             children: [
               if (isSelected) 
                 CustomPaint(
                   size: const Size(36, 36),
                   painter: _CirclePainter(color: accentColor),
                 ),
               Container(
                 width: 32,
                 height: 32,
                 alignment: Alignment.center,
                 decoration: isToday && !isSelected
                    ? BoxDecoration(
                        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                        shape: BoxShape.circle,
                      )
                    : null,
                 child: Text(
                   '$i',
                   style: GoogleFonts.notoSerifSc(
                     fontSize: 14,
                     fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                     color: isSelected ? accentColor : textColor,
                   ),
                 ),
               ),
             ],
           ),
         )
       );
    }
    
    // Use GridView inside PageView items
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
        physics: const NeverScrollableScrollPhysics(),
        children: dayWidgets,
      ),
    );
  }
  
  Widget _buildYearWheel(Color textColor, Color accentColor) {
     return Container(
       key: const ValueKey('year_wheel'),
       alignment: Alignment.center,
       child: Stack(
         alignment: Alignment.center,
         children: [
            // Safe zone / Selection indicator (Optional lines)
            Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: accentColor.withValues(alpha: 0.2), width: 1),
                  bottom: BorderSide(color: accentColor.withValues(alpha: 0.2), width: 1),
                )
              ),
            ),
            
            ListWheelScrollView.useDelegate(
               controller: _yearScrollController,
               itemExtent: 50,
               perspective: 0.005,
               diameterRatio: 1.5,
               magnification: 1.2,
               useMagnifier: true,
               physics: const FixedExtentScrollPhysics(),
               onSelectedItemChanged: (index) {
                  HapticFeedback.selectionClick();
               },
               childDelegate: ListWheelChildBuilderDelegate(
                 childCount: _years.length,
                 builder: (context, index) {
                   final year = _years[index];
                   
                   // We need to know if it's selected to change visual style instantly
                   // But ListWheelScrollView handles scale/opacity. 
                   // We can rely on standard text styling here.
                   return Center(
                     child: Text(
                        '$year',
                        style: GoogleFonts.notoSerifSc(
                           fontSize: 22,
                           color: textColor, // The magnifier will scale this
                           fontWeight: FontWeight.w500,
                        ),
                     ),
                   );
                 },
               ),
            ),
         ],
       ),
     );
  }
  
  Widget _buildFooter(Color bodyText, Color accentColor) {
     return Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(color: bodyText.withValues(alpha: 0.7)),
              ),
            ),
            
            // Confirm button changes meaning in Year mode
            TextButton(
              onPressed: () {
                if (_isYearSelection) {
                  _confirmYearSelection(_yearScrollController.selectedItem);
                } else {
                  // Jump to today
                  final now = DateTime.now();
                  
                  // Calculate target page for Today
                  final offset = (now.year - widget.initialDate.year) * 12 + (now.month - widget.initialDate.month);
                  final targetPage = _initialPage + offset;

                  setState(() {
                     _selectedDate = now;
                     _currentMonth = DateTime(now.year, now.month);
                     _isYearSelection = false;
                     
                     // If we were in year selection or just need to be safe
                     if (_pageController.hasClients) {
                        _pageController.jumpToPage(targetPage);
                     } else {
                        _pageController.dispose();
                        _pageController = PageController(initialPage: targetPage);
                     }
                  });
                  
                  widget.onDateSelected(_selectedDate);
                  Navigator.pop(context);
                }
              },
              child: Text(
                _isYearSelection ? '确定' : '今天',
                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
  }
}

class _CirclePainter extends CustomPainter {
  final Color color;
  _CirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Simulate imperfect circle
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawOval(rect, paint);
    canvas.drawOval(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
