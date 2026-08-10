import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/features/diary/application/diary_provider.dart';
import 'editor_session_controller.dart';

/// 保存编排结果（穷尽分支：validation / success / failure）。
///
/// 页面只负责翻译结果：success 走同步反馈与返回，failure 展示错误
/// 提示，validation 为契约完整性保留（当前编排不产生，防御处理）。
sealed class EditorSaveResult {
  const EditorSaveResult();
}

/// 校验失败：当前编排流程不产生该分支，为契约完整性保留。
class EditorSaveValidation extends EditorSaveResult {
  const EditorSaveValidation();
}

/// 保存成功：携带已保存的日记供页面做后续同步反馈。
class EditorSaveSuccess extends EditorSaveResult {
  const EditorSaveSuccess({required this.entry});

  final DiaryEntry entry;
}

/// 保存失败：携带异常供页面展示错误文案。
class EditorSaveFailure extends EditorSaveResult {
  const EditorSaveFailure({required this.error});

  final Object error;
}

/// 删除编排结果（穷尽分支：validation / success / failure）。
sealed class EditorDeleteResult {
  const EditorDeleteResult();
}

/// 校验失败：当前编排流程不产生该分支，为契约完整性保留。
class EditorDeleteValidation extends EditorDeleteResult {
  const EditorDeleteValidation();
}

/// 删除成功。
class EditorDeleteSuccess extends EditorDeleteResult {
  const EditorDeleteSuccess();
}

/// 删除失败：当前编排不捕获删除异常（与页面原行为一致，异常向上
/// 传播），该分支保留为契约完整性。
class EditorDeleteFailure extends EditorDeleteResult {
  const EditorDeleteFailure({required this.error});

  final Object error;
}

/// 保存/删除业务编排协调器。
///
/// 职责边界：
/// - 构建 DiaryEntry（日期/天气/心情/Markdown 字段来自会话控制器）
/// - 保存/删除前停止防抖并等待 in-flight 草稿落盘，防止成功清草稿后
///   被旧草稿重写
/// - 调用 DiaryProvider.saveEntry/deleteEntry，成功清草稿、失败保留
/// - 返回穷尽 typed result，不持有 BuildContext/Toast/Dialog/Navigator
///
/// 页面保留：删除确认 Dialog、错误 Toast、SyncUiCoordinator 同步反馈、
/// route reverse 与 Navigator，只翻译 typed result。
class EditorSaveCoordinator {
  EditorSaveCoordinator({
    required DiaryProvider diaryProvider,
    required EditorSessionController session,
  }) : _diaryProvider = diaryProvider,
       _session = session;

  final DiaryProvider _diaryProvider;
  final EditorSessionController _session;

  /// 保存当前编辑会话。
  ///
  /// 与页面原编排一致：先取消防抖并等待 in-flight 草稿写入落盘，
  /// 再构建 DiaryEntry 调用 saveEntry；成功清草稿并返回
  /// [EditorSaveSuccess]，失败保留草稿并返回 [EditorSaveFailure]。
  Future<EditorSaveResult> save() async {
    // 1. 停止防抖，等待进行中的自动保存落盘，避免 clearDraft 之后被
    //    in-flight 草稿写入重写。
    _session.cancelPendingAutoSave();
    await _session.awaitPendingAutoSave();

    final newEntry = DiaryEntry(
      filename: _session.draftId == 'new' ? '' : _session.draftId,
      dateString: _session.dateString,
      title: _session.titleController.text,
      weather: _session.weather,
      mood: _session.mood,
      content: _session.contentController.text,
      isMarkdown: _session.isMarkdown,
    );

    try {
      await _diaryProvider.saveEntry(newEntry);
      // 保存成功：清除本地草稿
      await _session.clearDraft();
      return EditorSaveSuccess(entry: newEntry);
    } catch (e) {
      // 保存失败：保留草稿，交由页面展示错误
      return EditorSaveFailure(error: e);
    }
  }

  /// 删除指定日记（页面在确认弹窗前已同步取消防抖）。
  ///
  /// 与原页面行为一致：删除失败不吞异常（原逻辑无 catch），异常向
  /// 上传播由 Flutter 错误处理兜底；成功后清草稿并返回
  /// [EditorDeleteSuccess]。
  Future<EditorDeleteResult> delete(String filename) async {
    // 防御性再取消一次（幂等）；等待 in-flight 草稿落盘
    _session.cancelPendingAutoSave();
    await _session.awaitPendingAutoSave();

    await _diaryProvider.deleteEntry(filename);
    // 删除成功：清除残留草稿
    await _session.clearDraft();
    return const EditorDeleteSuccess();
  }
}
