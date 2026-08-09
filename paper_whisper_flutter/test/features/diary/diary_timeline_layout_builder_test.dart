import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_timeline_layout_builder.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';

/// DiaryTimelineLayoutBuilder 单元测试（阶段 4 L0 第四批）。
///
/// 契约覆盖（逐字保持 `diary_list_page._generateResponsiveLayout`）：
/// - 列数阈值：contentWidth > 1100 → 3，> 700 → 2，其余 1；width > 800 时
///   contentWidth = width - 300（800/800.1、1100/1100.1、1400.1/1401 边界）；
/// - month/entry 混合输入：month 分隔 flush、满列 flush、末尾 flush；
/// - monthTargetMap：`year_month` → units 中 month 单元索引；
/// - itemYearMap：与 units 平行，month 行取 month.year，条目行取首条目
///   dateString 前缀年份（非法 → 0）；
/// - 列内顺序保持输入顺序；空输入无单元无映射、列数仍按宽度计算；
/// - 返回的行内条目列表不可变。
///
/// 纯计算测试，无 Widget / Theme / BuildContext。
void main() {
  DiaryEntryInput entry(String filename, {String dateString = '2023-10-27'}) {
    return DiaryEntryInput(
      DiaryEntry(
        filename: filename,
        dateString: dateString,
        title: '标题 $filename',
      ),
    );
  }

  DiaryMonthInput month(int year, int month) =>
      DiaryMonthInput(year: year, month: month);

  group('响应式列数（contentWidth 逻辑）', () {
    test('width 700 → contentWidth 700 → 1 列', () {
      expect(
        DiaryTimelineLayoutBuilder.build(
          items: const [],
          width: 700,
        ).columnCount,
        1,
      );
    });

    test('width 700.1 → contentWidth 700.1 → 2 列', () {
      expect(
        DiaryTimelineLayoutBuilder.build(
          items: const [],
          width: 700.1,
        ).columnCount,
        2,
      );
    });

    test('width 800 → 不减 300 → contentWidth 800 → 2 列', () {
      expect(
        DiaryTimelineLayoutBuilder.build(
          items: const [],
          width: 800,
        ).columnCount,
        2,
      );
    });

    test('width 800.1 → 减 300 → contentWidth 500.1 → 1 列', () {
      expect(
        DiaryTimelineLayoutBuilder.build(
          items: const [],
          width: 800.1,
        ).columnCount,
        1,
      );
    });

    test('width 1100 → contentWidth 800 → 2 列', () {
      expect(
        DiaryTimelineLayoutBuilder.build(
          items: const [],
          width: 1100,
        ).columnCount,
        2,
      );
    });

    test('width 1100.1 → 减 300 → contentWidth 800.1 → 2 列', () {
      expect(
        DiaryTimelineLayoutBuilder.build(
          items: const [],
          width: 1100.1,
        ).columnCount,
        2,
      );
    });

    test('width 1400.1 → 减 300 → contentWidth 1100.1 → 3 列', () {
      expect(
        DiaryTimelineLayoutBuilder.build(
          items: const [],
          width: 1400.1,
        ).columnCount,
        3,
      );
    });

    test('width 1401 → 减 300 → contentWidth 1101 → 3 列', () {
      expect(
        DiaryTimelineLayoutBuilder.build(
          items: const [],
          width: 1401,
        ).columnCount,
        3,
      );
    });
  });

  group('布局单元与分组', () {
    test('1 列：每条目独立一行', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [entry('e1'), entry('e2')],
        width: 700,
      );
      expect(layout.columnCount, 1);
      expect(layout.units, hasLength(2));
      for (final unit in layout.units) {
        expect((unit as DiaryEntryRowUnit).entries, hasLength(1));
      }
    });

    test('2 列满列 flush 与末尾 flush：3 条目 → 2+1 两行', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [
          entry('e1', dateString: '2023-10-01'),
          entry('e2', dateString: '2023-10-02'),
          entry('e3', dateString: '2023-10-03'),
        ],
        width: 750,
      );
      expect(layout.columnCount, 2);
      expect(layout.units, hasLength(2));
      final row1 = layout.units[0] as DiaryEntryRowUnit;
      final row2 = layout.units[1] as DiaryEntryRowUnit;
      // 列内顺序保持输入顺序
      expect(row1.entries.map((e) => e.filename), ['e1', 'e2']);
      expect(row2.entries.map((e) => e.filename), ['e3']);
      // 行年份取首条目 dateString 前缀
      expect(row1.year, 2023);
      expect(row2.year, 2023);
    });

    test('3 列：5 条目 → 3+2 两行', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [
          entry('e1'),
          entry('e2'),
          entry('e3'),
          entry('e4'),
          entry('e5'),
        ],
        width: 1500,
      );
      expect(layout.columnCount, 3);
      expect(layout.units, hasLength(2));
      expect(
        (layout.units[0] as DiaryEntryRowUnit).entries.map((e) => e.filename),
        ['e1', 'e2', 'e3'],
      );
      expect(
        (layout.units[1] as DiaryEntryRowUnit).entries.map((e) => e.filename),
        ['e4', 'e5'],
      );
    });

    test('month 分隔 flush：month 前条目成行，month 单元紧随', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [
          entry('e1', dateString: '2023-10-01'),
          month(2023, 11),
          entry('e2', dateString: '2023-11-01'),
        ],
        width: 750,
      );
      expect(layout.units, hasLength(3));
      expect(layout.units[0], isA<DiaryEntryRowUnit>());
      expect(
        (layout.units[0] as DiaryEntryRowUnit).entries.map((e) => e.filename),
        ['e1'],
      );
      expect(layout.units[1], isA<DiaryMonthUnit>());
      expect((layout.units[1] as DiaryMonthUnit).year, 2023);
      expect((layout.units[1] as DiaryMonthUnit).month, 11);
      expect(layout.units[2], isA<DiaryEntryRowUnit>());
    });

    test('month 开头不产生空行，索引从 0 开始', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [
          month(2023, 1),
          entry('e1', dateString: '2023-01-05'),
        ],
        width: 700,
      );
      expect(layout.units, hasLength(2));
      expect(layout.monthTargetMap, {'2023_1': 0});
      expect(layout.units[0], isA<DiaryMonthUnit>());
      expect(layout.units[1], isA<DiaryEntryRowUnit>());
    });

    test('monthTargetMap：year_month → units 中 month 单元索引（多个 month）', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [
          entry('e1', dateString: '2023-10-01'),
          month(2023, 10),
          entry('e2', dateString: '2023-10-02'),
          month(2023, 11),
          entry('e3', dateString: '2023-11-01'),
        ],
        width: 750,
      );
      // 2 列：e1 单行 row0；month10 → unit1；e2 单行 row2；month11 → unit3；e3 单行 row4
      expect(layout.monthTargetMap, {'2023_10': 1, '2023_11': 3});
      expect(layout.units, hasLength(5));
      expect((layout.units[1] as DiaryMonthUnit).year, 2023);
      expect((layout.units[1] as DiaryMonthUnit).month, 10);
      expect((layout.units[3] as DiaryMonthUnit).year, 2023);
      expect((layout.units[3] as DiaryMonthUnit).month, 11);
    });

    test('itemYearMap 与 units 平行：month 行用 month.year，条目行用首条目年份', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [
          entry('e1', dateString: '2022-12-31'),
          entry('e2', dateString: '2023-01-01'),
          month(2023, 1),
          entry('e3', dateString: '2023-02-01'),
        ],
        width: 750,
      );
      expect(layout.units, hasLength(3));
      expect(layout.itemYearMap, [2022, 2023, 2023]);
    });

    test('行年份解析：非法 dateString → 0', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [entry('e1', dateString: 'not-a-date')],
        width: 700,
      );
      expect((layout.units.single as DiaryEntryRowUnit).year, 0);
    });
  });

  group('空输入与不可变', () {
    test('空输入：无单元、无映射、列数仍按宽度计算', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: const [],
        width: 1500,
      );
      expect(layout.columnCount, 3);
      expect(layout.units, isEmpty);
      expect(layout.monthTargetMap, isEmpty);
      expect(layout.itemYearMap, isEmpty);
    });

    test('行内条目列表不可变', () {
      final layout = DiaryTimelineLayoutBuilder.build(
        items: [entry('e1'), entry('e2')],
        width: 700,
      );
      final row = layout.units.first as DiaryEntryRowUnit;
      expect(
        () => row.entries.add(
          DiaryEntry(filename: 'x', dateString: '2023-10-27'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
