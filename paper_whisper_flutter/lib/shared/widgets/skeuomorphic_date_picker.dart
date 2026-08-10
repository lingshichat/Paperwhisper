import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'skeuomorphic_dialog.dart';

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
  List<int> get _years =>
      List.generate(_endYear - _startYear + 1, (index) => _startYear + index);

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
    _yearScrollController = FixedExtentScrollController(
      initialItem: initialYearIndex,
    );
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
      _currentMonth = DateTime(
        widget.initialDate.year,
        widget.initialDate.month + offset,
      );
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
    final monthsFromStart =
        (targetDate.year - widget.initialDate.year) * 12 +
        (targetDate.month - widget.initialDate.month);
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
    final theme = AppTheme.themeIdOf(context);
    final tc = ThemeRegistry.get(theme).datePicker;

    // Theme Colors
    final Color dialogBg = tc.dialogBg;
    final Color headerBg = tc.headerBg;
    final Color headerText = tc.headerText;
    final Color bodyText = tc.bodyText;
    final Color accentColor = tc.accentColor;
    final Color weekDayColor = tc.weekDayColor;
    final BoxBorder border = tc.border;
    final List<BoxShadow> shadows = tc.shadows;

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
                      scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
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
                ),
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
              final monthDate = DateTime(
                widget.initialDate.year,
                widget.initialDate.month + offset,
              );
              return _buildCalendarGrid(monthDate, bodyText, accentColor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(
    DateTime monthDate,
    Color textColor,
    Color accentColor,
  ) {
    final daysInMonth = DateUtils.getDaysInMonth(
      monthDate.year,
      monthDate.month,
    );
    final firstDayOffset = DateUtils.firstDayOffset(
      monthDate.year,
      monthDate.month,
      MaterialLocalizations.of(context),
    );

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
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                        ),
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Text(
                  '$i',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 14,
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? accentColor : textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                top: BorderSide(
                  color: accentColor.withValues(alpha: 0.2),
                  width: 1,
                ),
                bottom: BorderSide(
                  color: accentColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
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
        children: [
          Expanded(
            child: SkeuomorphicDialogButton(
              label: '取消',
              isPrimary: false,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          // Confirm button changes meaning in Year mode
          Expanded(
            child: SkeuomorphicDialogButton(
              label: _isYearSelection ? '确定' : '今天',
              isPrimary: true,
              onPressed: () {
                if (_isYearSelection) {
                  _confirmYearSelection(_yearScrollController.selectedItem);
                } else {
                  // Jump to today
                  final now = DateTime.now();

                  // Calculate target page for Today
                  final offset =
                      (now.year - widget.initialDate.year) * 12 +
                      (now.month - widget.initialDate.month);
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
