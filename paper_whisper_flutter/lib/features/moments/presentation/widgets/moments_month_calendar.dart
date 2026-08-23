import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_index.dart';

/// 随心记顶栏展开月历。周日为首列，固定 6 行，高度锁死 296。
class MomentsMonthCalendar extends StatefulWidget {
  const MomentsMonthCalendar({
    super.key,
    required this.selectedDate,
    required this.startDate,
    required this.endDate,
    required this.hasContentOnDate,
    required this.onDateSelected,
    this.onJumpToToday,
  });

  final DateTime selectedDate;
  final DateTime startDate;
  final DateTime endDate;
  final bool Function(DateTime date) hasContentOnDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onJumpToToday;

  @override
  State<MomentsMonthCalendar> createState() => _MomentsMonthCalendarState();
}

class _MomentsMonthCalendarState extends State<MomentsMonthCalendar> {
  late DateTime _visibleMonth;
  late final PageController _pageController;

  static const _pageDuration = Duration(milliseconds: 300);
  static const _pageCurve = Curves.easeOutCubic;

  /// 周日=0 … 周六=6，与表头「日一二三四五六」对齐。
  static int sundayBasedLeadingOffset(DateTime month) {
    return DateTime(month.year, month.month, 1).weekday % 7;
  }

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  DateTime _clampMonth(DateTime month) {
    final startMonth = _monthOf(widget.startDate);
    final endMonth = _monthOf(widget.endDate);
    final m = _monthOf(month);
    if (m.isBefore(startMonth)) return startMonth;
    if (m.isAfter(endMonth)) return endMonth;
    return m;
  }

  int get _monthCount {
    final start = _monthOf(widget.startDate);
    final end = _monthOf(widget.endDate);
    return (end.year - start.year) * 12 + (end.month - start.month) + 1;
  }

  int _indexOfMonth(DateTime month) {
    final start = _monthOf(widget.startDate);
    final m = _clampMonth(month);
    return (m.year - start.year) * 12 + (m.month - start.month);
  }

  DateTime _monthAt(int index) {
    final start = _monthOf(widget.startDate);
    return DateTime(start.year, start.month + index);
  }

  int get _currentPage {
    if (_pageController.hasClients && _pageController.page != null) {
      return _pageController.page!.round();
    }
    return _indexOfMonth(_visibleMonth);
  }

  bool _todayEnabled(DateTime now) {
    final n = DateTime(now.year, now.month, now.day);
    return !n.isBefore(widget.startDate) && !n.isAfter(widget.endDate);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _visibleMonth = _clampMonth(widget.selectedDate);
    _pageController = PageController(initialPage: _indexOfMonth(_visibleMonth));
  }

