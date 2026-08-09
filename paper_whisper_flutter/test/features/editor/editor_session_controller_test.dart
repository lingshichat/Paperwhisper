import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/editor/application/editor_session_controller.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/services/draft_service.dart';

/// EditorSessionController 单元测试（阶段 3 测试 lane 第二批）。
///
/// 通过公开契约与可注入的 [FakeDraftService] 刻画控制器行为，不触碰
/// 私有状态：
/// - 新建/已有 entry 的逐字段初始化与 200 字预览截断边界
/// - hasChanges 对标题/正文/天气/心情的判定边界（Markdown/日期不跟踪）
/// - syncPreviewText 的截断与幂等
/// - 草稿判定：无/空/相同/不同/partial（isIncomplete）
/// - restoreFromDraft 覆盖字段、抑制防抖监听、hasChanges 正确
/// - 2s 防抖自动保存：取消/重置/立即保存/空内容/内容完整/再次保存
/// - clearDraft 委托与 dispose 的 Timer/Controller/监听器释放
///
/// 时间控制统一使用 WidgetTester 的 fake clock（`tester.pump(Duration)`），
/// 不真实等待；草稿 IO 全部走内存 [FakeDraftService]，不触碰
/// SharedPreferences。每个触发过文本输入的用例末尾必须 `dispose()`，
/// 否则 flutter_test 会以「Timer 仍挂起」判定测试失败。
void main() {
  group('初始化', () {
    testWidgets('新建日记：isEditing true、默认元数据与空控制器', (tester) async {
      final controller = buildController();

      expect(controller.isEditing, isTrue);
      expect(controller.weather, WeatherType.sunny);
      expect(controller.mood, MoodType.calm);
      expect(controller.isMarkdown, isFalse);
      expect(controller.dateString, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(controller.titleController.text, isEmpty);
      expect(controller.contentController.text, isEmpty);
      expect(controller.previewController.text, isEmpty);

      controller.dispose();
    });

    testWidgets('已有日记：标题/正文/元数据逐字段初始化，isEditing false', (tester) async {
      final controller = buildController(initialEntry: entry());

      expect(controller.isEditing, isFalse);
      expect(controller.titleController.text, '我的日记');
      expect(controller.contentController.text, '正文内容');
      expect(controller.previewController.text, '正文内容');
      expect(controller.weather, WeatherType.rainy);
      expect(controller.mood, MoodType.excited);
      expect(controller.isMarkdown, isTrue);
      expect(controller.dateString, '2026-05-01');

      controller.dispose();
    });

    testWidgets('预览控制器 200 字截断边界：短/恰好 200/201/长内容', (tester) async {
      final short = repeatChar(50);
      var controller = buildController(initialEntry: entry(content: short));
      expect(controller.previewController.text, short);
      controller.dispose();

      final exactly200 = repeatChar(200);
      controller = buildController(initialEntry: entry(content: exactly200));
      expect(controller.previewController.text, exactly200);
      controller.dispose();

      final over201 = repeatChar(201);
      controller = buildController(initialEntry: entry(content: over201));
      expect(controller.previewController.text.length, 200);
      expect(controller.previewController.text, over201.substring(0, 200));
      controller.dispose();

      final long = repeatChar(500);
      controller = buildController(initialEntry: entry(content: long));
      expect(controller.previewController.text.length, 200);
      expect(controller.previewController.text, long.substring(0, 200));
      controller.dispose();
    });
  });

  group('hasChanges', () {
    testWidgets('新建：空内容 false，标题/正文非空 true，清空回 false', (tester) async {
      final controller = buildController();

      expect(controller.hasChanges, isFalse);

      controller.titleController.text = '标题';
      expect(controller.hasChanges, isTrue);

      controller.titleController.text = '';
      expect(controller.hasChanges, isFalse);

      controller.contentController.text = '正文';
      expect(controller.hasChanges, isTrue);

      controller.contentController.text = '';
      expect(controller.hasChanges, isFalse);

      controller.dispose();
    });

    testWidgets('已有：未改 false；标题/正文/天气/心情变更 true；Markdown/日期不跟踪', (
      tester,
    ) async {
      // 标题变更
      var controller = buildController(initialEntry: entry());
      expect(controller.hasChanges, isFalse);
      controller.titleController.text = '新标题';
      expect(controller.hasChanges, isTrue);
      controller.dispose();

      // 正文变更
      controller = buildController(initialEntry: entry());
      controller.contentController.text = '新正文';
      expect(controller.hasChanges, isTrue);
      controller.dispose();

      // 天气变更
      controller = buildController(initialEntry: entry());
      controller.weather = WeatherType.snowy;
      expect(controller.hasChanges, isTrue);
      controller.dispose();

      // 心情变更
      controller = buildController(initialEntry: entry());
      controller.mood = MoodType.sad;
      expect(controller.hasChanges, isTrue);
      controller.dispose();

      // Markdown 开关变更不参与 hasChanges（锁定现状）
      controller = buildController(initialEntry: entry(isMarkdown: true));
      controller.isMarkdown = false;
      expect(controller.hasChanges, isFalse);
      controller.dispose();

      // 日期变更不参与 hasChanges（锁定现状）
      controller = buildController(initialEntry: entry());
      controller.dateString = '2099-01-01';
      expect(controller.hasChanges, isFalse);
      controller.dispose();
    });
  });

  group('syncPreviewText', () {
    testWidgets('短内容全量同步；长内容截断 200 字；重复调用幂等', (tester) async {
      var controller = buildController();
      controller.contentController.text = 'abc';
      controller.syncPreviewText();
      expect(controller.previewController.text, 'abc');
      controller.dispose();

      controller = buildController();
      final long = repeatChar(300);
      controller.contentController.text = long;
      controller.syncPreviewText();
      expect(controller.previewController.text.length, 200);
      expect(controller.previewController.text, long.substring(0, 200));

      // 幂等：内容未变时重复同步不改变预览
      controller.syncPreviewText();
      expect(controller.previewController.text, long.substring(0, 200));
      controller.dispose();
    });
  });

  group('草稿判定 checkDraftRestore', () {
    test('无草稿返回 null，且仅查询一次', () async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      expect(await controller.checkDraftRestore(), isNull);
      expect(await controller.checkDraftRestore(), isNull);
      expect(fake.getDraftCallCount, 1);

      controller.dispose();
    });

    test('新建 + 空草稿：清理残留并返回 null', () async {
      final fake = FakeDraftService();
      fake.drafts['new'] = entry(
        filename: '',
        dateString: '',
        title: '',
        content: '',
      );
      final controller = buildController(draftService: fake);

      expect(await controller.checkDraftRestore(), isNull);
      expect(fake.clearedIds, ['new']);

      controller.dispose();
    });

    test('新建 + 非空草稿：返回恢复信息（isIncomplete false）', () async {
      final fake = FakeDraftService();
      fake.drafts['new'] = entry(
        filename: '',
        dateString: '2026-05-02',
        title: '草稿标题',
        content: '草稿正文',
        weather: WeatherType.cloudy,
        mood: MoodType.sad,
      );
      final controller = buildController(draftService: fake);

      final info = await controller.checkDraftRestore();
      expect(info, isNotNull);
      expect(info!.isIncomplete, isFalse);
      expect(info.draft.title, '草稿标题');
      expect(info.draft.content, '草稿正文');
      expect(info.draft.weather, WeatherType.cloudy);
      expect(info.draft.mood, MoodType.sad);
      expect(info.draft.dateString, '2026-05-02');

      controller.dispose();
    });

    test('已有 + 草稿与原文一致：清理残留并返回 null', () async {
      final initial = entry();
      final fake = FakeDraftService();
      fake.drafts[initial.filename] = initial;
      final controller = buildController(
        initialEntry: initial,
        draftService: fake,
      );

      expect(await controller.checkDraftRestore(), isNull);
      expect(fake.clearedIds, [initial.filename]);

      controller.dispose();
    });

    test('已有 + 草稿标题不同：不清理，返回恢复信息', () async {
      final initial = entry();
      final fake = FakeDraftService();
      fake.drafts[initial.filename] = entry(
        title: '不同标题',
        content: initial.content,
      );
      final controller = buildController(
        initialEntry: initial,
        draftService: fake,
      );

      final info = await controller.checkDraftRestore();
      expect(info, isNotNull);
      expect(info!.isIncomplete, isFalse);
      expect(fake.clearedIds, isEmpty);

      controller.dispose();
    });

    test('已有 + 草稿正文更短：isIncomplete true（partial）', () async {
      final initial = entry(content: 'longer content here');
      final fake = FakeDraftService();
      fake.drafts[initial.filename] = entry(content: 'short');
      final controller = buildController(
        initialEntry: initial,
        draftService: fake,
      );

      final info = await controller.checkDraftRestore();
      expect(info, isNotNull);
      expect(info!.isIncomplete, isTrue);

      controller.dispose();
    });

    test('已有 + 草稿正文等长或更长：isIncomplete false', () async {
      final initial = entry(content: 'abcdef');
      final fake = FakeDraftService();
      fake.drafts[initial.filename] = entry(content: 'fedcba'); // 等长不同
      final controller = buildController(
        initialEntry: initial,
        draftService: fake,
      );

      final info = await controller.checkDraftRestore();
      expect(info, isNotNull);
      expect(info!.isIncomplete, isFalse);

      controller.dispose();

      final fake2 = FakeDraftService();
      fake2.drafts[initial.filename] = entry(content: 'abcdefghij'); // 更长
      final controller2 = buildController(
        initialEntry: initial,
        draftService: fake2,
      );

      final info2 = await controller2.checkDraftRestore();
      expect(info2, isNotNull);
      expect(info2!.isIncomplete, isFalse);

      controller2.dispose();
    });
  });

  group('restoreFromDraft', () {
    testWidgets('覆盖标题/正文/天气/心情/日期，抑制防抖监听，hasChanges 正确', (tester) async {
      final fake = FakeDraftService();
      final initial = entry(content: 'A');
      final draft = entry(
        dateString: '2026-06-06',
        title: '草稿标题',
        content: 'B',
        weather: WeatherType.snowy,
        mood: MoodType.happy,
        isMarkdown: false, // 与 initial 相反，用于验证 restore 不恢复该字段
      );
      final controller = buildController(
        initialEntry: initial,
        draftService: fake,
      );

      controller.restoreFromDraft(draft);

      expect(controller.titleController.text, '草稿标题');
      expect(controller.contentController.text, 'B');
      expect(controller.weather, WeatherType.snowy);
      expect(controller.mood, MoodType.happy);
      expect(controller.dateString, '2026-06-06');
      // 锁定现状：restoreFromDraft 不恢复 isMarkdown
      expect(controller.isMarkdown, isTrue);

      // 程序化赋值不触发防抖：无草稿变更标记、计时器不挂起
      expect(controller.hasDraftChanges, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(fake.saveCallCount, 0);

      // 与初始 entry 不同 → hasChanges true
      expect(controller.hasChanges, isTrue);

      controller.dispose();
    });

    testWidgets('恢复内容与初始一致：hasChanges false 且不触发保存', (tester) async {
      final fake = FakeDraftService();
      final initial = entry();
      final controller = buildController(
        initialEntry: initial,
        draftService: fake,
      );

      controller.restoreFromDraft(initial);

      expect(controller.hasChanges, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(fake.saveCallCount, 0);

      controller.dispose();
    });

    testWidgets('restore 后手动编辑重新触发防抖保存', (tester) async {
      final fake = FakeDraftService();
      final draft = entry(
        dateString: '2026-06-06',
        title: '草稿',
        content: '草稿正文',
      );
      final controller = buildController(draftService: fake);

      controller.restoreFromDraft(draft);
      await tester.pump(const Duration(seconds: 3));
      expect(fake.saveCallCount, 0);

      // 恢复本身不触发；恢复后的手动编辑正常进入防抖保存
      controller.contentController.text = '草稿正文+补充';
      await tester.pump(const Duration(seconds: 2));
      expect(fake.saveCallCount, 1);
      expect(fake.savedEntries.single.title, '草稿');
      expect(fake.savedEntries.single.content, '草稿正文+补充');

      controller.dispose();
    });
  });

  group('防抖自动保存', () {
    testWidgets('输入置位 hasDraftChanges，2s 后自动保存完整内容', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      controller.titleController.text = '标题';
      controller.contentController.text = '完整正文';
      expect(controller.hasDraftChanges, isTrue);

      await tester.pump(const Duration(milliseconds: 1900));
      expect(fake.saveCallCount, 0);

      await tester.pump(const Duration(milliseconds: 200));
      expect(fake.saveCallCount, 1);
      expect(controller.hasDraftChanges, isFalse);

      final saved = fake.savedEntries.single;
      expect(fake.savedIds, ['new']);
      expect(saved.title, '标题');
      expect(saved.content, '完整正文');
      expect(saved.filename, isEmpty); // 新建草稿不落文件名
      expect(saved.weather, WeatherType.sunny);
      expect(saved.mood, MoodType.calm);
      expect(saved.isMarkdown, isFalse);
      expect(saved.dateString, controller.dateString);

      controller.dispose();
    });

    testWidgets('连续输入重置防抖计时器：3s 内只保存一次最新内容', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      controller.contentController.text = 'a';
      await tester.pump(const Duration(seconds: 1));

      controller.contentController.text = 'ab';
      await tester.pump(const Duration(seconds: 1));
      expect(fake.saveCallCount, 0);

      await tester.pump(const Duration(seconds: 2));
      expect(fake.saveCallCount, 1);
      expect(fake.savedEntries.single.content, 'ab');

      controller.dispose();
    });

    testWidgets('cancelPendingAutoSave 取消计时器并清除标记', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      controller.titleController.text = 'x';
      expect(controller.hasDraftChanges, isTrue);

      controller.cancelPendingAutoSave();
      expect(controller.hasDraftChanges, isFalse);

      await tester.pump(const Duration(seconds: 5));
      expect(fake.saveCallCount, 0);

      controller.dispose();
    });

    testWidgets('已有日记输入不触发草稿防抖（isEditing false）', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(
        initialEntry: entry(),
        draftService: fake,
      );

      controller.titleController.text = '新标题';
      expect(controller.hasDraftChanges, isFalse);

      await tester.pump(const Duration(seconds: 3));
      expect(fake.saveCallCount, 0);

      controller.dispose();
    });

    testWidgets('performAutoSave 立即保存；挂起计时器触发时因标记已清而空转', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      controller.contentController.text = '立即保存正文';
      await controller.performAutoSave();
      expect(fake.saveCallCount, 1);
      expect(controller.hasDraftChanges, isFalse);

      // 输入时挂起的 2s 计时器仍会触发，但标记已清除 → 空转不重复保存
      await tester.pump(const Duration(seconds: 2));
      expect(fake.saveCallCount, 1);

      controller.dispose();
    });

    testWidgets('performAutoSave 无变更时不保存', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      await controller.performAutoSave();
      expect(fake.saveCallCount, 0);

      controller.dispose();
    });

    testWidgets('空标题空正文不保存，变更标记保留（锁定现状）', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      controller.titleController.text = 'x';
      controller.titleController.text = '';
      controller.contentController.text = 'y';
      controller.contentController.text = '';

      await controller.performAutoSave();
      expect(fake.saveCallCount, 0);
      expect(controller.hasDraftChanges, isTrue); // 早退不清标记

      controller.dispose();
    });

    testWidgets('保存成功后再次编辑可再次保存', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      controller.contentController.text = 'v1';
      await tester.pump(const Duration(seconds: 2));
      expect(fake.saveCallCount, 1);

      controller.contentController.text = 'v2';
      await tester.pump(const Duration(seconds: 2));
      expect(fake.saveCallCount, 2);
      expect(fake.savedEntries.last.content, 'v2');

      controller.dispose();
    });
  });

  group('clearDraft', () {
    test('委托服务并传递草稿 id：新建为 new，已有为文件名', () async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);
      await controller.clearDraft();
      expect(fake.clearedIds, ['new']);
      controller.dispose();

      final initial = entry();
      final fake2 = FakeDraftService();
      final controller2 = buildController(
        initialEntry: initial,
        draftService: fake2,
      );
      await controller2.clearDraft();
      expect(fake2.clearedIds, [initial.filename]);
      controller2.dispose();
    });
  });

  group('dispose', () {
    testWidgets('取消挂起的防抖计时器，之后不再保存', (tester) async {
      final fake = FakeDraftService();
      final controller = buildController(draftService: fake);

      controller.titleController.text = 'x'; // 挂起 2s 计时器
      controller.dispose();

      await tester.pump(const Duration(seconds: 5));
      expect(fake.saveCallCount, 0);
    });

    testWidgets('释放三个 Controller：dispose 后设置文本抛错', (tester) async {
      final controller = buildController();
      controller.titleController.text = 'x'; // 确保监听器已挂接
      controller.dispose();

      // ChangeNotifier.dispose 会清空监听器；dispose 后写文本必抛 FlutterError，
      // 以此验证三个 Controller 均已正确释放（不直接读 protected hasListeners）。
      // 注意：dispose 前 title 已是 'x'，dispose 后须写不同值，否则 value setter 因值未变而早退。
      expect(() => controller.titleController.text = 'y', throwsFlutterError);
      expect(() => controller.contentController.text = 'x', throwsFlutterError);
      expect(() => controller.previewController.text = 'x', throwsFlutterError);
    });

    testWidgets(
      'dispose 后受保护方法安全：performAutoSave 与 cancelPendingAutoSave 幂等不抛',
      (tester) async {
        final fake = FakeDraftService();
        final controller = buildController(draftService: fake);

        controller.contentController.text = 'x';
        controller.dispose();

        await controller.performAutoSave();
        expect(fake.saveCallCount, 0);

        controller.cancelPendingAutoSave(); // 不抛

        await tester.pump(const Duration(seconds: 2));
        expect(fake.saveCallCount, 0);
      },
    );
  });
}

