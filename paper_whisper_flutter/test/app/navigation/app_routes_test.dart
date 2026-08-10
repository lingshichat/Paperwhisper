import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/app/navigation/route_transitions.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/models/moment.dart';
import 'package:paper_whisper_flutter/features/about/presentation/about_page.dart';
import 'package:paper_whisper_flutter/pages/book_directory_page.dart';
import 'package:paper_whisper_flutter/pages/bookshelf_page.dart';
import 'package:paper_whisper_flutter/pages/diary_list_page.dart';
import 'package:paper_whisper_flutter/pages/editor_page.dart';
import 'package:paper_whisper_flutter/pages/intro_page.dart';
import 'package:paper_whisper_flutter/pages/moment_detail_page.dart';
import 'package:paper_whisper_flutter/pages/moments_page.dart';
import 'package:paper_whisper_flutter/pages/premium_membership_page.dart';
import 'package:paper_whisper_flutter/pages/security_settings_page.dart';
import 'package:paper_whisper_flutter/pages/settings_page.dart';
import 'package:paper_whisper_flutter/features/statistics/presentation/statistics_page.dart';
import 'package:paper_whisper_flutter/pages/sync_settings_page.dart';
import 'package:paper_whisper_flutter/features/trash/presentation/trash_page.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:provider/provider.dart';

