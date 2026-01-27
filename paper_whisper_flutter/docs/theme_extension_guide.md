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

### 2.1 日记列表页 (`lib/pages/diary_list_page.dart`)

- **顶部栏 (Header)**：检查 `AppTheme.getMobileHeaderColors()` 是否覆盖新主题。
- **空状态图标/文字**：检查 `_buildEmptyState()` 方法中的颜色判断。
- **下拉刷新动画**：见组件适配部分。

### 2.2 编辑器页面 (`lib/pages/editor_page.dart`)

- **光标颜色**：检查 `_buildHeader()` 和 `_buildContentArea()` 中的 `cursorColor`。
- **装饰线颜色**：检查 `_buildAdaptiveContent()` 中的 `color` 定义。
- **下拉菜单背景**：检查 `_buildWeatherSelector()` 和 `_buildMoodSelector()` 中的 `dropdownBg` / `menuBg`。

### 2.3 设置页面 (`lib/pages/settings_page.dart`)

- **标题阴影**：检查 `titleShadow` 的定义。
- **底部弹窗样式**：检查 `_buildSkeuomorphicBottomSheet()` 和相关方法。
- **开关颜色**：通常由 `AppTheme.getSettingsTheme()` 统一管理。

### 2.4 数据同步页面 (`lib/pages/sync_settings_page.dart`)

- **按钮样式**：检查 `_buildButton()` 方法中的 `isAfterRain` 等判断。
- **输入框样式**：检查 `_buildTextField()` 方法。

### 2.5 书架目录页面 (`lib/pages/book_directory_page.dart`)

- **标题颜色**：检查 `appBarColor` 的判断逻辑，确保浅色主题使用深色标题。

### 2.6 专注写作页面 (`lib/pages/focus_writing_page.dart`)

- **遮罩透明度**：检查 Scrim 的颜色和透明度设置。

---

## 三、组件适配清单

### 3.1 纸张组件 (`lib/widgets/paper_sheet_widget.dart`)

- **书签/丝带颜色 (`accentColor`)**：在 `build()` 方法中添加新主题的颜色分支。

### 3.2 日期选择器 (`lib/widgets/skeuomorphic_date_picker.dart`)

- **整体配色**：在 `build()` 方法的颜色定义块中添加新主题分支，包括：
  - `dialogBg`, `headerBg`, `headerText`, `bodyText`, `accentColor`, `weekDayColor`, `border`, `shadows`

### 3.3 搜索栏 (`lib/widgets/skeuomorphic_search_bar.dart`)

- **背景/边框/图标颜色**：检查 `build()` 方法中的颜色判断。
- **内阴影颜色**：检查 "Simulated Inner Shadow" 部分的颜色定义。

### 3.4 下拉刷新 (`lib/widgets/book_flip_refresh_widget.dart`)

- **书本动画颜色**：在 `build()` 方法中添加 `bookColor`, `pageColor`, `textColor` 的新主题分支。

### 3.5 月份分割线 (`lib/widgets/month_divider.dart`)

- **颜色配置**：通常由 `AppTheme.getMonthDividerTheme()` 统一管理。

### 3.6 对话框 (`lib/widgets/skeuomorphic_dialog.dart`)

- **背景/边框/按钮颜色**：检查 `build()` 方法中的颜色判断。

### 3.7 过渡动画 (`lib/widgets/paper_fold_page_route.dart`)

- **信纸颜色**：在 `_getThemeColors()` 方法中添加新主题的 `_LetterColors` 配置，包括：
  - `paper`, `foldedBack`, `border`, `shadow`, `foldLine`

---

## 四、新增主题标准流程

1.  **在 `app_theme.dart` 中注册主题常量**。
2.  **逐一检查并更新上述各 `getXxxTheme()` 方法**。
3.  **全局搜索 `isSeaFlower` 或 `isMidnight` 等关键字**，在硬编码判断处添加新主题分支。
4.  **运行应用，逐页面、逐组件验收视觉效果**。
5.  **记录遗漏点，补充修复**。

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
lib/pages/diary_list_page.dart
lib/pages/editor_page.dart
lib/pages/settings_page.dart
lib/pages/sync_settings_page.dart
lib/pages/book_directory_page.dart
lib/pages/focus_writing_page.dart
lib/widgets/paper_sheet_widget.dart
lib/widgets/skeuomorphic_date_picker.dart
lib/widgets/skeuomorphic_search_bar.dart
lib/widgets/book_flip_refresh_widget.dart
lib/widgets/month_divider.dart
lib/widgets/skeuomorphic_dialog.dart
lib/widgets/paper_fold_page_route.dart
```
