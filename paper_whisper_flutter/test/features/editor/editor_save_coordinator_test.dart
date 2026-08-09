import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/editor/application/editor_save_coordinator.dart';
import 'package:paper_whisper_flutter/features/editor/application/editor_session_controller.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/providers/diary_provider.dart';
import 'package:paper_whisper_flutter/services/diary_service.dart';

// 复用批次二测试的构造 helper（buildController/entry）与 FakeDraftService
// 基类，避免重复 fake 定义；GatedFakeDraftService 在其上增加挂起门与
// 错误注入。
import 'editor_session_controller_test.dart';

/// EditorSaveCoordinator 单元测试（阶段 3 测试 lane 第三批）。
///
/// 只通过公开契约与可注入 fake 刻画协调器行为，不触碰私有状态、不做
/// private shadow、不触碰真实 IO：
/// - save 构建 DiaryEntry 全字段：新建空 filename / 已有原 filename
/// - DiaryProvider 成功后才 clearDraft；失败不 clear 且返回 typed Failure
/// - delete 的 filename 透传 / 成功清草稿 / 异常向上传播且草稿保留
/// - 草稿竞态：save/delete 等待 in-flight 草稿落盘后才调 provider 与
///   clear；旧写入不得晚于 clear 落盘；写入失败不悬挂；连续
///   performAutoSave 的 in-flight 指针指向最新写入
///
/// validation 分支（EditorSaveValidation/EditorDeleteValidation）为契约
/// 完整性保留、当前编排不产生，按「不可达则不臆造」原则不编写行为
/// 测试。
///
/// 时间控制统一使用 WidgetTester fake clock（`tester.pump(Duration)`），
/// 不真实等待；草稿 IO 全部走内存 fake。每个用例通过 addTearDown 释放
/// 会话控制器，避免 flutter_test 以「Timer 仍挂起」判定失败。
void main() {
  group('save 构建 DiaryEntry', () {
    testWidgets('新建：filename 为空字符串，日期/标题/正文/天气/心情/Markdown 全字段透传', (
      tester,
    ) async {
      final h = buildHarness();
      addTearDown(h.controller.dispose);
      h.controller.titleController.text = '标题';
      h.controller.contentController.text = '正文内容';
      h.controller.weather = WeatherType.snowy;
      h.controller.mood = MoodType.happy;
      h.controller.isMarkdown = true;
      h.controller.dateString = '2026-07-07';

      final result = await h.coordinator.save();

      expect(result, isA<EditorSaveSuccess>());
      final saved = (result as EditorSaveSuccess).entry;
      expect(saved.filename, isEmpty);
      expect(saved.dateString, '2026-07-07');
      expect(saved.title, '标题');
      expect(saved.content, '正文内容');
      expect(saved.weather, WeatherType.snowy);
      expect(saved.mood, MoodType.happy);
      expect(saved.isMarkdown, isTrue);
    });

    testWidgets('已有日记：filename 用原文件名，其余字段取自会话', (tester) async {
      final initial = entry(); // filename '2026-05-01_abc.txt'
      final h = buildHarness(initialEntry: initial);
      addTearDown(h.controller.dispose);
      h.controller.titleController.text = '新标题';
      h.controller.contentController.text = '新正文';
      h.controller.weather = WeatherType.windy;
      h.controller.mood = MoodType.tired;
      h.controller.isMarkdown = false;

      final result = await h.coordinator.save();

      expect(result, isA<EditorSaveSuccess>());
      final saved = (result as EditorSaveSuccess).entry;
      expect(saved.filename, initial.filename);
      expect(saved.dateString, initial.dateString);
      expect(saved.title, '新标题');
      expect(saved.content, '新正文');
      expect(saved.weather, WeatherType.windy);
      expect(saved.mood, MoodType.tired);
      expect(saved.isMarkdown, isFalse);
    });
  });

  group('保存结果与草稿清理', () {
    testWidgets('保存成功：DiaryProvider.saveEntry 先于清草稿，返回 Success 携带 entry', (
      tester,
    ) async {
      final h = buildHarness();
      addTearDown(h.controller.dispose);
      h.controller.contentController.text = '正文';

      final result = await h.coordinator.save();

      expect(result, isA<EditorSaveSuccess>());
      expect(h.service.savedEntries, hasLength(1));
      expect(h.draft.clearedIds, ['new']);
      // 关键顺序：provider 保存成功后才清草稿
      expect(h.order, ['saveEntry', 'clearDraft']);
    });

    testWidgets('保存失败：不清草稿、返回 typed Failure 携带错误对象', (tester) async {
      final h = buildHarness();
      addTearDown(h.controller.dispose);
      h.service.saveError = StateError('disk full');

      final result = await h.coordinator.save();

      expect(result, isA<EditorSaveFailure>());
      expect((result as EditorSaveFailure).error, isA<StateError>());
      expect(h.service.savedEntries, isEmpty);
      expect(h.draft.clearedIds, isEmpty);
    });
  });

  group('删除编排', () {
    testWidgets('删除成功：filename 透传、清草稿、返回 DeleteSuccess', (tester) async {
      final initial = entry();
      final h = buildHarness(initialEntry: initial);
      addTearDown(h.controller.dispose);

      final result = await h.coordinator.delete(initial.filename);

      expect(result, isA<EditorDeleteSuccess>());
      expect(h.service.deletedFilenames, [initial.filename]);
      expect(h.draft.clearedIds, [initial.filename]);
      expect(h.order, ['deleteEntry', 'clearDraft']);
    });

    testWidgets('删除失败：异常向上传播、草稿保留（原编排不吞异常）', (tester) async {
      final initial = entry();
      final h = buildHarness(initialEntry: initial);
      addTearDown(h.controller.dispose);
      h.service.deleteError = StateError('boom');

      await expectLater(
        h.coordinator.delete(initial.filename),
        throwsA(isA<StateError>()),
      );
      expect(h.service.deletedFilenames, isEmpty);
      expect(h.draft.clearedIds, isEmpty);
    });
  });

  group('草稿竞态', () {
    testWidgets('保存等待 in-flight 草稿落盘后才调 DiaryProvider 与清草稿：旧写入不晚于 clear', (
      tester,
    ) async {
      final h = buildHarness();
      addTearDown(h.controller.dispose);
      final gate = Completer<void>();
      h.draft.saveGate = gate;

      h.controller.contentController.text = '正文';
      await tester.pump(const Duration(seconds: 2)); // 防抖触发，草稿写入挂起

      final saveFuture = h.coordinator.save();
      await tester.pump();
      // in-flight 未完成：provider 未被调用，clear 未发生
      expect(h.service.savedEntries, isEmpty);
      expect(h.draft.clearedIds, isEmpty);
      expect(h.order, ['saveDraft:start']);

      gate.complete(); // 放行草稿写入
      final result = await saveFuture;

      expect(result, isA<EditorSaveSuccess>());
      expect(h.service.savedEntries, hasLength(1));
      expect(h.draft.clearedIds, ['new']);
      // 关键顺序：草稿写入 → DiaryProvider 保存 → 清草稿
      expect(h.order, [
        'saveDraft:start',
        'saveDraft:write',
        'saveEntry',
        'clearDraft',
      ]);
    });

    testWidgets('in-flight 草稿写入失败：awaitPendingAutoSave 不抛不悬挂，保存照常成功', (
      tester,
    ) async {
      final h = buildHarness();
      addTearDown(h.controller.dispose);
      final gate = Completer<void>();
      h.draft.saveGate = gate;
      h.draft.saveError = StateError('io failure');

      h.controller.contentController.text = '正文';
      await tester.pump(const Duration(seconds: 2)); // 草稿写入挂起

      final saveFuture = h.coordinator.save();
      await tester.pump();
      expect(h.service.savedEntries, isEmpty);

      gate.complete(); // 放行但写入抛错，不得悬挂主流程
      final result = await saveFuture;

      expect(result, isA<EditorSaveSuccess>());
      expect(h.service.savedEntries, hasLength(1));
      expect(h.draft.clearedIds, ['new']);
    });

    testWidgets('连续 performAutoSave：in-flight 指针指向最新写入，快照等待不悬挂', (
      tester,
    ) async {
      final h = buildHarness();
      addTearDown(h.controller.dispose);
      final gate = Completer<void>();
      h.draft.saveGate = gate;

      h.controller.contentController.text = 'v1';
      final f1 = h.controller.performAutoSave();
      h.controller.contentController.text = 'v2';
      final f2 = h.controller.performAutoSave();

      await tester.pump();
      expect(h.order, ['saveDraft:start', 'saveDraft:start']); // 两次均已启动

      final wait = h.controller.awaitPendingAutoSave();
      gate.complete(); // 放行两次写入
      await wait; // 快照等待最新 in-flight，不悬挂
      await f1;
      await f2;

      expect(h.draft.savedEntries.map((e) => e.content).toList(), ['v1', 'v2']);
      expect(h.order, [
        'saveDraft:start',
        'saveDraft:start',
        'saveDraft:write',
        'saveDraft:write',
      ]);

      // 两次文本输入各启动一个 2s 防抖 Timer，测试体结束时仍未触发，
      // 须在结束前显式取消（addTearDown 的 dispose 晚于 flutter_test 的
      // timersPending 校验，来不及清理）。
      h.controller.cancelPendingAutoSave();
    });

    testWidgets('草稿写入失败被防抖路径捕获：标记保留，再次输入可重试成功', (tester) async {
      final h = buildHarness();
      addTearDown(h.controller.dispose);
      h.draft.saveError = StateError('disk full');

      h.controller.contentController.text = 'v1';
      await tester.pump(const Duration(seconds: 2)); // 自动保存触发但写入失败
      expect(h.draft.savedEntries, isEmpty); // 失败未落盘
      expect(h.controller.hasDraftChanges, isTrue); // 标记保留可重试

      h.controller.contentController.text = 'v2'; // 再次输入
      await tester.pump(const Duration(seconds: 2)); // 重试成功
      expect(h.draft.savedEntries.single.content, 'v2');
      expect(h.controller.hasDraftChanges, isFalse);
    });
  });
}

