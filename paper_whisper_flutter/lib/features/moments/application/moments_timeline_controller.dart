import 'package:flutter/widgets.dart';

/// 随心记时间线控制器（context-free）。
///
/// 持有日期状态机与 Page/Ruler 双向同步的纯逻辑，不持有 BuildContext：
/// - 起点日期（`today - 5 年`）、选中日期与 3650 天覆盖范围；
/// - 日期 ↔ 时间线索引、尺子偏移（70 单位）↔ 页索引换算；
/// - Ruler/Page 互斥来源决策（原 `_isRulerActive` / `_isPageActive`）；
/// - PageController / FixedExtentScrollController 的创建与释放。
///
/// 页面保留 Widget NotificationListener 与全部 UI：滚动通知只把
/// 互斥判断与偏移换算委托给本控制器，跳转动作仍由页面在控制器上执行。
class MomentsTimelineController {
  MomentsTimelineController({DateTime? initialDate, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 365 * 5));
    _selectedDate = _normalize(initialDate ?? now);

    final initialIndex = indexForDate(_selectedDate);
    pageController = PageController(initialPage: initialIndex);
    rulerController = FixedExtentScrollController(initialItem: initialIndex);
  }

  final DateTime Function() _clock;

  /// 尺子每项高度（原 `offset / 70.0` 中的 70 单位）。
  static const double rulerItemExtent = 70.0;

  /// 时间线覆盖天数（原 `_dayRange = 3650`）。
  static const int dayRange = 3650;

  late final DateTime _startDate;
  late DateTime _selectedDate;

  // Ruler/Page 互斥标记（原 `_isRulerActive` / `_isPageActive`），防止
  // 一方滚动驱动另一方跳转时产生回环通知。
  bool _isRulerActive = false;
  bool _isPageActive = false;

  /// 页面控制器（页面负责 animateToPage / jumpTo，生命周期归本控制器）。
  late final PageController pageController;

  /// 尺子滚动控制器（生命周期归本控制器）。
  late final FixedExtentScrollController rulerController;

  /// 起点日期（今天 - 5 年，归一化到当日零点）。
  DateTime get startDate => _startDate;

  /// 当前选中日期（已归一化到当日零点）。
  DateTime get selectedDate => _selectedDate;

  bool get isRulerActive => _isRulerActive;
  bool get isPageActive => _isPageActive;

  static DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 日期 → 时间线索引（早于起点时钳制为 0，与原 `_initDates` 一致）。
  int indexForDate(DateTime date) {
    final index = _normalize(date).difference(_startDate).inDays;
    return index < 0 ? 0 : index;
  }

  /// 时间线索引 → 日期（原 `_startDate.add(Duration(days: index))`）。
  DateTime dateForIndex(int index) => _startDate.add(Duration(days: index));

  /// 尺子偏移 → 页索引（原 `rulerOffset / 70.0`）。
  double pageForRulerOffset(double rulerOffset) =>
      rulerOffset / rulerItemExtent;

  /// 页索引 → 尺子偏移（原 `page * 70.0`）。
  double rulerOffsetForPage(double page) => page * rulerItemExtent;

  /// 是否为同一天（忽略时间分量）。
  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 选中日期（页面在 setState 内调用，归一化到当日零点）。
  void selectDate(DateTime date) => _selectedDate = _normalize(date);

  /// Ruler 滚动更新：若 Page 正在滚动则忽略本次通知，否则标记 Ruler
  /// 为活跃来源并继续处理。返回是否应继续同步另一侧。
  bool shouldProcessRulerScroll() {
    if (_isPageActive) return false;
    _isRulerActive = true;
    return true;
  }

  /// Ruler 滚动结束。
  void rulerScrollEnded() => _isRulerActive = false;

  /// Page 滚动更新：若 Ruler 正在滚动则忽略本次通知，否则标记 Page
  /// 为活跃来源并继续处理。返回是否应继续同步另一侧。
  bool shouldProcessPageScroll() {
    if (_isRulerActive) return false;
    _isPageActive = true;
    return true;
  }

  /// Page 滚动结束（页面随后在 `!isRulerActive` 时做日期吸附同步）。
  void pageScrollEnded() => _isPageActive = false;

  /// 释放两个滚动控制器（页面 dispose 时调用）。
  void dispose() {
    pageController.dispose();
    rulerController.dispose();
  }
}
