# 实施计划

## 修改顺序

1. 增加结构性性能测试：侧边栏 Drawer blur 边界、日记/随心记卡片滤镜分支与共享 key、桌面瀑布流首屏惰性构建及滚动可达。
2. 重构 `SidebarWidget`：删除延迟顶层状态，使用单一 Future + 局部 `FutureBuilder`，移动 Drawer 绕过 blur。
3. 为日记时间线添加稳定 `BackdropGroup`，将玻璃 `DiaryCard` 接入 grouped filter。
4. 为随心记三个滚动入口添加独立 `BackdropGroup`，让 `MomentCard` 非玻璃分支完全绕过滤镜。
5. 添加 `flutter_staggered_grid_view` 依赖，将桌面 `MomentsWaterfall` 改为 builder masonry，并保持列数、排序、间距、删除回调。
6. 更新受 180ms Sidebar timer 影响的测试 helper 注释与无效等待。

## 预计文件

- `paper_whisper_flutter/pubspec.yaml` / `pubspec.lock`：瀑布流依赖。
- `lib/app/shell/sidebar_widget.dart`：首次展开与一言重建边界。
- `lib/features/diary/presentation/diary_list_page.dart`：日记 BackdropGroup。
- `lib/features/diary/presentation/widgets/diary_card.dart`：grouped filter。
- `lib/features/moments/presentation/moments_page.dart`：移动每日列表分组。
- `lib/features/moments/presentation/widgets/moments_search_results.dart`：搜索列表分组。
- `lib/features/moments/presentation/widgets/moments_waterfall.dart`：惰性 masonry。
- `lib/features/moments/presentation/widgets/moment_card.dart`：玻璃/非玻璃分支。
- `test/widgets/`、`test/pages/`：结构约束与既有行为回归。

## 验证

```bash
dart format <本次修改的 Dart 文件>
flutter test test/widgets/sidebar_widget_test.dart
flutter test test/widgets/diary_card_test.dart
flutter test test/widgets/moment_card_test.dart
flutter test test/widgets/moments_waterfall_test.dart
flutter test test/pages/diary_list_page_test.dart test/pages/moments_page_test.dart
flutter analyze
flutter test
```

额外审查 `git diff --check`、依赖锁文件变化和首屏 widget 数断言。真实设备帧时间需在 Android profile 模式做最终体感确认，不以 debug 模式帧率作为结论。

## 回滚点

- 每完成侧边栏、滤镜分组、瀑布流三个批次后分别检查 diff 与聚焦测试。
- 若 masonry 在当前平台出现布局回归，只回滚第 5 步及依赖，不影响另外两项性能修复。
