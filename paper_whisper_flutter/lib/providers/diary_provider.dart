import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class DiaryProvider with ChangeNotifier {
  final DiaryService _service;
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String _debugPath = '';

  // New: Flattened List Support
  List<dynamic> _flatEntries = [];
  // Key: "yyyy_M" (e.g. "2026_1"), Value: index in _flatEntries
  Map<String, int> _monthIndexMap = {}; 


  String _searchQuery = '';
  

  List<DiaryEntry> get entries => _entries;
  List<dynamic> get flatEntries => _flatEntries;
  Map<String, int> get monthIndexMap => _monthIndexMap;

  bool get isLoading => _isLoading;
  String get debugPath => _debugPath;
  DiaryService get service => _service;
  String get searchQuery => _searchQuery;

  DiaryProvider([DiaryService? service]) : _service = service ?? DiaryService() {
    loadEntries();
    _loadBookTitles();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadEntries() async {
    _isLoading = true;
    notifyListeners(); // 触发 UI 显示 loading
    try {
      await _service.init();
      _debugPath = _service.currentDataPath;
      _entries = await _service.getEntries();
      
      // Sort Descending (Reverse Chronological: Newest -> Oldest)
      _entries.sort((a, b) => b.dateString.compareTo(a.dateString));
      
      _buildFlatList();
    } catch (e) {
      debugPrint("Error loading entries: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _buildFlatList() {
    _flatEntries.clear();
    _monthIndexMap.clear();

    if (_entries.isEmpty) return;

    int currentYear = -1;
    int currentMonth = -1;

    for (var entry in _entries) {
      // Parse date manually to avoid DateTime overhead if format is strict yyyy-MM-dd
      final parts = entry.dateString.split('-');
      if (parts.length < 2) continue;
      
      final y = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;

      if (y != currentYear || m != currentMonth) {
        currentYear = y;
        currentMonth = m;
        
        final key = '${currentYear}_$currentMonth';
        // Check if map already has this key (should not happen if sorted, but safety check)
        if (!_monthIndexMap.containsKey(key)) {
           _monthIndexMap[key] = _flatEntries.length;
           _flatEntries.add(MonthHeader(year: currentYear, month: currentMonth));
        }
      }
      _flatEntries.add(entry);
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

  // --- Book Shelf Logic ---

  // Custom book metadata: Year -> Value
  Map<int, String> _bookTitles = {};
  Map<int, String> _bookSubtitles = {};
  Map<int, String> _bookCoverPaths = {};

  // Custom month metadata: "Year_Month" -> Title
  Map<String, String> _monthTitles = {};

  Map<int, String> get bookTitles => _bookTitles; // Keep for backward compatibility if needed, but prefer getters below

  Future<void> _loadBookTitles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      _bookTitles.clear();
      _bookSubtitles.clear();
      _bookCoverPaths.clear();
      _monthTitles.clear();

      for (var key in keys) {
        if (key.startsWith('book_title_')) {
           final yearStr = key.substring('book_title_'.length);
           final year = int.tryParse(yearStr);
           if (year != null) _bookTitles[year] = prefs.getString(key) ?? '';
        } else if (key.startsWith('book_subtitle_')) {
           final yearStr = key.substring('book_subtitle_'.length);
           final year = int.tryParse(yearStr);
           if (year != null) _bookSubtitles[year] = prefs.getString(key) ?? '';
        } else if (key.startsWith('book_cover_')) {
           final yearStr = key.substring('book_cover_'.length);
           final year = int.tryParse(yearStr);
           if (year != null) _bookCoverPaths[year] = prefs.getString(key) ?? '';
        } else if (key.startsWith('month_title_')) {
           // Format: month_title_{year}_{month}
           final parts = key.split('_');
           if (parts.length == 4) {
             final yearStr = parts[2];
             final monthStr = parts[3];
             _monthTitles['${yearStr}_${monthStr}'] = prefs.getString(key) ?? '';
           }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading book meta: $e");
    }
  }

  /// Sets book metadata. Pass null to keep existing value.
  Future<void> setBookInfo(int year, {String? title, String? subtitle, String? coverPath}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (title != null) {
      _bookTitles[year] = title;
      await prefs.setString('book_title_$year', title);
    }
    
    if (subtitle != null) {
      _bookSubtitles[year] = subtitle;
      await prefs.setString('book_subtitle_$year', subtitle);
    }
    
    if (coverPath != null) {
      _bookCoverPaths[year] = coverPath;
      await prefs.setString('book_cover_$year', coverPath);
    }

    notifyListeners();
  }

  /// Resets book metadata fields to default (removes from persistence).
  Future<void> resetBookInfo(int year, {bool title = false, bool subtitle = false, bool cover = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (title) {
      _bookTitles.remove(year);
      await prefs.remove('book_title_$year');
    }
    
    if (subtitle) {
      _bookSubtitles.remove(year);
      await prefs.remove('book_subtitle_$year');
    }
    
    if (cover) {
      _bookCoverPaths.remove(year);
      await prefs.remove('book_cover_$year');
    }

    notifyListeners();
  }
  
  // Month Title Methods
  
  Future<void> setMonthTitle(int year, int month, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${year}_$month';
    _monthTitles[key] = title;
    await prefs.setString('month_title_$key', title);
    notifyListeners();
  }
  
  Future<void> resetMonthTitle(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${year}_$month';
    _monthTitles.remove(key);
    await prefs.remove('month_title_$key');
    notifyListeners();
  }
  
  String getMonthTitle(int year, int month) {
    return _monthTitles['${year}_$month'] ?? '$month 月';
  }
  
  // Deprecated: use setBookInfo
  Future<void> setBookTitle(int year, String title) async {
    await setBookInfo(year, title: title);
  }

  String getBookTitle(int year) {
    return _bookTitles[year] ?? '你的专属故事'; // Default title
  }
  
  String getBookSubtitle(int year) {
    return _bookSubtitles[year] ?? '$year年'; // Default subtitle
  }
  
  String? getBookCoverPath(int year) {
    return _bookCoverPaths[year];
  }

  /// Group entries by Year -> Month -> List<DiaryEntry>
  /// Returns sorted map (descending years, descending months)
  Map<int, Map<int, List<DiaryEntry>>> getEntriesGroupedByYearMonth() {
    final Map<int, Map<int, List<DiaryEntry>>> grouped = {};

    for (var entry in _entries) {
      // Parse date: yyyy-MM-dd
      final parts = entry.dateString.split('-');
      if (parts.length >= 2) {
        final year = int.tryParse(parts[0]) ?? DateTime.now().year;
        final month = int.tryParse(parts[1]) ?? DateTime.now().month;

        grouped.putIfAbsent(year, () => {});
        grouped[year]!.putIfAbsent(month, () => []);
        grouped[year]![month]!.add(entry);
      }
    }

    // Sort Years (Descending)
    final sortedYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<int, Map<int, List<DiaryEntry>>> sortedGrouped = {};

    for (var year in sortedYears) {
      final monthMap = grouped[year]!;
      // Sort Months (Descending)
      final sortedMonths = monthMap.keys.toList()..sort((a, b) => b.compareTo(a));
      
      final Map<int, List<DiaryEntry>> sortedMonthMap = {};
      for (var month in sortedMonths) {
        sortedMonthMap[month] = monthMap[month]!;
      }
      sortedGrouped[year] = sortedMonthMap;
    }

    return sortedGrouped;
  }
}


/// Helper class for the flattened list headers
class MonthHeader {
  final int year;
  final int month;

  const MonthHeader({required this.year, required this.month});
}
