import '../../../models/diary_entry.dart';

/// 时间线输入节点（最小 feature model，供页面扁平列表适配）。
///
/// 页面把现有扁平列表（`MonthHeader` / `DiaryEntry` 混合）转换为
/// [DiaryMonthInput] / [DiaryEntryInput] 后交给
/// [DiaryTimelineLayoutBuilder.build]，避免 application 层反向依赖
/// provider 层。
sealed class DiaryTimelineInput {
  const DiaryTimelineInput();
}

/// 月份分隔输入（对应页面 `MonthHeader`）。
class DiaryMonthInput extends DiaryTimelineInput {
  const DiaryMonthInput({required this.year, required this.month});

  final int year;
  final int month;
}

/// 日记条目输入（对应 `DiaryEntry`）。
class DiaryEntryInput extends DiaryTimelineInput {
  const DiaryEntryInput(this.entry);

  final DiaryEntry entry;
}

/// 时间线布局单元（typed plan，不含任何 Widget）。
sealed class DiaryTimelineUnit {
  const DiaryTimelineUnit();
}

/// 月份分隔单元（页面渲染为 MonthDivider）。
class DiaryMonthUnit extends DiaryTimelineUnit {
  const DiaryMonthUnit({required this.year, required this.month});

  final int year;
  final int month;
}

/// 日记条目行单元（页面渲染为一行 DiaryCard，行内 ≤ [DiaryTimelineLayout.columnCount] 个）。
class DiaryEntryRowUnit extends DiaryTimelineUnit {
  const DiaryEntryRowUnit({required this.entries, required this.year});

  /// 该行条目（有序，不超过列数）。
  final List<DiaryEntry> entries;

  /// 行年份（取首条目年份，与原 `flushBuffer` 逻辑一致）。
  final int year;
}

/// 时间线布局计算结果（纯数据，不含 Widget / Theme / BuildContext）。
class DiaryTimelineLayout {
  const DiaryTimelineLayout({
    required this.columnCount,
    required this.units,
    required this.monthTargetMap,
    required this.itemYearMap,
  });

  /// 响应式列数：contentWidth > 1100 → 3；> 700 → 2；其余 1。
  final int columnCount;

  /// 有序布局单元（与页面 `_uiItems` 顺序一一对应）。
  final List<DiaryTimelineUnit> units;

  /// `year_month` → units 索引（对应页面 `_monthTargetMap`）。
  final Map<String, int> monthTargetMap;

  /// 与 [units] 平行的年份表（对应页面 `_itemYearMap`）。
  final List<int> itemYearMap;
}

/// 日记时间线响应式布局纯计算。
///
/// 职责边界：
/// - 输入纯数据节点，输出 typed plan / map，不产生 Widget；
/// - 不依赖 Theme / BuildContext / Provider；
/// - 列数阈值与分组规则逐字保持 `diary_list_page._generateResponsiveLayout`。
///
/// 页面侧适配（接线时）：
/// ```dart
/// final inputs = rawItems.map((e) => e is MonthHeader
///     ? DiaryMonthInput(year: e.year, month: e.month)
///     : DiaryEntryInput(e as DiaryEntry)).toList();
/// final layout = DiaryTimelineLayoutBuilder.build(items: inputs, width: w);
///
/// // MonthDivider 标题由页面适配层调用 DiaryProvider.getMonthTitle 构建；
/// // plan 只负责位置与年份，不持有文案或 Provider 依赖。
/// ```
abstract final class DiaryTimelineLayoutBuilder {

  /// 计算时间线布局。
  static DiaryTimelineLayout build({
    required List<DiaryTimelineInput> items,
    required double width,
  }) {
    final units = <DiaryTimelineUnit>[];
    final monthTargetMap = <String, int>{};
    final itemYearMap = <int>[];

    double contentWidth = width;
    if (width > 800) {
      contentWidth -= 300;
    }

    int columnCount = 1;
    if (contentWidth > 1100) {
      columnCount = 3;
    } else if (contentWidth > 700) {
      columnCount = 2;
    }

    final buffer = <DiaryEntry>[];

    // 行年份取首条目年份（与原 flushBuffer 一致）。
    void flushBuffer() {
      if (buffer.isNotEmpty) {
        int rowYear = 0;
        final parts = buffer.first.dateString.split('-');
        if (parts.isNotEmpty) rowYear = int.tryParse(parts[0]) ?? 0;

        units.add(
          DiaryEntryRowUnit(entries: List.unmodifiable(buffer), year: rowYear),
        );
        itemYearMap.add(rowYear);
        buffer.clear();
      }
    }

    for (final item in items) {
      switch (item) {
        case DiaryMonthInput(:final year, :final month):
          flushBuffer();
          monthTargetMap['${year}_$month'] = units.length;
          units.add(DiaryMonthUnit(year: year, month: month));
          itemYearMap.add(year);
        case DiaryEntryInput(:final entry):
          buffer.add(entry);
          if (buffer.length == columnCount) flushBuffer();
      }
    }
    flushBuffer();

    return DiaryTimelineLayout(
      columnCount: columnCount,
      units: units,
      monthTargetMap: monthTargetMap,
      itemYearMap: itemYearMap,
    );
  }
}
