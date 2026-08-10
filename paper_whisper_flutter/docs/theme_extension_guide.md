# 纸语 PaperWhisper 主题扩展指南

> 本文档总结了新增主题时需要修改的所有代码位置、页面和组件，基于"雨后天空 (After the Rain)"主题的适配经验整理。

---

## 一、核心配置文件

### 1. `lib/config/app_theme.dart`

这是主题系统的**核心枢纽**，所有主题的基础颜色和配置都在此定义。

| 需要修改的内容 | 说明 |
|---|---|
| **主题常量** | 添加新主题的字符串常量，如 `static const themeNewTheme = 'new_theme';` |
| **`getBackground()`** | 定义新主题的背景装饰（渐变、图片等） |
| **`getTextColor()` / `getTextSecondaryColor()`** | 定义主要和次要文字颜色 |
| **`getAccentColor()`** | 定义主题强调色 |
| **`getMobileHeaderColors()`** | 定义移动端顶部栏的颜色配置 |
| **`getSettingsTheme()`** | 定义设置页面的颜色配置（背景、文字、开关颜色等） |
| **`getEditorTheme()`** | 定义编辑器页面的颜色配置（光标、分割线、对话框等） |
| **`getBookDirectoryTheme()`** | 定义书架目录页面的颜色配置 |
| **`getMonthDividerTheme()`** | 定义月份分割线的颜色配置 |
| **`getSearchTheme()`** | 定义搜索栏的颜色配置 |

---

## 二、页面适配清单

### 2.1 日记列表页 (`lib/features/diary/presentation/diary_list_page.dart`)

- **顶部栏 (Header)**：检查 `AppTheme.getMobileHeaderColors()` 是否覆盖新主题。
- **空状态图标/文字**：检查 `_buildEmptyState()` 方法中的颜色判断。
- **下拉刷新动画**：见组件适配部分。

### 2.2 编辑器页面 (`lib/features/editor/presentation/editor_page.dart`)

- **光标颜色**：检查 `_buildHeader()` 和 `_buildContentArea()` 中的 `cursorColor`。
- **装饰线颜色**：检查 `_buildAdaptiveContent()` 中的 `color` 定义。
- **下拉菜单样式**：
  - 背景色：`_buildWeatherSelector()` 和 `_buildMoodSelector()` 中的 `dropdownBg` / `menuBg`。
  - 文字颜色：同上方法中的 `dropdownText` / `menuText`。
- **导出长图样式**：检查 `_buildExportChunks()` 中的 `borderColor`（用于长图顶部/底部的装饰边框）。
- **桌面端顶栏**：检查 `_buildDesktopHeader()` 中的 `iconColor` 和 `textColor`。

### 2.3 设置页面 (`lib/features/settings/presentation/settings_page.dart`)

- **标题阴影**：检查 `titleShadow` 的定义。
- **底部弹窗样式**：检查 `_buildSkeuomorphicBottomSheet()` 和相关方法。
- **开关颜色**：由 `ThemeRegistry.get(theme).settings` 强类型数据统一管理。
- **主题名称显示**：直接读取 `ThemeRegistry.get(theme).name`；展示顺序由设置页显式 ID 列表固定。
- **状态栏适配**：检查 `AppBar` 是否设置了 `systemOverlayStyle`。

### 2.4 数据同步页面 (`lib/features/sync_settings/presentation/sync_settings_page.dart`)

- **按钮样式**：检查 `_buildButton()` 方法中的主题判断。
- **输入框样式**：检查 `_buildTextField()` 方法。
- **加载进度条**：检查 `LinearProgressIndicator` 的 `color` 属性。
- **状态栏适配**：同上。

### 2.5 书架目录页面 (`lib/features/library/presentation/book_directory_page.dart`)

- **标题颜色**：检查 `appBarColor` 的判断逻辑。

### 2.6 回收站页面 (`lib/features/trash/presentation/trash_page.dart`)

- **列表项颜色**：检查 `_buildTrashItem()` 中对不同主题的适配。
- **状态栏适配**：同上。

### 2.7 专注写作页面 (`lib/pages/focus_writing_page.dart`)

- **遮罩透明度**：检查 Scrim 的颜色和透明度设置。

### 2.8 随心记页面 (`lib/features/moments/presentation/moments_page.dart`)