/// AppRoutes 路由工厂：route 目标 Widget 类型与参数可达、
/// 转场工厂返回值语义、命名与泛型返回类型。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(Widget home) => MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => SettingsProvider())],
    child: MaterialApp(home: home),
  );

  Widget buildPage(Route<Object?> route, BuildContext context) =>
      (route as PageRouteBuilder<Object?>).pageBuilder(
        context,
        kAlwaysCompleteAnimation,
        kAlwaysCompleteAnimation,
      );

  group('转场工厂返回值语义', () {
    testWidgets('六种 Route 类工厂返回对应 Route 类型', (tester) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      const page = Text('p');

      expect(AppRoutes.slide<void>(page), isA<SlidePageRoute<void>>());
      expect(AppRoutes.fadeSlide<void>(page), isA<FadeSlidePageRoute<void>>());
      expect(AppRoutes.unfold<void>(page), isA<UnfoldPageRoute<void>>());
      expect(
        AppRoutes.smoothCover<void>(page),
        isA<SmoothCoverPageRoute<void>>(),
      );
      expect(AppRoutes.bookFlip<void>(page), isA<BookFlipPageRoute<void>>());
      expect(
        AppRoutes.letterFold<void>(page),
        isA<LetterFoldPageRoute<void>>(),
      );
    });

    testWidgets('pageFade 工厂：opaque=true、默认 300ms/300ms，可传 forward', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      const page = Text('p');

      final route = AppRoutes.pageFade<void>(page) as PageRouteBuilder<void>;
      expect(route.opaque, isTrue);
      expect(route.transitionDuration, const Duration(milliseconds: 300));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 300),
      );
      final built = route.pageBuilder(
        tester.element(find.byType(MaterialApp)),
        kAlwaysCompleteAnimation,
        kAlwaysCompleteAnimation,
      );
      expect(built, same(page));

      // forward 可覆盖，reverse 保留 Flutter 默认 300ms
      final long =
          AppRoutes.pageFade<void>(
                page,
                forward: const Duration(milliseconds: 800),
              )
              as PageRouteBuilder<void>;
      expect(long.transitionDuration, const Duration(milliseconds: 800));
      expect(long.reverseTransitionDuration, const Duration(milliseconds: 300));
    });

    testWidgets('pageFadeBuilder：惰性执行且拿到与 pageBuilder 相同的 route context', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));

      var builderCalls = 0;
      BuildContext? captured;
      final route =
          AppRoutes.pageFadeBuilder<void>((ctx) {
                builderCalls++;
                captured = ctx;
                return const Text('lazy');
              })
              as PageRouteBuilder<void>;

      // 构造阶段不执行 builder（惰性）
      expect(builderCalls, 0);
      expect(route.opaque, isTrue);
      expect(route.transitionDuration, const Duration(milliseconds: 300));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 300),
      );

      final built = route.pageBuilder(
        context,
        kAlwaysCompleteAnimation,
        kAlwaysCompleteAnimation,
      );
      expect(builderCalls, 1);
      expect(captured, same(context));
      expect(built, isA<Text>());
    });

    testWidgets('pageFade 委托 pageFadeBuilder：构建结果与 forward 语义等价', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));
      const page = Text('p');

      final direct = AppRoutes.pageFade<void>(page) as PageRouteBuilder<void>;
      final delegated =
          AppRoutes.pageFadeBuilder<void>((_) => page)
              as PageRouteBuilder<void>;
      expect(direct.opaque, delegated.opaque);
      expect(direct.transitionDuration, delegated.transitionDuration);
      expect(
        direct.pageBuilder(
          context,
          kAlwaysCompleteAnimation,
          kAlwaysCompleteAnimation,
        ),
        same(page),
      );
      expect(
        delegated.pageBuilder(
          context,
          kAlwaysCompleteAnimation,
          kAlwaysCompleteAnimation,
        ),
        same(page),
      );

      final long =
          AppRoutes.pageFadeBuilder<void>(
                (_) => page,
                forward: const Duration(milliseconds: 800),
              )
              as PageRouteBuilder<void>;
      expect(long.transitionDuration, const Duration(milliseconds: 800));
      expect(long.reverseTransitionDuration, const Duration(milliseconds: 300));
    });

    testWidgets(
      'pageFadeBuilder：外层 route 被替换后 route context 仍可导航（无 deactivated 异常）',
      (tester) async {
        // 复现 Splash locked 场景：外层页面被 pushReplacement 替换销毁，
        // 锁屏 route 的 pageBuilder 捕获到的是 route 自身 context，
        // 后续经该 context 导航不得触发 deactivated context 异常。
        late BuildContext routeContext;
        var navigated = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (outerContext) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(outerContext).pushReplacement(
                        AppRoutes.pageFadeBuilder<void>((ctx) {
                          routeContext = ctx;
                          return Scaffold(
                            body: Center(
                              child: TextButton(
                                onPressed: () {
                                  // 外层已被替换销毁，此处必须使用 route context
                                  Navigator.of(routeContext).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const Scaffold(body: Text('target')),
                                    ),
                                  );
                                  navigated = true;
                                },
                                child: const Text('go'),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                    child: const Text('start'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('start'));
        await tester.pumpAndSettle();
        expect(find.text('go'), findsOneWidget);

        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(navigated, isTrue);
        expect(find.text('target'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('overlayFade 工厂：opaque=false、默认 300ms（momentDetail 语义）', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      const page = Text('p');

      final route = AppRoutes.overlayFade<void>(page) as PageRouteBuilder<void>;
      expect(route.opaque, isFalse);
      expect(route.transitionDuration, const Duration(milliseconds: 300));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 300),
      );
      final built = route.pageBuilder(
        tester.element(find.byType(MaterialApp)),
        kAlwaysCompleteAnimation,
        kAlwaysCompleteAnimation,
      );
      expect(built, same(page));
    });

    testWidgets(
      'transparent 工厂：opaque=false、无 Fade transitionsBuilder（main resume 锁屏）',
      (tester) async {
        await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
        const page = Text('p');

        final route =
            AppRoutes.transparent<void>(page) as PageRouteBuilder<void>;
        expect(route.opaque, isFalse);
        expect(route.transitionDuration, const Duration(milliseconds: 300));
        expect(
          route.reverseTransitionDuration,
          const Duration(milliseconds: 300),
        );
        // 无 Fade：transitionsBuilder 直接透传 child，不包 FadeTransition
        final transitioned = route.transitionsBuilder(
          tester.element(find.byType(MaterialApp)),
          kAlwaysCompleteAnimation,
          kAlwaysCompleteAnimation,
          const Text('child'),
        );
        expect(transitioned, isA<Text>());
        expect(transitioned, isNot(isA<FadeTransition>()));
        final built = route.pageBuilder(
          tester.element(find.byType(MaterialApp)),
          kAlwaysCompleteAnimation,
          kAlwaysCompleteAnimation,
        );
        expect(built, same(page));
      },
    );

    testWidgets('shellFade 工厂：opaque=true、500ms/300ms（sidebar 语义）', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      const page = Text('p');

      final route = AppRoutes.shellFade<void>(page) as PageRouteBuilder<void>;
      expect(route.opaque, isTrue);
      expect(route.transitionDuration, const Duration(milliseconds: 500));
      expect(
        route.reverseTransitionDuration,
        const Duration(milliseconds: 300),
      );
      final built = route.pageBuilder(
        tester.element(find.byType(MaterialApp)),
        kAlwaysCompleteAnimation,
        kAlwaysCompleteAnimation,
      );
      expect(built, same(page));
    });

    test('editor 工厂按 transition 选择转场（仅 letterFold/unfold/slide）', () {
      expect(
        AppRoutes.editor(transition: AppRouteTransition.letterFold),
        isA<LetterFoldPageRoute<void>>(),
      );
      expect(
        AppRoutes.editor(transition: AppRouteTransition.unfold),
        isA<UnfoldPageRoute<void>>(),
      );
      expect(
        AppRoutes.editor(transition: AppRouteTransition.slide),
        isA<SlidePageRoute<void>>(),
      );
    });
  });

  group('页面工厂：route 目标 Widget 参数可达', () {
    testWidgets('introCompleted：DiaryListPage、800ms/300ms、opaque=true', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));

      final route = AppRoutes.introCompleted();
      expect(route, isA<PageRouteBuilder<void>>());
      final r = route as PageRouteBuilder<void>;
      expect(r.opaque, isTrue);
      expect(r.transitionDuration, const Duration(milliseconds: 800));
      expect(
        r.reverseTransitionDuration,
        const Duration(milliseconds: 300),
        reason: 'intro 现状仅设 transitionDuration=800，reverse 保留 Flutter 默认 300ms',
      );
      expect(buildPage(route, context), isA<DiaryListPage>());
    });

    testWidgets('startup：showIntro 优先 IntroPage，其余按 startup_page 字符串分发', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));

      Widget targetOf(bool showIntro, String startupPage) => buildPage(
        AppRoutes.startup(showIntro: showIntro, startupPage: startupPage),
        context,
      );

      expect(targetOf(true, 'writer'), isA<IntroPage>());
      expect(targetOf(false, 'moments'), isA<MomentsPage>());
      expect(targetOf(false, 'writer'), isA<DiaryListPage>());
      expect(targetOf(false, 'last'), isA<DiaryListPage>());
      expect(targetOf(false, 'unknown'), isA<DiaryListPage>());
      expect(targetOf(false, ''), isA<DiaryListPage>());

      // 300ms/300ms、opaque=true（splash 现状）
      final route = AppRoutes.startup(showIntro: false, startupPage: 'last');
      final r = route as PageRouteBuilder<void>;
      expect(r.opaque, isTrue);
      expect(r.transitionDuration, const Duration(milliseconds: 300));
      expect(r.reverseTransitionDuration, const Duration(milliseconds: 300));
    });

    testWidgets('无参页面工厂构建正确页面类型', (tester) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));

      expect(buildPage(AppRoutes.settings(), context), isA<SettingsPage>());
      expect(buildPage(AppRoutes.trash(), context), isA<TrashPage>());
      expect(buildPage(AppRoutes.about(), context), isA<AboutPage>());
      expect(
        buildPage(AppRoutes.premium(), context),
        isA<PremiumMembershipPage>(),
      );
      expect(
        buildPage(AppRoutes.syncSettings(), context),
        isA<SyncSettingsPage>(),
      );
      expect(
        buildPage(AppRoutes.securitySettings(), context),
        isA<SecuritySettingsPage>(),
      );
      expect(buildPage(AppRoutes.statistics(), context), isA<StatisticsPage>());
      expect(buildPage(AppRoutes.moments(), context), isA<MomentsPage>());
      expect(buildPage(AppRoutes.diaryList(), context), isA<DiaryListPage>());
    });

    testWidgets('securitySettings 使用 SlidePageRoute（settings_page 现状）', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final route = AppRoutes.securitySettings();
      expect(route, isA<SlidePageRoute<void>>());
      final slide = route as SlidePageRoute<void>;
      expect(slide.transitionDuration, const Duration(milliseconds: 700));
      expect(slide.opaque, isTrue);
    });

    testWidgets('bookshelf 使用 SmoothCoverPageRoute（book_directory 现状）', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final route = AppRoutes.bookshelf();
      expect(route, isA<SmoothCoverPageRoute<dynamic>>());
      final cover = route as SmoothCoverPageRoute<dynamic>;
      expect(cover.transitionDuration, const Duration(milliseconds: 700));
      expect(cover.opaque, isTrue);
    });

    testWidgets('sidebar 页面工厂使用 shellFade（opaque=true、500ms/300ms）', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      for (final route in [
        AppRoutes.diaryList(),
        AppRoutes.moments(),
        AppRoutes.statistics(),
      ]) {
        expect(route, isA<PageRouteBuilder<void>>());
        final r = route as PageRouteBuilder<void>;
        expect(r.opaque, isTrue, reason: 'sidebar 现状未设置 opaque，默认 true');
        expect(
          r.transitionDuration,
          const Duration(milliseconds: 500),
          reason: 'sidebar 现状 transitionDuration 500ms',
        );
        expect(
          r.reverseTransitionDuration,
          const Duration(milliseconds: 300),
          reason: 'sidebar 现状未设置 reverseTransitionDuration，Flutter 默认 300ms',
        );
      }
    });

    testWidgets('editor 工厂参数可达（entry/lazyLoad/usePreviewMode/onContentReady）', (
      tester,
    ) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));

      void Function(VoidCallback)? ready;
      final entry = DiaryEntry(
        filename: 'f',
        dateString: '2026-08-09',
        title: 't',
        content: 'c',
      );
      final route = AppRoutes.editor(
        entry: entry,
        lazyLoad: true,
        usePreviewMode: true,
        onContentReady: (VoidCallback cb) => ready = (_) => cb(),
        transition: AppRouteTransition.unfold,
      );
      expect(route, isA<UnfoldPageRoute<void>>());

      final page = buildPage(route, context) as EditorPage;
      expect(page.entry, same(entry));
      expect(page.lazyLoad, isTrue);
      expect(page.usePreviewMode, isTrue);
      expect(page.onContentReady, isNotNull);
      expect(ready, isNull); // 未触发，仅透传
    });

    testWidgets('bookDirectory 工厂参数可达且返回 int 泛型', (tester) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));

      final route = AppRoutes.bookDirectory(year: 2026);
      expect(route, isA<SmoothCoverPageRoute<int>>());
      final page = buildPage(route, context) as BookDirectoryPage;
      expect(page.year, 2026);
    });

    testWidgets('bookshelf 工厂参数可达', (tester) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));

      final page =
          buildPage(AppRoutes.bookshelf(initialYear: 2025), context)
              as BookshelfPage;
      expect(page.initialYear, 2025);
      expect(buildPage(AppRoutes.bookshelf(), context), isA<BookshelfPage>());
    });

    testWidgets('momentDetail 工厂参数可达且 opaque=false', (tester) async {
      await tester.pumpWidget(harness(const Scaffold(body: Text('x'))));
      final context = tester.element(find.byType(MaterialApp));

      final moment = Moment.create(content: 'hello');
      final route = AppRoutes.momentDetail(
        moment: moment,
        baseDir: null,
        heroTag: 'hero-1',
        initialIndex: 2,
      );
      final builder = route as PageRouteBuilder<void>;
      expect(builder.opaque, isFalse);
      expect(
        builder.transitionDuration,
        const Duration(milliseconds: 300),
        reason: 'moment_card 现状未设置 duration，PageRouteBuilder 默认 300ms',
      );
      final page = buildPage(route, context) as MomentDetailPage;
      expect(page.moment, same(moment));
      expect(page.heroTag, 'hero-1');
      expect(page.initialIndex, 2);
    });
  });
}
