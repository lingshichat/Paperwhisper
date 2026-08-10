# Flutter Architecture Boundaries

> `paper_whisper_flutter/lib/` 的可执行架构契约。修改目录、跨域依赖、导航、主题或 composition root 时，先检查本文件。

---

## 1. Scope / Trigger

以下改动必须遵守本契约：

- 新增或移动页面、Provider、Service、Controller、Widget、主题字段；
- 修改应用启动、Provider 装配、生命周期或跨页导航；
- 让一个 feature 调用另一个 feature；
- 把业务能力提升到 `core/` 或 `shared/`；
- 调整主题注册、主题 ID、组件主题数据或共享组件取主题方式。

目标目录只有五个入口：

```text
lib/
  main.dart
  app/
  core/
  features/
  shared/
```

旧的 `config/`、`models/`、`pages/`、`providers/`、`services/`、`utils/`、`widgets/` 不再接收新文件，也不得恢复为兼容层。

---

## 2. Signatures

### Composition root

```dart
Future<void> main() => bootstrap();
Future<void> bootstrap();

class PaperWhisperApp extends StatefulWidget {
  const PaperWhisperApp({
    required bool showIntro,
    required String startupPage,
    required bool isLocked,
  });
}
```

`bootstrap()` 创建唯一的 `DiaryService`、`MomentService` 和全局 Provider 图；`PaperWhisperApp` 只负责 MaterialApp、生命周期、锁屏恢复、启动页和自动同步接线。

### Navigation

```dart
class AppRoutes {
  static Route<void> settings();
  static Route<void> moments();
  static Route<void> diaryList();
  static Route<void> editor({DiaryEntry? entry, ...});
  static Route<void> startup({
    required bool showIntro,
    required String startupPage,
  });
}
```

完整工厂以 `lib/app/navigation/app_routes.dart` 为准。跨页目标由 `AppRoutes` 构造；业务 Dialog、bottom sheet 和 `Navigator.pop` 不必经过该工厂。

### Theme identity and typed component data

```dart
ThemeData AppTheme.getThemeData(String themeId);
String AppTheme.themeIdOf(BuildContext context);
PaperWhisperTheme ThemeRegistry.get(String themeId);
```

`AppTheme.getThemeData()` 写入强类型 ThemeExtension。`shared/widgets` 通过 `AppTheme.themeIdOf(context)` 获取 ID，再读取 `ThemeRegistry.get(id).component`；不得依赖 `SettingsProvider`。

### Cross-domain storage port

```dart
abstract interface class MomentStorageAccess {
  Directory? get dataDir;
  Future<void> init();
  Future<Set<String>> getAllReferencedImages();
}
```

`core/storage/StorageService` 只依赖这个端口，`features/moments/data/MomentService` 实现它。core 不读取 `Moment` 业务模型。

---

## 3. Contracts

### Dependency direction

| Source | May depend on | Must not depend on |
|---|---|---|
| `app/` | `core/`、`features/`、`shared/` | 无额外限制；这里是装配层 |
| `core/` | Dart/Flutter、第三方基础库、`core/` | `app/`、`features/`、`shared/` |
| `shared/` | Dart/Flutter、第三方 UI 库、`core/`、`shared/` | `app/`、任何 `features/` |
| `features/<x>/data` | `core/`、本 feature data、明确的低层跨域模型/端口 | 本 feature `application/`、`presentation/` |
| `features/<x>/application` | `core/`、本 feature data/application、明确的跨域端口 | 任意 `presentation/`、`BuildContext` |
| `features/<x>/presentation` | `core/`、`shared/`、本 feature、必要的跨域公开契约、`app/navigation` | 直接构造跨域页面 Route |

跨 feature 依赖不是一律禁止，但必须有明确业务含义。例如 sync 编排 diary/moments，statistics 汇总 diary/moments；为了少写一行 import 而横穿 feature 不成立。

### Ownership

- `app/navigation`：Route 工厂和五类转场的唯一位置。
- `app/shell`：Sidebar 及 shell 独占数据。
- `core/theme`：七主题注册、typed component data、主题视觉效果和 ThemeData。
- `core/storage`：跨域存储基础设施与最小端口，不持有业务模型。
- `features/<domain>/data`：该域模型、持久化、网关。
- `features/<domain>/application`：context-free Provider、Controller、Coordinator、状态机。
- `features/<domain>/presentation`：页面、域内 Widget、Dialog/Toast/Navigator 翻译。
- `shared/widgets`：已有多个跨域消费者且不依赖任何 feature 的 UI primitive。

未被消费的遗留组件可以保留在最保守边界，但不得据此创建新的通用抽象。删除另行立项。

### Navigation

- `lib/app/navigation/` 之外，生产代码中的 `MaterialPageRoute`、`PageRouteBuilder` 和自定义 Route 构造应为 0。
- 保留现有 Route 泛型、opaque、barrier、curve、forward/reverse duration 和 pop 返回值。
- `startup_page` 的持久化值固定为 `moments`、`writer`、`last`；不得重命名或迁移格式。
- 需要有效 Route context 的 replacement 流程使用惰性 builder，不能捕获即将卸载的页面 context。

