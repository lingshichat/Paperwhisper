# 技术设计

## 边界

性能问题实际位于 presentation 渲染树，不涉及 Provider、存储或业务模型。本次只调整共享侧边栏、两类卡片及其滚动容器；数据加载、排序来源、导航回调和主题字段保持不变。

## 1. 侧边栏首开

### 当前链路

`Scaffold.drawer -> SidebarWidget.initState -> postFrame -> 180ms delay -> 顶层 setState -> BackdropFilter`。一言结果也通过同一个 State 的 `setState` 重建整栏。抽屉首次可见时还需绘制整屏高的移动背景滤镜。

### 调整

- 删除 `_hasPrimedFirstSidebarFrame`、`_enableBackdropBlur` 和 180ms 调度。
- 在 `initState` 只创建一次 `Future<HitokotoLine?>`；一言区域使用局部 `FutureBuilder`，结果完成只重建该子树。
- `isInDrawer == true` 时不包裹 `BackdropFilter`。四个透明主题继续使用现有半透明 `bgDecoration`、边框和阴影；桌面固定侧边栏仍保留 20px blur。

这消除了抽屉动画中的动态滤镜状态切换和非关键网络结果造成的整栏重建，不新增状态管理层。

## 2. 列表背景滤镜

当前 SDK 原生支持 `BackdropGroup + BackdropFilter.grouped`。列表中不重叠的卡片可共享同一背景输入，Flutter Engine 只执行一次背景采样。

- `DiaryCard` 的玻璃分支改用 `BackdropFilter.grouped`；`ScrollablePositionedList` 外设置稳定 `BackdropGroup`。
- `MomentCard` 拆分玻璃/非玻璃渲染分支。非玻璃分支完全不创建滤镜 widget；玻璃分支使用 `BackdropFilter.grouped`。
- 随心记移动端每日列表、搜索结果列表、桌面瀑布流分别建立自己的 `BackdropGroup`。不同 PageView 页面不共享 key，避免横向切页时重叠滤镜错误合并。

卡片间已有水平和垂直间距，海底花海主题 1.02 的 hover scale 也不足以跨越间距，因此同组滤镜不重叠。

## 3. 桌面随心记瀑布流

引入 `flutter_staggered_grid_view: ^0.7.0`，将 eager 的 `SingleChildScrollView + Column` 替换为 `MasonryGridView.count` 的 builder 路径：

- `itemCount` 与 `itemBuilder` 保证只构建可见及缓存范围内卡片。
- 继续按 `createdAt` 降序传入，保持最新在前。
- 宽度阈值保持 `>1200 -> 3`、`>750 -> 2`、其余 1。
- 保持 24px 主轴/交叉轴间距及原外边距。
- 标准 masonry 采用“当前最短列优先”，替代旧的 round-robin 分列；这是实现可变高度惰性布局所需的局部布局变化，卡片样式和阅读顺序不变。

依赖已用当前 Flutter SDK 离线解析成功；当前 Flutter SDK 根 `pubspec.yaml` 也固定使用 0.7.0。

## 兼容性与风险

- 无数据迁移、持久化或公开业务接口变化。
- 移动端透明抽屉不再模糊其后方内容，半透明表面视觉仍保留；这是以最小视觉代价换取稳定开启动画的明确取舍。
- 惰性瀑布流会释放远离视口且未请求 keep-alive 的卡片，行为与现有移动端列表一致，能同步释放图片和音频控制器资源。
- `BackdropGroup` 只包围各自滚动集合，避免 PageView 邻页或 Hero overlay 共享错误的 key。

## 回滚

三部分互不依赖，可分别回滚：侧边栏状态；卡片滤镜分组；瀑布流依赖与 widget。没有数据库或文件格式回滚步骤。
