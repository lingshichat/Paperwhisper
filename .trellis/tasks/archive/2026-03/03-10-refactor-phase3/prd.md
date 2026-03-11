# 重构路线图阶段 3：其他页面样式收敛

## Goal

延续阶段 1&2 的重构成果，消除剩余页面和组件中散落的硬编码颜色与主题判断逻辑，
使所有主题相关颜色均由 `AppTheme` 统一管理，Widget 层不再出现 `isSeaFlower`、`isMidnight` 等主题判断。

详细背景参见：`.trellis/spec/refactoring-roadmap.md`

## Requirements

### P1: 高优页面样式收敛
- [ ] `settings_page.dart`: 清理外观设置和排版设置区域的散落主题判断，统一由 `AppTheme.getSettingsTheme` 接管。

### P2: 独立组件样式收敛
- [ ] `security_settings_page.dart`
- [ ] `moment_card.dart`
- [ ] `moment_input_widget.dart`

### P3: 低风险/边缘组件清理
- [ ] `skeuomorphic_date_picker.dart`
- [ ] `paper_sheet_widget.dart`
- [ ] `book_flip_refresh_widget.dart`

### P4: 控件降级替换
- [ ] 全局搜索 `ElevatedButton`, `TextButton`, `TextButton.icon`
- [ ] 将发现的 Material 标准按钮替换为符合拟物化语言的自定义按钮容器

## Acceptance Criteria

- [ ] 每个修改页面：本地切换全部 7 种主题无视觉断层
- [ ] `flutter analyze` 无新引入错误
- [ ] Widget 层无 `isSeaFlower`/`isMidnight`/`isTwilight`/`isGardenOfWords` 布尔判断
- [ ] 所有主题颜色通过 `AppTheme.getXxxTheme(theme)` 获取

## Technical Notes

- 所有新增 `AppTheme.getXxxTheme()` 方法必须覆盖全部 7 种主题（含 default fallback）
- 参考阶段 2 的 `getTrashPageTheme` / `getSyncSettingsTheme` 实现模式
- 验收规则见 `refactoring-roadmap.md` 第 56-62 行