- **顶栏背景**：检查 `AppBar` 的 `backgroundColor`。
- **标尺颜色**：检查 `RulerDatePicker` 的输入是否来自 `ThemeRegistry.get(theme).moments`。
- **输入框组件**：见组件适配部分 `MomentInputWidget`。

---

## 三、组件适配清单

### 3.1 纸张组件 (`lib/features/editor/presentation/widgets/paper_sheet_widget.dart`)

- **书签/丝带颜色**：在 `build()` 方法中添加新主题的分支。

### 3.2 日期选择器 (`lib/shared/widgets/skeuomorphic_date_picker.dart`)

- **整体配色**：`dialogBg`, `headerBg`, `accentColor` 等。

### 3.3 搜索栏 (`lib/shared/widgets/skeuomorphic_search_bar.dart`)

- **背景/边框**：检查 `build()` 中的颜色定义。
- **图标与光标**：确保 `iconColor` 和 `cursorColor` 使用了主题强调色（如 Musubi Red）。
- **内发光 (Glow)**：检查 `Stack` 中对于 `gradient` 的定义，确保发光颜色与主题匹配。

### 3.4 下拉刷新 (`lib/features/diary/presentation/widgets/book_flip_refresh_widget.dart`)

- **书本动画颜色**：`bookColor`, `pageColor`, `textColor`。

### 3.5 月份分割线 (`lib/features/diary/presentation/widgets/month_divider.dart`)

- **颜色配置**：`ThemeRegistry.get(theme).monthDivider`。

### 3.6 对话框 (`lib/shared/widgets/skeuomorphic_dialog.dart`)

- **背景/按钮颜色**：检查 `build()` 中的颜色判断。

### 3.7 过渡动画 (`lib/app/navigation/route_transitions.dart`)

- **信纸颜色**：`_getThemeColors()` 中的 `_LetterColors` 配置（信纸背景、折痕、阴影）。

### 3.8 随心记输入框 (`lib/features/moments/presentation/widgets/moment_input_widget.dart`)

- **容器背景**：检查 `containerColor`。
- **输入框样式**：检查 `inputBgColor`, `inputBorderColor`。
- **图标颜色**：特别注意 **图库图标 (`imageIconColor`)** 和 **发送按钮 (`sendColor`)** 是否需要适配主题强调色。
- **阴影颜色**：检查 `boxShadows` 中的颜色，避免使用与主题冲突的色调（如紫色主题配青色阴影）。

---

## 四、新增主题标准流程

1.  **资源准备**：如果需要，将背景图放入 `assets/textures/`。
2.  **定义主题**：在 `config/theme/themes/` 创建完整的 `PaperWhisperTheme`，填写 ID、名称、描述及全部 typed 组件字段。
3.  **注册主题**：在 `ThemeRegistry.init()` 中按预期展示/回归顺序注册。
4.  **兼容判断**：仅当现有视觉分支仍依赖主题 ID 时，在 `AppTheme` 添加对应常量；不得新增 Map 门面。
5.  **测试与视觉验收**：更新主题 ID/顺序测试，并重点检查光标、图标、阴影和边框。

---

## 五、常用颜色变量命名建议

| 变量名 | 用途 |
|---|---|
| `paperColor` / `bgColor` | 主背景/纸张颜色 |
| `textColor` / `inkColor` | 主文字颜色 |
| `secondaryColor` / `hintColor` | 次要文字/提示颜色 |
| `accentColor` | 强调色（按钮、高亮、书签） |
| `borderColor` | 边框颜色 |
| `shadowColor` | 阴影颜色 |

---

## 六、附录：本次适配涉及的文件列表

```
lib/config/app_theme.dart
lib/features/diary/presentation/diary_list_page.dart
lib/features/editor/presentation/editor_page.dart
lib/features/settings/presentation/settings_page.dart
lib/features/sync_settings/presentation/sync_settings_page.dart
lib/features/library/presentation/book_directory_page.dart
lib/pages/focus_writing_page.dart
lib/features/moments/presentation/moments_page.dart
lib/features/editor/presentation/widgets/paper_sheet_widget.dart
lib/shared/widgets/skeuomorphic_date_picker.dart
lib/shared/widgets/skeuomorphic_search_bar.dart
lib/features/diary/presentation/widgets/book_flip_refresh_widget.dart
lib/features/diary/presentation/widgets/month_divider.dart
lib/shared/widgets/skeuomorphic_dialog.dart
lib/app/navigation/route_transitions.dart
lib/features/moments/presentation/widgets/moment_input_widget.dart
assets/textures/
```