/// 组装测试夹具：会话控制器 + 保存协调器 + 两个共享调用序日志的 fake。
///
/// order 同时记录草稿写入（saveDraft:start/write、clearDraft）与
/// DiaryProvider 动作（saveEntry/deleteEntry），用于断言跨边界顺序。
({
  EditorSaveCoordinator coordinator,
  EditorSessionController controller,
  GatedFakeDraftService draft,
  FakeDiaryService service,
  DiaryProvider provider,
  List<String> order,
})
buildHarness({DiaryEntry? initialEntry}) {
  final order = <String>[];
  final draft = GatedFakeDraftService(order: order);
  final service = FakeDiaryService(order: order);
  final provider = DiaryProvider(service: service);
  final controller = buildController(
    initialEntry: initialEntry,
    draftService: draft,
  );
  return (
    coordinator: EditorSaveCoordinator(
      diaryProvider: provider,
      session: controller,
    ),
    controller: controller,
    draft: draft,
    service: service,
    provider: provider,
    order: order,
  );
}

/// 在 [FakeDraftService] 基础上增加挂起门与一次性错误注入的草稿 fake。
///
/// saveDraft 语义：先记录 start（调用已启动），若设置挂起门则等待放行，
/// 放行后若注入错误则抛出（模拟写入失败，不落盘），否则记录 write 并
/// 落盘。写入动作发生在挂起门放行之后，能真实检验「协调器等待 in-flight
/// 完成才 clear」的防重写保证。
class GatedFakeDraftService extends FakeDraftService {
  GatedFakeDraftService({List<String>? order}) : _order = order ?? <String>[];

