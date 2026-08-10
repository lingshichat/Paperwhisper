import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/diary_entry.dart';
import '../../models/moment.dart';
import '../../features/about/presentation/about_page.dart';
import '../../features/library/presentation/book_directory_page.dart';
import '../../features/library/presentation/bookshelf_page.dart';
import '../../pages/diary_list_page.dart';
import '../../pages/editor_page.dart';
import '../../pages/intro_page.dart';
import '../../pages/moment_detail_page.dart';
import '../../pages/moments_page.dart';
import '../../features/premium/presentation/premium_membership_page.dart';
import '../../pages/security_settings_page.dart';
import '../../pages/settings_page.dart';
import '../../features/statistics/presentation/statistics_page.dart';
import '../../pages/sync_settings_page.dart';
import '../../features/trash/presentation/trash_page.dart';
import 'route_transitions.dart';

/// 编辑器多动画场景的转场选择器。
///
/// 仅保留现有生产调用使用的三类（letterFold / unfold / slide）；
/// 其余转场经 [AppRoutes] 的通用工厂（slide/fadeSlide/unfold/
/// smoothCover/bookFlip/letterFold/fade/shellFade）按需选用。
enum AppRouteTransition { letterFold, unfold, slide }

/// 跨页路由工厂（集中导航边界）。
///
/// 页面与通用组件不再直接构造跨页目标页面并选择转场；跨页导航统一经
/// [AppRoutes] 返回 [Route]。保留 5 个旧文件中的 6 种 Route 类（slide /
/// fadeSlide / unfold / smoothCover / bookFlip / letterFold）的全部构造参数
/// 与语义（duration / curve / opaque / barrier），页面构造参数与现状调用
/// 逐一对应。
///
/// 说明：
/// - 业务弹窗、`Navigator.pop` 不强制走本工厂。
/// - 本文件只依赖 `pages/` 与 `app/navigation/`，不反向依赖 `widgets/`。
class AppRoutes {
  AppRoutes._();

  // ---------------------------------------------------------------------------
  // 转场 Route 工厂：复用 route_transitions 的六种 Route 类
  // ---------------------------------------------------------------------------

  /// 平滑平移（700ms / 600ms，easeOutQuart）。
  static Route<T> slide<T>(Widget page) => SlidePageRoute<T>(page: page);

  /// 淡入页面（opaque=true，默认 300ms/300ms，可传 forward duration；
  /// reverse 保留 Flutter 默认 300ms）。供页面级淡入复用。
  static Route<T> pageFade<T>(
    Widget page, {
    Duration forward = const Duration(milliseconds: 300),
  }) => pageFadeBuilder<T>((_) => page, forward: forward);

