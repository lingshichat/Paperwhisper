import '../../../models/moment.dart';

/// 随心记按天索引（不可变视图）。
///
/// 由 [MomentIndex.build] 从原始列表一次性构建，构建后输入列表不再被
/// 引用或修改；对外暴露的均为只读 Map / List。
///
/// 排序规则（与 `moments_page._MomentLookupCache` 逐字一致）：
/// - [latestMoments]：按创建时间降序（最新在前）；
/// - [momentsByDay]：按天分组，组内按创建时间升序；
/// - [imageCountByDay]：每天图片总数。
///
/// 不持有 service / BuildContext，纯内存索引。
class MomentIndex {
  MomentIndex._({
    required this.latestMoments,
    required this.momentsByDay,
    required this.imageCountByDay,
  });

  /// 全部随心记，按创建时间降序（最新在前）。
  final List<Moment> latestMoments;

  /// 按天分组：key 为 `yyyy-M-d`，组内按创建时间升序。
  final Map<String, List<Moment>> momentsByDay;

  /// 每天图片总数：key 为 `yyyy-M-d`。
  final Map<String, int> imageCountByDay;

  /// 构建索引。输入列表不会被修改；输出为只读视图。
  factory MomentIndex.build(List<Moment> moments) {
    final latestMoments = List<Moment>.from(moments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final momentsByDay = <String, List<Moment>>{};
    final imageCountByDay = <String, int>{};

    for (final moment in moments) {
      final key = _dayKey(moment.createdAt);
      momentsByDay.putIfAbsent(key, () => <Moment>[]).add(moment);
      imageCountByDay[key] = (imageCountByDay[key] ?? 0) + moment.images.length;
    }

    for (final dailyMoments in momentsByDay.values) {
      dailyMoments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return MomentIndex._(
      latestMoments: List.unmodifiable(latestMoments),
      momentsByDay: Map.unmodifiable(
        momentsByDay.map(
          (key, value) => MapEntry(key, List.unmodifiable(value)),
        ),
      ),
      imageCountByDay: Map.unmodifiable(imageCountByDay),
    );
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  /// 指定日期的随心记列表（无则返回空列表）。
  List<Moment> momentsForDate(DateTime date) {
    return momentsByDay[_dayKey(date)] ?? const [];
  }

  /// 指定日期的图片总数（无则返回 0）。
  int imageCountForDate(DateTime date) {
    return imageCountByDay[_dayKey(date)] ?? 0;
  }
}
