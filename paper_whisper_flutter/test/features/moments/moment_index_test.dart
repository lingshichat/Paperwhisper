import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/moments/application/moment_index.dart';
import 'package:paper_whisper_flutter/models/moment.dart';

/// MomentIndex 单元测试（阶段 4 L0 第三批）。
///
/// 契约覆盖（与 `moments_page._MomentLookupCache` 逐字一致）：
/// - build 不修改输入列表（顺序与元素不变）；
/// - latestMoments 按创建时间降序（最新在前）；
/// - momentsByDay 按天分组、组内升序、day key 未补零（yyyy-M-d）；
/// - imageCountByDay 每天图片数累计，imageCountForDate 缺省返回 0；
/// - momentsForDate 缺省日期返回空列表；
/// - 全部输出不可变：latest / byDay / 组内列表 / imageCount 修改均抛错，
///   缺省查询返回的空列表亦不可变。
///
/// 纯内存索引测试，无 I/O、无插件。
void main() {
  Moment moment(
    String uuid,
    DateTime createdAt, {
    List<String> images = const [],
  }) {
    return Moment(
      uuid: uuid,
      content: '内容 $uuid',
      images: images,
      createdAt: createdAt,
    );
  }

  group('MomentIndex.build', () {
    test('输入列表不被修改（顺序与元素保持）', () {
      final input = [
        moment('b', DateTime(2026, 3, 5, 10, 0)),
        moment('a', DateTime(2026, 3, 5, 9, 0)),
      ];
      final before = input.map((m) => m.uuid).toList();

      MomentIndex.build(input);

      expect(input.map((m) => m.uuid), before);
      expect(input.map((m) => m.uuid), ['b', 'a']);
    });

    test('空输入 → 空索引', () {
      final index = MomentIndex.build(const []);
      expect(index.latestMoments, isEmpty);
      expect(index.momentsByDay, isEmpty);
      expect(index.imageCountByDay, isEmpty);
    });

    test('latestMoments 按创建时间降序（最新在前）', () {
      final index = MomentIndex.build([
        moment('old', DateTime(2026, 3, 5, 8, 0)),
        moment('mid', DateTime(2026, 3, 5, 12, 0)),
        moment('new', DateTime(2026, 3, 6, 9, 0)),
      ]);
      expect(index.latestMoments.map((m) => m.uuid), ['new', 'mid', 'old']);
    });

    test('momentsByDay 按天分组、组内升序、key 未补零', () {
      final index = MomentIndex.build([
        moment('a', DateTime(2026, 3, 5, 9, 0)),
        moment('b', DateTime(2026, 3, 5, 10, 0)),
        moment('c', DateTime(2026, 3, 12, 8, 0)),
        moment('d', DateTime(2026, 11, 3, 7, 0)),
      ]);
      expect(index.momentsByDay.keys, ['2026-3-5', '2026-3-12', '2026-11-3']);
      expect(index.momentsByDay['2026-3-5']!.map((m) => m.uuid), ['a', 'b']);
      expect(index.momentsByDay['2026-3-12']!.map((m) => m.uuid), ['c']);
      expect(index.momentsByDay['2026-11-3']!.map((m) => m.uuid), ['d']);
    });

    test('imageCountByDay 每天图片数累计', () {
      final index = MomentIndex.build([
        moment('a', DateTime(2026, 3, 5, 9, 0), images: ['i1', 'i2']),
        moment('b', DateTime(2026, 3, 5, 10, 0), images: ['i3']),
        moment('c', DateTime(2026, 3, 6, 9, 0)),
      ]);
      expect(index.imageCountByDay['2026-3-5'], 3);
      expect(index.imageCountByDay['2026-3-6'], 0);
      expect(index.imageCountForDate(DateTime(2026, 3, 5)), 3);
      expect(index.imageCountForDate(DateTime(2026, 3, 6)), 0);
    });

    test('momentsForDate 未补零 key 命中；缺省日期返回空列表', () {
      final index = MomentIndex.build([
        moment('a', DateTime(2026, 3, 5, 9, 0)),
        moment('b', DateTime(2026, 3, 12, 9, 0)),
      ]);
      expect(index.momentsForDate(DateTime(2026, 3, 5)).map((m) => m.uuid), [
        'a',
      ]);
      expect(index.momentsForDate(DateTime(2026, 3, 12)).map((m) => m.uuid), [
        'b',
      ]);
      expect(index.momentsForDate(DateTime(2026, 1, 1)), isEmpty);
    });
  });

  group('输出不可变', () {
    test('latest / byDay / 组内列表 / imageCount 修改均抛错', () {
      final index = MomentIndex.build([
        moment('a', DateTime(2026, 3, 5, 9, 0), images: ['i1']),
      ]);
      final extra = moment('x', DateTime(2026, 1, 1));

      expect(() => index.latestMoments.add(extra), throwsUnsupportedError);
      expect(
        () => index.momentsByDay['2026-3-5']!.add(extra),
        throwsUnsupportedError,
      );
      expect(() => index.momentsByDay['2099-1-1'] = [], throwsUnsupportedError);
      expect(
        () => index.imageCountByDay['2099-1-1'] = 5,
        throwsUnsupportedError,
      );
      // 缺省日期查询返回的空列表同样不可变
      expect(
        () => index.momentsForDate(DateTime(2099, 1, 1)).add(extra),
        throwsUnsupportedError,
      );
    });
  });
}