  final List<String> _order;

  /// 挂起门：非空时 saveDraft 在写入动作前等待放行。
  Completer<void>? saveGate;

  /// 一次性注入错误：放行后（或未挂起时）抛出并自动清除，用于模拟
  /// 写入失败后再次输入重试成功的路径。
  Object? saveError;

  @override
  Future<void> saveDraft(String id, DiaryEntry entry) async {
    _order.add('saveDraft:start');
    final gate = saveGate;
    if (gate != null) await gate.future;
    final error = saveError;
    if (error != null) {
      saveError = null; // 一次性：抛后允许重试成功
      throw error;
    }
    _order.add('saveDraft:write');
    savedIds.add(id);
    savedEntries.add(entry);
    drafts[id] = entry;
  }

  @override
  Future<void> clearDraft(String id) async {
    _order.add('clearDraft');
    await super.clearDraft(id);
  }
}

/// DiaryService 的内存替身：覆写全部 IO 方法，避免真实文件系统与
/// 平台通道；saveEntry/deleteEntry 支持挂起门与错误注入，并共享调用序
/// 日志用于断言「先 provider 后 clear」的顺序。
class FakeDiaryService extends DiaryService {
  FakeDiaryService({List<String>? order}) : _order = order ?? <String>[];

  final List<String> _order;

  /// 按序记录 saveEntry 的 entry（断言字段透传与调用次数）。
  final List<DiaryEntry> savedEntries = <DiaryEntry>[];

  /// 按序记录 deleteEntry 的 filename。
  final List<String> deletedFilenames = <String>[];

  /// saveEntry 挂起门（当前用例未使用，保留与草稿侧对称的能力）。
  Completer<void>? saveGate;

  /// 一次性 saveEntry 错误注入（抛后自动清除）。
  Object? saveError;

  /// deleteEntry 错误注入（抛后保留，删除路径不吞异常）。
  Object? deleteError;

  @override
  Future<void> init() async {}

  @override
  Future<List<DiaryEntry>?> loadCache() async => null;

  @override
  Future<List<DiaryEntry>> getEntries() async => <DiaryEntry>[];

  @override
  Future<void> saveCache(List<DiaryEntry> entries) async {}

  @override
  Future<String> saveEntry(DiaryEntry entry) async {
    _order.add('saveEntry');
    final error = saveError;
    if (error != null) {
      saveError = null;
      throw error;
    }
    final gate = saveGate;
    if (gate != null) await gate.future;
    savedEntries.add(entry);
    return entry.filename.isEmpty ? 'generated.txt' : entry.filename;
  }

  @override
  Future<void> deleteEntry(String filename) async {
    _order.add('deleteEntry');
    final error = deleteError;
    if (error != null) throw error;
    deletedFilenames.add(filename);
  }
}