/// 构造被测控制器，默认注入内存 [FakeDraftService]。
EditorSessionController buildController({
  DiaryEntry? initialEntry,
  FakeDraftService? draftService,
}) {
  return EditorSessionController(
    initialEntry: initialEntry,
    draftService: draftService ?? FakeDraftService(),
  );
}

/// 构造测试用 DiaryEntry，默认值贴合已有日记场景。
DiaryEntry entry({
  String filename = '2026-05-01_abc.txt',
  String dateString = '2026-05-01',
  String title = '我的日记',
  String content = '正文内容',
  WeatherType weather = WeatherType.rainy,
  MoodType mood = MoodType.excited,
  bool isMarkdown = true,
}) {
  return DiaryEntry(
    filename: filename,
    dateString: dateString,
    title: title,
    content: content,
    weather: weather,
    mood: mood,
    isMarkdown: isMarkdown,
  );
}

/// 生成指定长度的重复字符（用于 200 字截断边界）。
String repeatChar(int length) => List.filled(length, 'x').join();

/// DraftService 全量覆写的内存替身：记录保存/清除副作用，支持预置草稿。
///
/// 只覆写四个公共方法，不触碰私有字段（无 private shadow），也不依赖
/// SharedPreferences 平台通道，可在 fake clock 下确定性完成。
class FakeDraftService extends DraftService {
  /// 预置或已保存的草稿表（id → entry）。
  final Map<String, DiaryEntry> drafts = <String, DiaryEntry>{};

  /// 按序记录每次 saveDraft 的 id 与 entry（断言保存编排与字段透传）。
  final List<String> savedIds = <String>[];
  final List<DiaryEntry> savedEntries = <DiaryEntry>[];

  /// 按序记录每次 clearDraft 的 id。
  final List<String> clearedIds = <String>[];

  /// getDraft 调用次数（断言「仅首次检查」语义）。
  int getDraftCallCount = 0;

  int get saveCallCount => savedIds.length;

  @override
  Future<void> saveDraft(String id, DiaryEntry entry) async {
    savedIds.add(id);
    savedEntries.add(entry);
    drafts[id] = entry;
  }

  @override
  Future<DiaryEntry?> getDraft(String id) async {
    getDraftCallCount++;
    return drafts[id];
  }

  @override
  Future<void> clearDraft(String id) async {
    clearedIds.add(id);
    drafts.remove(id);
  }

  @override
  Future<bool> hasDraft(String id) async => drafts.containsKey(id);
}
