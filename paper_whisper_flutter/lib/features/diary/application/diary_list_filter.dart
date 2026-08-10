import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';

/// 日记列表搜索过滤（纯函数）。
///
/// 逐字保持 `diary_list_page._buildContentArea` 的搜索语义：
/// 对标题 / 正文 / 日期字符串做 `contains` 匹配（区分大小写，
/// 与旧实现一致）。空查询返回原列表（页面在查询非空时才调用）。
abstract final class DiaryListFilter {
  /// 按 [query] 过滤日记。
  ///
  /// 空查询直接返回 [entries]（无过滤）；否则保留标题、正文或
  /// 日期字符串包含查询词的条目，顺序不变。
  static List<DiaryEntry> filter({
    required List<DiaryEntry> entries,
    required String query,
  }) {
    if (query.isEmpty) return entries;
    return entries
        .where(
          (e) =>
              e.title.contains(query) ||
              e.content.contains(query) ||
              e.dateString.contains(query),
        )
        .toList();
  }
}
