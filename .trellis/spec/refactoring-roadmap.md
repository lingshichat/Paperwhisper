# 代码规范化重构计划 (Refactoring Roadmap)

> 记录按 Trellis Spec 规范化 PaperWhisper 项目代码的进度与后续规划。

---

## 📅 当期目标

消除项目中违反代码规范（特别是视觉和架构规范）的实现，重点解决：
1. `print()` 被错误使用于日志记录。
2. 基础 Material 等级控件 (`ElevatedButton`等) 未进行拟物化封装。
3. **严重问题**：分散在各个 Widget 中的硬编码颜色，尤其是 `isSeaFlower ? ... : ...` 嵌套三元运算符判断主题，阻碍了未来新主题的扩展。

---

## 🧹 阶段 1：废弃代码清理与低风险重构（✅ 已完成）

- [x] 删除 PyFlask 时代残留目录 (`legacy_desktop/`, `dist/`, `.venv/` 等)
- [x] 删除旧版测试数据 (`diary_data/`)
- [x] 移除已弃用的画廊页面 (`gallery_page.dart`)
- [x] **日志规范化**：将 `update_service.dart`, `storage_service.dart`, `auth_service.dart` 中的 `print()` 替换为 `debugPrint()`

---

## 🎨 阶段 2：重灾区页面硬编码颜色收敛（✅ 已完成）

- [x] **扩展 AppTheme**: 在 `app_theme.dart` 中新增 `getTrashPageTheme` 和 `getSyncSettingsTheme`，向页面层暴露统一的动态颜色字典。
- [x] **重写回收站页面** (`trash_page.dart`): 移除了 20+ 处嵌套硬编码颜色，代码量减半，组件纯粹化。
- [x] **重写同步设置** (`sync_settings_page.dart`): 移除了 50+ 处基于 `isSeaFlower/isMidnight/isTwilight/isGardenOfWords` 的三元条件分支颜色选择器，重构了自定义拟物化滑块与输入框的样式表。

---

## 🛠 阶段 3：其他页面逐步收敛与组件替换（✅ 已完成）

### P0: 全局冗余清理（✅ 已完成）
- [x] 清理全部 `flutter analyze` warnings（68 处：44 unused imports、7 unused elements、6 unused fields、6 unused variables、4 unreachable defaults、1 duplicate import）
- [x] `getDialogInputTheme()` 从 if-else 转为 switch 语句，消除 theme boolean 残留
- [x] `moment_input_widget.dart` 底栏按钮去除 Container+Border 外框，恢复纯图标拟物风格

### P1: 高优页面样式收敛（✅ 已完成）
- [x] `settings_page.dart`: 已统一读取 `ThemeRegistry` typed component data，无动态 Map 或散落主题判断。

### P2: 独立组件样式收敛（✅ 已完成）
- [x] `security_settings_page.dart`: 无硬编码主题判断
- [x] `moment_card.dart`: 无硬编码主题判断
- [x] `moment_input_widget.dart`（底栏按钮已修复）

### P3: 低风险/边缘组件清理（✅ 已完成）
- [x] `skeuomorphic_date_picker.dart`: 无硬编码主题判断
- [x] `paper_sheet_widget.dart`: 无硬编码主题判断
- [x] `book_flip_refresh_widget.dart`: 无硬编码主题判断

### P4: 控件降级替换（✅ 已完成）
- [x] 全局无 `ElevatedButton`、`TextButton`、`TextButton.icon` 残留，Material 标准按钮已全部替换为拟物化自定义按钮。

---

## 🧭 2026 架构可维护性重构

| 阶段 | 状态 | 已建立的边界与质量证据 |
|---|---|---|
| 质量基线 | ✅ 完成 | `flutter analyze` 0 issue、资源释放与双平台基础 smoke |
| 同步域 | ✅ 完成 | context-free `SyncProvider`、`features/sync/`、共享 Service 所有权、跨实例 Manifest 串行写入 |
| 编辑器 | ✅ 完成 | `editor_page.dart` 约 1650→581 行；Session/Save/Export/Presentation 边界；编辑器 115 项、完整 324 项测试 |
| 页面协调器 | ✅ 完成 | 横切职责收敛：UpdateCheck/Permission/SaveSync/ExportPathResolver/SyncStatusFormatter；Settings 1521→944、Moments 1248→907、DiaryList 1257→881、SyncSettings 1140→764、Editor 581 行；新控制器/协调器不持有 BuildContext；`flutter analyze` 0 issue、完整 765 项测试全绿、14 个文件双平台 widget smoke |
| 目标架构 | ✅ 完成 | `app/core/features/shared` 落地；AppRoutes 集中导航；动态主题 facade、主题 `toMap()`/强转归零；`main.dart` 3 行；依赖方向静态检查全 0；完整 815 项测试；7 主题 × 2 平台 × 3 页面共 42 张视觉截图通过 |

五阶段已全部完成。后续功能必须在现有边界内演进，不再恢复旧 layer-first 目录或动态主题兼容层。不得重新把 BuildContext、文件 I/O、平台插件、Timer 或跨功能保存策略塞回 Provider/大型页面。

---

## 📌 验收规则

任何人认领推进上述 Phase 3 任务时，必须遵守以下约定：
1. **Widget 只读 typed theme data。** 通过 `AppTheme.themeIdOf(context)` 与 `ThemeRegistry.get(id).component` 取值，不新增主题 Map、运行时强转或散装主题分支。
2. 修改完成后，在 Windows 与 Android 检查全部 7 种主题；主题/布局变更还需保留可重复的 widget smoke 或截图证据。
3. 提交前运行全仓 format check、`flutter analyze` 和完整 `flutter test`，三者都必须通过。
4. core/shared/data/application 的反向依赖、navigation 外 Route 构造和旧 layer import 必须保持 0；具体命令见 `frontend/architecture-boundaries.md`。
