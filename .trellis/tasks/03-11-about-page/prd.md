# 关于纸语页面

## Goal

为设置页中"关于纸语PaperWhisper"入口创建完整的关于页面，展示项目基本信息、外部链接和开源协议。当前该入口仅为 TODO 占位，需要实现信纸风格的关于页面。

## Requirements

### 页面内容
- App 名称: 纸语 PaperWhisper
- 版本号: 动态读取（使用 `UpdateService.getCurrentVersion()` 或 `package_info_plus`）
- Slogan: "纸本无言，因你而语"
- 官网链接: https://paperwhisper.lingshichat.top/
- GitHub 链接: https://github.com/lingshichat/Paperwhisper
- 小红书链接: https://www.xiaohongshu.com/user/profile/6115f765000000000101d9b6
- 开源协议: MIT License

### 设计风格
- **信纸风格**：参考 `premium_membership_page.dart` 的信纸设计模式
- **主题适配**：支持所有 7 个主题，使用现有 `SettingsThemeData` / `ThemeColors` 中的颜色
- **拟物化装饰**：使用 `WaxSealBadge` 或 `PostmarkStamp` 等现有装饰组件

### 布局结构
```
[AppBar: 关于纸语]
[Background: theme gradient]
  [ScrollView]
    [Letter Paper Container]
      [Tape decoration - top]

      ~ PaperWhisper ~        (Cinzel/PlayfairDisplay font)
      纸语                     (NotoSerifSC, large)
      "纸本无言，因你而语"      (DancingScript/italic)
      v1.5.8                  (small, secondary color)

      ─── 链接 ───
      ◉ 官方网站    →          (tap → url_launcher)
      ◉ GitHub     →          (tap → url_launcher)
      ◉ 小红书      →          (tap → url_launcher)

      ─── 开源协议 ───
      MIT License             (tap → 显示 MIT 全文或跳转)

      [WaxSealBadge]          (decorative)
      PaperWhisper Team       (DancingScript signature)
    [/Letter Paper Container]
```

### 导航接入
- 从设置页"关于纸语PaperWhisper"入口跳转，使用 `SlidePageRoute` 过渡动画
- 修改 `settings_page.dart` 中对应 `onTap` 回调（约 line 419）

## Acceptance Criteria

- [ ] 从设置页点击"关于纸语PaperWhisper"可正常跳转到关于页面
- [ ] 所有 7 个主题下显示正常，颜色适配正确
- [ ] 点击官网/GitHub/小红书链接可正常打开外部浏览器
- [ ] 版本号正确显示（动态读取，非硬编码）
- [ ] Android 和 Windows 端均正常显示
- [ ] 返回按钮正常工作
- [ ] 信纸风格与 `premium_membership_page` 视觉一致

## Technical Notes

### 复用现有代码
| 组件/工具 | 来源 | 用途 |
|-----------|------|------|
| `SlidePageRoute` | `lib/widgets/slide_page_route.dart` | 页面过渡动画 |
| `WaxSealBadge` | `lib/widgets/wax_seal_badge.dart` | 装饰性蜡封 |
| `PostmarkStamp` | `lib/widgets/postmark_stamp.dart` | 可选装饰 |
| `AppTheme.getBackground()` | `lib/config/app_theme.dart` | 页面背景 |
| `AppTheme.getSystemUiOverlayStyle()` | `lib/config/app_theme.dart` | 状态栏样式 |
| `UpdateService.getCurrentVersion()` | `lib/services/update_service.dart` | 版本号 |
| `url_launcher` | 已有依赖 | 打开外部链接 |
| 信纸设计模式 | `lib/pages/premium_membership_page.dart` | 设计参考 |

### 主题方案
复用 `SettingsThemeData` 和 `ThemeColors` 中已有的颜色（titleColor, textColor, paperColor 等），不创建新的 theme data class。

### 文件变更
| 文件 | 操作 |
|------|------|
| `lib/pages/about_page.dart` | **新建** — 关于页面 |
| `lib/pages/settings_page.dart` | **修改** — 接入导航（line ~419） |
