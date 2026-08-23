# 列表与侧边栏性能证据

## 运行路径

- `features/diary/presentation/diary_list_page.dart:788` 已使用 `ScrollablePositionedList.builder`，列表项本身是惰性构建；主要风险来自玻璃主题下每张 `DiaryCard` 独立执行背景模糊。
- `features/diary/presentation/widgets/diary_card.dart:146` 在玻璃主题中为每张卡片创建 `BackdropFilter`。
- `features/moments/presentation/widgets/moment_card.dart:247` 对所有主题创建 `BackdropFilter`；非玻璃主题把 sigma 设为 `0.001`，但仍保留滤镜 RenderObject 和合成边界。
- `features/moments/presentation/widgets/moments_waterfall.dart:48` 使用 `SingleChildScrollView + Row + Column`，会一次性构建当天全部 `MomentCard`。
- `app/shell/sidebar_widget.dart:40` 在首次构建后延迟 180ms 对整栏 `setState`，并在同一顶层 State 中接收一言结果；两次更新都会重建整个侧边栏。移动端抽屉还会在四个透明主题上执行整栏 20px 背景模糊。

## SDK 证据

- 当前 Flutter SDK 的 `BackdropFilter` 文档明确说明 blur 属于昂贵的非局部滤镜。
- SDK 提供 `BackdropGroup + BackdropFilter.grouped`，用于列表中多个不重叠滤镜共享一次背景采样；官方示例正是 `ListView.builder` 中的多项 blur。
- `RenderBackdropFilter.alwaysNeedsCompositing` 在存在 child 时始终为 true；仅设置 `enabled: false` 仍保留合成需求，因此非玻璃主题应直接绕过 `BackdropFilter` widget，而不是使用接近零的 sigma。

本地依据：

- `E:/environment/flutter/packages/flutter/lib/src/widgets/basic.dart:465`
- `E:/environment/flutter/packages/flutter/lib/src/widgets/basic.dart:507`
- `E:/environment/flutter/packages/flutter/lib/src/widgets/basic.dart:583`
- `E:/environment/flutter/packages/flutter/lib/src/rendering/proxy_box.dart:1325`

## 瀑布流方案验证

- `flutter_staggered_grid_view 0.7.0` 提供 `MasonryGridView.builder`，按需创建可见及缓存范围内的可变高度卡片，同时保持现有瀑布流语义。
- 已在任务目录使用 Flutter 当前 SDK 执行 `flutter pub get --offline` 兼容性探针，依赖解析成功。
- 包 API 参考：https://pub.dev/documentation/flutter_staggered_grid_view/latest/flutter_staggered_grid_view/MasonryGridView-class.html

## 决策

1. 日记列表保留现有定位与月份跳转实现，只把玻璃卡片接入稳定的共享 `BackdropGroup`。
2. 随心记非玻璃主题完全绕过滤镜；玻璃主题接入每个滚动集合自己的 `BackdropGroup`。
3. 桌面随心记使用 `MasonryGridView.builder` 替换 eager 瀑布流，不改列数阈值、间距、排序或卡片外观。
4. 移动端 Drawer 不执行背景 blur；透明主题仍使用现有半透明主题表面、边框和阴影。桌面固定侧边栏继续保留 blur。
5. 一言改由持有单一 Future 的局部 `FutureBuilder` 更新，移除 180ms 延迟状态切换，避免非关键结果重建整栏。