### Theme

- `ThemeRegistry` 是七主题 typed source of truth；注册顺序为 `default`、`midnight`、`amber_lens`、`after_rain`、`twilight`、`garden_of_words`、`sea_flower`。
- UI 直接读取 typed 字段，不恢复 `Map<String, dynamic>` facade、组件 `toMap()`、运行时颜色/Gradient/Border 强转。
- `FabThemeData` 用互斥的 `backgroundColor` / `backgroundGradient` 表达背景，两者恰一非空。
- shared 组件必须运行在 `AppTheme.getThemeData()` 生成的 Material 主题下。测试壳也使用该入口；不得为裸 `ThemeData` 添加默认主题 fallback。
- 新主题字段逐字段迁移，保留 nullable、Gradient、Border、Shadow 的原语义和七主题色值。

### Composition and state

- 保留 Provider，不新增路由、DI、状态管理或代码生成依赖。
- manifest-owning Service 只在 `bootstrap()` 创建并注入，页面不得重新 new。
- application/data 不持有 `BuildContext`；Toast、Dialog、Navigator 留在 presentation。
- `main.dart` 只保留 import 和 `main() => bootstrap()`。

---

## 4. Validation & Error Matrix

| Condition | Required result |
|---|---|
| core/shared 新增 feature import | 架构检查失败；改用 core 端口或把代码放回 feature |
| data 引用 application/presentation | 架构检查失败；反转接口或移动职责 |
| application 引用 presentation / BuildContext | 架构检查失败；返回 typed outcome，由页面翻译 |
| shared 组件需要当前主题 | 使用 `AppTheme.themeIdOf(context)`；不得 import `SettingsProvider` |
| shared 组件运行在裸 `ThemeData` 下 | 视为接线错误；测试改用 `AppTheme.getThemeData()`，不新增 fallback |
| core 需要随心记图片引用 | 依赖 `MomentStorageAccess`，不得 import `MomentService` / `Moment` |
| 新跨页导航 | 在 `AppRoutes` 增加工厂并锁定 Route 参数测试 |
| 主题字段需要 Map 强转 | 停止实现；先补 typed component field，再迁移消费者 |
| 新业务文件无明确归属 | 优先放所属 feature；只有稳定的多域消费证据才进入 shared/core |

---

## 5. Good / Base / Bad Cases

- **Good**：`StorageService` 需要图片引用集合，于是在 core 定义 `MomentStorageAccess`，Moments 实现端口；依赖方向仍是 feature → core。
- **Base**：新增一个 Diary 独占卡片，直接放 `features/diary/presentation/widgets/`，由 Diary 页面消费。
- **Bad**：为了让 shared toast 读取主题而 import `features/settings/application/settings_provider.dart`。
- **Bad**：把 OS 同步通知放在 `presentation/`，再让 `SyncProvider` 从 application 反向 import。
- **Bad**：在页面里直接 `PageRouteBuilder(pageBuilder: ...OtherFeaturePage())`，形成第二导航入口。

---

## 6. Tests Required

每个结构批次至少完成：

1. `dart format --output=none --set-exit-if-changed lib test`。
2. `flutter analyze`，必须 0 issue。
3. 与移动/端口/Route/主题有关的聚焦测试。
4. 完整 `flutter test`；聚焦测试不能替代全量。
5. 导航迁移：`test/app/navigation/` + 涉及页面的返回栈测试。
6. 主题迁移：七主题 typed 字段测试，以及 Windows/Android 代表页面视觉回归。
7. 目录迁移：下列静态查询归零，并执行 `git diff --check`。

```bash
rg "AppTheme\.get[A-Za-z]+Theme\(" lib
rg "\btoMap\s*\(" lib/core/theme
rg "package:paper_whisper_flutter/(config|models|pages|providers|services|utils|widgets)/" lib test
rg "package:paper_whisper_flutter/(app|features|shared)/" lib/core
rg "package:paper_whisper_flutter/(app|features)/" lib/shared
rg "MaterialPageRoute|PageRouteBuilder" lib -g '!lib/app/navigation/**'
```

---

## 7. Wrong vs Correct

### Wrong

```dart
// core 反向依赖业务 feature
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';

class StorageService {
  StorageService(this.momentService);
  final MomentService momentService;
}

// shared 反向依赖 Settings feature
final themeId = context.read<SettingsProvider>().currentTheme;
```

### Correct

```dart
// core 声明最小端口，feature 负责实现
abstract interface class MomentStorageAccess {
  Future<Set<String>> getAllReferencedImages();
}

class MomentService implements MomentStorageAccess {
  @override
  Future<Set<String>> getAllReferencedImages() async => ...;
}

// shared 只读取 core/theme 发布的 ThemeExtension
final themeId = AppTheme.themeIdOf(context);
final toastTheme = ThemeRegistry.get(themeId).toast;
```
