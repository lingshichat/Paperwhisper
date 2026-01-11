import 'package:flutter/foundation.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class DiaryProvider with ChangeNotifier {
  final DiaryService _service;
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String _debugPath = '';

  List<DiaryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String get debugPath => _debugPath;
  DiaryService get service => _service;

  DiaryProvider([DiaryService? service]) : _service = service ?? DiaryService() {
    loadEntries();
  }

  Future<void> loadEntries() async {
    _isLoading = true;
    notifyListeners(); // 触发 UI 显示 loading
    try {
      await _service.init();
      _debugPath = _service.currentDataPath;
      _entries = await _service.getEntries();
    } catch (e) {
      debugPrint("Error loading entries: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadAfterPermission() async {
    _service.reset();
    await loadEntries();
  }

  Future<void> saveEntry(DiaryEntry entry) async {
    await _service.saveEntry(entry);
    await loadEntries(); // 重新加载以更新列表
  }

  Future<void> deleteEntry(String filename) async {
    await _service.deleteEntry(filename);
    await loadEntries();
  }
}
