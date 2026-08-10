import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_list_filter.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';

/// DiaryListFilter 单元测试（阶段 4 Wave B1）。
///
/// 契约覆盖（逐字保持 `diary_list_page._buildContentArea` 搜索语义）：
/// - 标题 / 正文 / 日期字符串 contains 匹配（区分大小写，与旧实现一致）；
/// - 无命中 → 空列表；空查询 → 原列表（页面在查询非空时才调用）；
/// - 多命中保持输入顺序。
void main() {
  final entries = <DiaryEntry>[
    DiaryEntry(
      filename: '2026-05-01_apple.txt',
      dateString: '2026-05-01',
      title: '苹果的回忆',
      content: '今天吃了苹果。',
    ),
    DiaryEntry(
      filename: '2026-05-02_banana.txt',
      dateString: '2026-05-02',
      title: '香蕉的回忆',
      content: '今天吃了香蕉。',
    ),
    DiaryEntry(
      filename: '2026-05-03_notes.txt',
      dateString: '2026-05-03',
      title: '工作笔记',
      content: '五月三日，整理季度计划。',
    ),
  ];

  List<String> titles(List<DiaryEntry> result) =>
      result.map((e) => e.title).toList();

  test('标题命中', () {
    expect(titles(DiaryListFilter.filter(entries: entries, query: '苹果')), [
      '苹果的回忆',
    ]);
  });

  test('正文命中', () {
    expect(titles(DiaryListFilter.filter(entries: entries, query: '香蕉')), [
      '香蕉的回忆',
    ]);
  });

  test('日期字符串命中', () {
    expect(
      titles(DiaryListFilter.filter(entries: entries, query: '2026-05-03')),
      ['工作笔记'],
    );
  });

  test('无命中返回空列表', () {
    expect(DiaryListFilter.filter(entries: entries, query: '不存在的关键词'), isEmpty);
  });

  test('空查询返回原列表', () {
    expect(DiaryListFilter.filter(entries: entries, query: ''), same(entries));
  });

  test('区分大小写（与旧实现一致）', () {
    expect(
      DiaryListFilter.filter(
        entries: [
          DiaryEntry(
            filename: 'a.txt',
            dateString: '2026-05-01',
            title: 'Apple',
            content: 'x',
          ),
        ],
        query: 'apple',
      ),
      isEmpty,
    );
  });

  test('多命中保持输入顺序', () {
    expect(titles(DiaryListFilter.filter(entries: entries, query: '2026-05')), [
      '苹果的回忆',
      '香蕉的回忆',
      '工作笔记',
    ]);
  });
}