  @override
  void didUpdateWidget(covariant MomentsMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedMonth = _monthOf(widget.selectedDate);
    final oldSelectedMonth = _monthOf(oldWidget.selectedDate);
    if (selectedMonth != oldSelectedMonth &&
        (selectedMonth.year != _visibleMonth.year ||
            selectedMonth.month != _visibleMonth.month)) {
      _visibleMonth = _clampMonth(selectedMonth);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_indexOfMonth(_visibleMonth));
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _monthCount) return;
    _pageController.animateToPage(
      index,
      duration: _pageDuration,
      curve: _pageCurve,
    );
  }

  void _prevMonth() => _goToPage(_currentPage - 1);

  void _nextMonth() => _goToPage(_currentPage + 1);

  void _onPageChanged(int index) {
    final month = _monthAt(index);
    if (month.year == _visibleMonth.year &&
        month.month == _visibleMonth.month) {
      return;
    }
    setState(() => _visibleMonth = month);
  }

  String _semanticsLabel(
    DateTime date, {
    required bool isToday,
    required bool hasContent,
  }) {
    final day = '${date.month}月${date.day}日';
    final prefix = isToday ? '今天，$day' : day;
    return hasContent ? '$prefix，有随心记' : prefix;
  }

  @override
  Widget build(BuildContext context) {
    final themeId = AppTheme.themeIdOf(context);
    final moments = ThemeRegistry.get(themeId).moments;
    final accent = AppTheme.getAccentColor(themeId);
    final textColor = moments.rulerTextColor;
    final inactive = moments.rulerInactiveTextColor;
    final indicator = moments.rulerIndicatorColor;

    final startMonth = _monthOf(widget.startDate);
    final endMonth = _monthOf(widget.endDate);
    final atStartMonth =
        _visibleMonth.year == startMonth.year &&
        _visibleMonth.month == startMonth.month;
    final atEndMonth =
        _visibleMonth.year == endMonth.year &&
        _visibleMonth.month == endMonth.month;
    final now = DateTime.now();
    final todayEnabled = widget.onJumpToToday != null && _todayEnabled(now);
    final todayColor = todayEnabled ? accent : inactive;
    final chevronLeftColor = atStartMonth ? inactive : textColor;
    final chevronRightColor = atEndMonth ? inactive : textColor;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 296),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: moments.rulerBg,
          border: Border(bottom: BorderSide(color: moments.rulerBorderColor)),
          boxShadow: [
            BoxShadow(
              color: moments.rulerShadowColor,
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            height: 288, // 40 + 22 + 226
            child: Stack(
              children: [
                PageView.builder(
                  key: const ValueKey('moments_cal_pager'),
                  controller: _pageController,
                  itemCount: _monthCount,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final month = _monthAt(index);
                    return _buildMonthPage(
                      month: month,
                      accent: accent,
                      textColor: textColor,
                      inactive: inactive,
                      indicator: indicator,
                      now: now,
                    );
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    key: const ValueKey('moments_cal_header'),
                    height: 40,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: atStartMonth ? null : _prevMonth,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.chevron_left,
                              size: 20,
                              color: chevronLeftColor,
                            ),
                          ),
                        ),
                        // 中间让给 PageView，标题几何居中且可横向滑动。
                        const Expanded(
                          child: IgnorePointer(child: SizedBox.expand()),
                        ),
                        GestureDetector(
                          onTap: todayEnabled ? widget.onJumpToToday : null,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: 40,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '今天',
                                  maxLines: 1,
                                  style: GoogleFonts.notoSerifSc(
                                    fontSize: 13,
                                    height: 1.0,
                                    color: todayColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: atEndMonth ? null : _nextMonth,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: chevronRightColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthPage({
    required DateTime month,
    required Color accent,
    required Color textColor,
    required Color inactive,
    required Color indicator,
    required DateTime now,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: Center(
            child: Padding(
              // 两侧等宽，避开叠在上面的 chevron / 「今天」，标题仍相对面板居中。
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${month.year}年${month.month}月',
                  key: ValueKey(
                    'moments_cal_month_title_${month.year}_${month.month}',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 13,
                    height: 1.0,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 22,
          child: Row(
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map(
                  (d) => Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 12,
                          height: 1.0,
                          fontWeight: FontWeight.bold,
                          color: inactive,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(
          height: 226, // 6×36 + 5×2
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 36,
              mainAxisSpacing: 2,
              crossAxisSpacing: 0,
            ),
            itemBuilder: (context, index) {
              return _buildCell(
                month: month,
                index: index,
                accent: accent,
                textColor: textColor,
                inactive: inactive,
                indicator: indicator,
                now: now,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCell({
    required DateTime month,
    required int index,
    required Color accent,
    required Color textColor,
    required Color inactive,
    required Color indicator,
    required DateTime now,
  }) {
    final leading = sundayBasedLeadingOffset(month);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final dayNumber = index - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return SizedBox(
        key: ValueKey('moments_cal_pad_${month.year}_${month.month}_$index'),
      );
    }

    final date = DateTime(month.year, month.month, dayNumber);
    final key = MomentIndex.dayKey(date);
    final inRange =
        !date.isBefore(
          DateTime(
            widget.startDate.year,
            widget.startDate.month,
            widget.startDate.day,
          ),
        ) &&
        !date.isAfter(
          DateTime(
            widget.endDate.year,
            widget.endDate.month,
            widget.endDate.day,
          ),
        );
    final isSelected = _isSameDay(date, widget.selectedDate);
    final isToday = _isSameDay(date, now);
    final hasContent = widget.hasContentOnDate(date);
    final numberColor = inRange ? textColor : inactive;

    return Semantics(
      button: inRange,
      enabled: inRange,
      label: _semanticsLabel(date, isToday: isToday, hasContent: hasContent),
      child: GestureDetector(
        key: ValueKey('moments_cal_$key'),
        onTap: inRange
            ? () {
                HapticFeedback.selectionClick();
                widget.onDateSelected(date);
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      CustomPaint(
                        size: const Size(22, 22),
                        painter: _SelectedDayHaloPainter(color: accent),
                      ),
                    if (isToday && !isSelected)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$dayNumber',
                        maxLines: 1,
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 12,
                          height: 1.0,
                          color: numberColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (hasContent)
                Container(
                  key: ValueKey('moments_cal_mark_$key'),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: indicator,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}

/// 选中日椭圆光晕（月历私有，不复用日期对话框的 painter）。
class _SelectedDayHaloPainter extends CustomPainter {
  _SelectedDayHaloPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawOval(rect, fill);
    canvas.drawOval(rect, border);
  }

  @override
  bool shouldRepaint(covariant _SelectedDayHaloPainter oldDelegate) =>
      oldDelegate.color != color;
}
