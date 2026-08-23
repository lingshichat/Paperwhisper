# Editor Transition Preference

## 1. Scope / Trigger

Apply this contract when changing the “关闭多余动画” setting, editor Route selection, diary-card/FAB/sidebar editor entry points, or the long-diary preview handshake.

## 2. Signatures

```dart
Route<void> AppRoutes.editor({
  DiaryEntry? entry,
  AppRouteTransition transition = AppRouteTransition.slide,
  bool usePreviewMode = false,
  bool simplifyPageTransitions = false,
  // Existing preview callback and route geometry arguments omitted.
});

bool get SettingsProvider.simplifyPageTransitions;
Future<void> SettingsProvider.setSimplifyPageTransitions(bool value);
```

The persisted key is `simplify_page_transitions` (`bool`).

## 3. Contracts

- A missing preference resolves to `false`; existing `letterFold` and `unfold` behavior remains the default.
- The setter updates memory and calls `notifyListeners()` before awaiting `SharedPreferences`.
- Diary-list and sidebar presentation read the setting at tap time and pass it to `AppRoutes.editor`. `app/navigation` must not read Provider or require `BuildContext`.
- `simplifyPageTransitions=true` overrides `letterFold` and `unfold` with the existing `SlidePageRoute`; pop uses that Route's reverse slide. Other app routes are unchanged.
- Simplified navigation constructs `EditorPage(usePreviewMode: false)`. Long-diary preview is normally released by `UnfoldPageRoute.onAnimationComplete`; a slide Route never fires that callback.

## 4. Validation & Error Matrix

| Condition | Required behavior |
|---|---|
| Preference absent | Resolve `false`; preserve existing complex transitions |
| Enabled with `letterFold` or `unfold` | Return `SlidePageRoute` |
| Enabled with `usePreviewMode=true` | Build `EditorPage` with preview disabled so content is not left truncated |
| Disabled | Preserve requested transition, Route parameters, and preview callback behavior |
| App restarts after toggle | Restore the persisted boolean through `SettingsBootstrapData` |

## 5. Good / Base / Bad Cases

- Good: A long diary opens through `SlidePageRoute` and receives `usePreviewMode=false`.
- Base: The setting is absent, so cards unfold and new entries use letter-fold.
- Bad: Swap `UnfoldPageRoute` for slide while leaving preview enabled; full content never replaces the truncated preview.

## 6. Tests Required

- Provider: absent value defaults false; setter notifies immediately and persists; bootstrap restores true.
- Settings UI: Android narrow layout renders, toggles, and persists without exceptions.
- Route factory: both complex transitions are overridden; disabled behavior and page parameters remain intact.
- Entry points: FAB, long diary card, and sidebar “写一篇” push `SlidePageRoute`; long-card `EditorPage.usePreviewMode` is false; reverse duration remains the slide Route contract.

## 7. Wrong vs Correct

### Wrong

```dart
// Slide 不会触发 Unfold 的完成回调，长日记会停留在截断预览。
final page = EditorPage(usePreviewMode: true);
return SlidePageRoute<void>(page: page);
```

### Correct

```dart
return AppRoutes.editor(
  entry: entry,
  transition: AppRouteTransition.unfold,
  usePreviewMode: isLongDiary,
  simplifyPageTransitions:
      context.read<SettingsProvider>().simplifyPageTransitions,
);
```
