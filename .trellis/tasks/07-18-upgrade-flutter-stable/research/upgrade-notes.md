# Flutter 3.44.4 Upgrade Notes (expanded follow-ups)

## Baseline

| Item | Value |
|---|---|
| Target | Flutter **3.44.4** stable · revision `ad70ec4617…` · Dart **3.12.2** |
| Date | 2026-07-18 |

## Phase A — SDK alignment (done)

1. `environment.sdk`: `^3.7.0` → `^3.10.0`
2. `.metadata` → current stable; windows platform entry
3. `.gitignore`: drop stale `.flutter-plugins`; add `/coverage/`
4. Android `ndkVersion` → `28.2.13676358`

## Phase B — Follow-ups (done)

### 1. `withOpacity` → `withValues(alpha: …)`

- **786** replacements across **36** Dart files under `lib/`
- Remaining `withOpacity`: **0**

### 2. Markdown package

- Removed discontinued `flutter_markdown`
- Added `flutter_markdown_plus: ^1.0.0` (API drop-in for future MarkdownBody usage)
- No app source imported the old package (only `isMarkdown` data field remains)

### 3. Built-in Kotlin + AGP 9

| File | Change |
|---|---|
| `android/settings.gradle.kts` | AGP **9.0.1** (was 8.11.1) |
| `android/gradle/wrapper` | Gradle **9.1.0** (was 8.14) |
| `android/app/build.gradle.kts` | Removed `kotlin-android` + `kotlinOptions`; added `kotlin { compilerOptions { jvmTarget = JVM_17 } }` |
| `android/build.gradle.kts` | AGP 9 public `LibraryExtension` DSL (drop library `targetSdk`) |
| `android/app/proguard-rules.pro` | **New** — AGP 9 fails if referenced file missing; Play Core `-dontwarn` for R8 |
| `android/gradle.properties` | Flutter migrator may re-add `android.builtInKotlin=false` / `android.newDsl=false` as **plugin compatibility shims** |

App module is migrated per Flutter docs. Flutter tool may re-inject opt-out flags when plugins still pull KGP; with `record` 7.x the KGP plugin warning is gone. Flags remaining after a build are migrator-side compatibility, not missing app migration.

### 4. Major dependency upgrades

| Package | From → To (approx) |
|---|---|
| google_fonts | 7 → **8** |
| permission_handler | 11 → **12** |
| flutter_secure_storage | 9 → **10** |
| package_info_plus | 8 → **10** |
| device_info_plus | 12 → **13** |
| flutter_local_notifications | 19 → **22** |
| record | 5 → **7** |
| fl_chart | 0.70 → **1.2** |
| flutter_lints | 5 → **6** |
| flutter_launcher_icons | 0.13 → **0.14** |

Code fixes for majors:

- `sync_provider.dart`: notifications `initialize` / `show` / `cancel` named args (v22 API)
- Removed `record_linux` dependency_override (no longer needed)

## Analyze (final)

- **0 errors**, **0 warnings**
- ~111 **info** (flutter_lints 6 style): `unnecessary_underscores`, `use_build_context_synchronously`, `avoid_print`, etc. — not upgrade blockers
- 8 residual `deprecated_member_use` (non-`withOpacity`; optional follow-up)

## Build verification

| Platform | Result |
|---|---|
| Windows `flutter build windows --release` | OK · `paper_whisper_flutter.exe` |
| Android `flutter build apk --release` | OK · `app-release.apk` (~64.3MB) |

## Rollback

```text
git restore paper_whisper_flutter/ .trellis/spec/frontend/index.md .trellis/spec/frontend/type-safety.md
# plus remove new proguard-rules.pro if restoring fully
```