  /// 淡入页面（惰性 builder 版，opaque=true，默认 300ms/300ms，可传
  /// forward duration；reverse 保留 Flutter 默认 300ms）。
  ///
  /// [builder] 在 route 的 pageBuilder 阶段才执行，此时传入的是该
  /// route 自身的有效 BuildContext，而非调用方（可能即将被替换/销毁）
  /// 的 context。供 Splash 锁屏、SecuritySettings 锁屏流等在 route
  /// 内部持有回调导航上下文的场景使用，避免捕获外层将被 dispose 的
  /// context 导致 deactivated context 异常。
  static Route<T> pageFadeBuilder<T>(
    WidgetBuilder builder, {
    Duration forward = const Duration(milliseconds: 300),
  }) => PageRouteBuilder<T>(
    opaque: true,
    transitionDuration: forward,
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  /// 淡入覆盖（opaque=false，默认 300ms/300ms；供 MomentDetail 类模态
  /// 呈现复用，对应 moment_card 现状的 PageRouteBuilder + FadeTransition）。
  static Route<T> overlayFade<T>(Widget page) => PageRouteBuilder<T>(
    opaque: false,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  /// 透明覆盖（opaque=false、无 Fade transitionsBuilder，300ms/300ms；
  /// 对应 main resume 锁屏现状：仅 opaque=false，无转场动画）。
  static Route<T> transparent<T>(Widget page) =>
      PageRouteBuilder<T>(opaque: false, pageBuilder: (_, _, _) => page);

  /// 淡入 shell 切换（opaque=true，500ms / 300ms；供 Sidebar 主页面切换
  /// 复用，对应 sidebar_widget 现状的 PageRouteBuilder + FadeTransition：
  /// 仅设置 transitionDuration=500ms，reverse 保持 Flutter 默认 300ms）。
  static Route<T> shellFade<T>(Widget page) => PageRouteBuilder<T>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  /// 淡入平移（600ms / 500ms，easeOutQuart）。
  static Route<T> fadeSlide<T>(Widget page) =>
      FadeSlidePageRoute<T>(page: page);

  /// 折纸展开（800ms / 700ms，性能模式 550ms / 500ms，opaque=false）。
  static Route<T> unfold<T>(
    Widget page, {
    Rect? sourceRect,
    Color? backgroundColor,
    VoidCallback? onAnimationComplete,
    bool usePerformanceMode = false,
  }) => UnfoldPageRoute<T>(
    page: page,
    sourceRect: sourceRect,
    backgroundColor: backgroundColor,
    onAnimationComplete: onAnimationComplete,
    usePerformanceMode: usePerformanceMode,
  );

  /// 丝滑覆盖（700ms / 600ms，easeOutQuart）。
  static Route<T> smoothCover<T>(Widget page) =>
      SmoothCoverPageRoute<T>(page: page);

  /// 书本翻页（500ms / 450ms，easeOutCubic）。
  static Route<T> bookFlip<T>(Widget page) => BookFlipPageRoute<T>(page: page);

  /// 信纸对折（1600ms / 1400ms，easeOutSine，opaque=false）。
  static Route<T> letterFold<T>(Widget page) =>
      LetterFoldPageRoute<T>(page: page);

  // ---------------------------------------------------------------------------
  // 页面 Route 工厂：单一动画语义的跨页目标
  // ---------------------------------------------------------------------------

  /// 设置页（现状：SlidePageRoute）。
  static Route<void> settings() => slide(const SettingsPage());

  /// 回收站（现状：SlidePageRoute）。
  static Route<void> trash() => slide(const TrashPage());

  /// 关于页（现状：SlidePageRoute）。
  static Route<void> about() => slide(const AboutPage());

  /// 会员页（现状：SlidePageRoute，settings / sync_settings / moments 共用）。
  static Route<void> premium() => slide(const PremiumMembershipPage());

  /// 同步设置页（现状：SlidePageRoute）。
  static Route<void> syncSettings() => slide(const SyncSettingsPage());

  /// 安全设置页（现状：SlidePageRoute，settings_page）。
  static Route<void> securitySettings() => slide(const SecuritySettingsPage());

  /// 统计页（现状：自定义 PageRouteBuilder 淡入 500ms opaque，sidebar）。
  static Route<void> statistics() => shellFade(const StatisticsPage());

  /// 随心记页（现状：自定义 PageRouteBuilder 淡入 500ms opaque，sidebar）。
  static Route<void> moments() => shellFade(const MomentsPage());

  /// 日记列表页（现状：自定义 PageRouteBuilder 淡入 500ms opaque，sidebar）。
  static Route<void> diaryList() => shellFade(const DiaryListPage());

  /// 引导页完成 → 日记列表（现状：intro 800ms Fade 淡入；reverse 保留
  /// Flutter 默认 300ms）。
  static Route<void> introCompleted() => pageFade<void>(
    const DiaryListPage(),
    forward: const Duration(milliseconds: 800),
  );

  /// 启动页分发（现状：splash 300ms Fade 淡入，300ms/300ms）。
  ///
  /// showIntro 优先返回 IntroPage；否则按 startup_page 持久化字符串
  /// （'moments' / 'writer' / 'last' / default）逐字分发，字符串不变。
  static Route<void> startup({
    required bool showIntro,
    required String startupPage,
  }) {
    final Widget target;
    if (showIntro) {
      target = const IntroPage();
    } else {
      switch (startupPage) {
        case 'moments':
          target = const MomentsPage();
        case 'writer':
        case 'last':
        default:
          target = const DiaryListPage();
      }
    }
    return pageFade<void>(target);
  }

  /// 书架页（现状：SmoothCoverPageRoute，book_directory）。
  ///
  /// 保持旧调用 `SmoothCoverPageRoute(page: BookshelfPage(...))` 推断出的
  /// `Route<dynamic>` 返回契约：调用方 `Navigator.push` 拿回 dynamic 结果，
  /// 与 book_directory 的 `Navigator.pop(context, result)` 语义一致。
  static Route<dynamic> bookshelf({int? initialYear}) =>
      smoothCover<dynamic>(BookshelfPage(initialYear: initialYear));

  /// 目录页（现状：SmoothCoverPageRoute，返回 int 结果：月/年）。
  static Route<int> bookDirectory({required int year}) =>
      smoothCover<int>(BookDirectoryPage(year: year));

  /// 随心记详情页（现状：opaque=false + FadeTransition，moment_card）。
  static Route<void> momentDetail({
    required Moment moment,
    required Directory? baseDir,
    required String heroTag,
    int initialIndex = 0,
  }) => overlayFade<void>(
    MomentDetailPage(
      moment: moment,
      baseDir: baseDir,
      heroTag: heroTag,
      initialIndex: initialIndex,
    ),
  );

  // ---------------------------------------------------------------------------
  // 多动画场景页面工厂
  // ---------------------------------------------------------------------------

  /// 编辑器页（现状：新建走 LetterFold、点击卡片走 Unfold、降级走 Slide）。
  static Route<void> editor({
    DiaryEntry? entry,
    bool lazyLoad = false,
    void Function(VoidCallback)? onContentReady,
    bool usePreviewMode = false,
    AppRouteTransition transition = AppRouteTransition.slide,
    Rect? sourceRect,
    bool usePerformanceMode = false,
    VoidCallback? onAnimationComplete,
  }) {
    final page = EditorPage(
      entry: entry,
      lazyLoad: lazyLoad,
      onContentReady: onContentReady,
      usePreviewMode: usePreviewMode,
    );
    return switch (transition) {
      AppRouteTransition.letterFold => letterFold<void>(page),
      AppRouteTransition.unfold => unfold<void>(
        page,
        sourceRect: sourceRect,
        usePerformanceMode: usePerformanceMode,
        onAnimationComplete: onAnimationComplete,
      ),
      AppRouteTransition.slide => slide<void>(page),
    };
  }
}
