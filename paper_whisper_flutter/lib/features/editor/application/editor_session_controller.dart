import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/diary_entry.dart';
import '../../../services/draft_service.dart';

/// 草稿恢复判定结果（纯数据，由页面决定如何展示与执行）。
class DraftRestoreInfo {
  const DraftRestoreInfo({required this.draft, required this.isIncomplete});

  /// 本地草稿内容
  final DiaryEntry draft;

  /// 草稿内容是否少于原日记（上次编辑可能意外中断）
  final bool isIncomplete;
}

/// 编辑会话控制器：持有编辑状态、草稿生命周期与自动保存编排。
///
/// 职责边界：
/// - 标题/正文/200 字预览三个 TextEditingController
/// - 日期/天气/心情/Markdown 等编辑元数据与 hasChanges 判定
/// - 草稿恢复判定、防抖自动保存、立即保存与成功清理
/// - 防抖 Timer 与 listener 的生命周期管理
///
/// 不持有 BuildContext，不负责 Toast/Dialog/Navigator，展示层由页面负责。
class EditorSessionController {
  EditorSessionController({
    required DiaryEntry? initialEntry,
    required DraftService draftService,
  }) : _initialEntry = initialEntry,
       _draftService = draftService,
       _draftId = initialEntry?.filename ?? 'new',
       weather = initialEntry?.weather ?? WeatherType.sunny,
       mood = initialEntry?.mood ?? MoodType.calm,
       isMarkdown = initialEntry?.isMarkdown ?? false,
       isEditing = (initialEntry == null),
       dateString =
           initialEntry?.dateString ?? DateTime.now().toString().split(' ')[0] {
    final fullText = initialEntry?.content ?? '';
    titleController = TextEditingController(text: initialEntry?.title ?? '');
    contentController = TextEditingController(text: fullText);

    // 初始化预览控制器：只截取前 200 字符（约一屏），极致减少渲染压力
    // 1000字符依然会导致显著卡顿，200字符是性能与视觉填充的平衡点
    previewController = TextEditingController(
      text: fullText.length > 200 ? fullText.substring(0, 200) : fullText,
    );

    // 监听内容变更，驱动防抖自动保存
    titleController.addListener(_onTextChanged);
    contentController.addListener(_onTextChanged);
  }

  final DiaryEntry? _initialEntry;
  final DraftService _draftService;
  final String _draftId;

  // 编辑状态
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late final TextEditingController previewController;

  WeatherType weather;
  MoodType mood;
  bool isMarkdown;
  bool isEditing;
  String dateString;

  // 草稿状态
  Timer? _autoSaveTimer;
  bool _hasDraftChanges = false;
  bool _hasCheckedDraft = false;
  bool _suppressTextListener = false;
  bool _disposed = false;

  /// 是否有未保存的修改（新建：非空内容；编辑：与初始值比较）。
  bool get hasChanges {
    if (_initialEntry == null) {
      return titleController.text.isNotEmpty ||
          contentController.text.isNotEmpty;
    }
    return titleController.text != _initialEntry.title ||
        contentController.text != _initialEntry.content ||
        weather != _initialEntry.weather ||
        mood != _initialEntry.mood;
  }

  /// 是否存在未落盘的草稿变更。
  bool get hasDraftChanges => _hasDraftChanges;

  // ---- 内容监听与防抖自动保存 ----

  void _onTextChanged() {
    if (_suppressTextListener) return;
    if (!isEditing) return;

    // 重置计时器：2 秒无输入后自动保存草稿
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), performAutoSave);
    _hasDraftChanges = true;
  }

  /// 停止防抖计时器并清除草稿变更标记（保存/删除前调用，避免竞态）。
  void cancelPendingAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _hasDraftChanges = false;
  }

  /// 立即保存草稿（防抖回调或页面切后台时调用）。
  Future<void> performAutoSave() async {
    if (_disposed || !_hasDraftChanges) return;
    if (titleController.text.isEmpty && contentController.text.isEmpty) {
      return; // 空内容不存
    }

    final currentEntry = DiaryEntry(
      filename: _draftId == 'new' ? '' : _draftId,
      dateString: dateString,
      title: titleController.text,
      weather: weather,
      mood: mood,
      content: contentController.text,
      isMarkdown: isMarkdown,
    );

    await _draftService.saveDraft(_draftId, currentEntry);
    _hasDraftChanges = false;
  }

  /// 将正文最新内容同步到预览控制器（200 字截断，路由 reverse 时调用）。
  void syncPreviewText() {
    final fullText = contentController.text;
    final trunk = fullText.length > 200 ? fullText.substring(0, 200) : fullText;
    if (previewController.text != trunk) {
      previewController.text = trunk;
    }
  }

  // ---- 草稿恢复 ----

  /// 检查本地草稿并返回恢复判定（仅首次有效）。
  /// 返回 null 表示无需恢复（无草稿/草稿与原文一致/空草稿已清理）。
  Future<DraftRestoreInfo?> checkDraftRestore() async {
    if (_hasCheckedDraft) return null;
    _hasCheckedDraft = true;

    final draft = await _draftService.getDraft(_draftId);
    if (draft == null) return null;

    // 编辑旧日记：草稿与原文一致则清理残留，无需恢复
    if (_draftId != 'new') {
      final currentContent = _initialEntry?.content ?? '';
      if (draft.content == currentContent &&
          draft.title == (_initialEntry?.title ?? '')) {
        await _draftService.clearDraft(_draftId);
        return null;
      }
    } else {
      // 新建：空草稿直接清理
      if (draft.content.isEmpty && draft.title.isEmpty) {
        await _draftService.clearDraft(_draftId);
        return null;
      }
    }

    bool isIncomplete = false;
    if (_draftId != 'new' && _initialEntry != null) {
      if (draft.content.length < _initialEntry.content.length) {
        isIncomplete = true;
      }
    }

    return DraftRestoreInfo(draft: draft, isIncomplete: isIncomplete);
  }

  /// 以草稿内容覆盖编辑会话（程序化赋值，不触发防抖草稿保存）。
  void restoreFromDraft(DiaryEntry draft) {
    _suppressTextListener = true;
    titleController.text = draft.title;
    contentController.text = draft.content;
    _suppressTextListener = false;

    weather = draft.weather;
    mood = draft.mood;
    dateString = draft.dateString;
  }

  /// 清除本地草稿（保存成功/丢弃草稿时调用）。
  Future<void> clearDraft() => _draftService.clearDraft(_draftId);

  // ---- 生命周期 ----

  /// 释放所有 Controller、Timer 与监听器；调用后不得再使用本实例。
  void dispose() {
    _disposed = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    titleController.removeListener(_onTextChanged);
    contentController.removeListener(_onTextChanged);
    titleController.dispose();
    contentController.dispose();
    previewController.dispose();
  }
}
