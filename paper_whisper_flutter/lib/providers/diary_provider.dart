import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class DiaryProvider with ChangeNotifier {
  final DiaryService _service;
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  int _lastUpdateTick = 0; // Data versioning for UI cache invalidation
  String _debugPath = '';

  // New: Flattened List Support
  List<dynamic> _flatEntries = [];
  // Key: "yyyy_M" (e.g. "2026_1"), Value: index in _flatEntries
  Map<String, int> _monthIndexMap = {}; 


  String _diarySearchQuery = '';
  String _momentsSearchQuery = '';


  List<DiaryEntry> get entries => _entries;
  List<dynamic> get flatEntries => _flatEntries;
  Map<String, int> get monthIndexMap => _monthIndexMap;

  bool get isLoading => _isLoading;
  String get debugPath => _debugPath;
  DiaryService get service => _service;
  String get diarySearchQuery => _diarySearchQuery;
  String get momentsSearchQuery => _momentsSearchQuery;
  String get searchQuery => _diarySearchQuery;
  int get lastUpdateTick => _lastUpdateTick;

  DiaryProvider([DiaryService? service, List<DiaryEntry>? initialEntries]) : _service = service ?? DiaryService() {
    if (initialEntries != null && initialEntries.isNotEmpty) {
      _entries = initialEntries;
      _isLoading = false;
      _buildFlatList();
      // Metadata needs service init, which might not be fully ready if we just passed entries? 
      // Actually main.dart will call service.init(), so it should be fine.
      // We still run loadEntries in background to sync with file system
      loadEntries(silent: true);
    } else {
      loadEntries();
    }
  }

  void setDiarySearchQuery(String query) {
    _diarySearchQuery = query;
    notifyListeners();
  }

  void setMomentsSearchQuery(String query) {
    _momentsSearchQuery = query;
    notifyListeners();
  }

  // Legacy fallback
  void setSearchQuery(String query) {
    setDiarySearchQuery(query);
  }

  Future<void> loadEntries({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners(); 
    }
    
    try {
      await _service.init();
      _debugPath = _service.currentDataPath;

      // 1. 尝试优先读取缓存 (Fast Path) - Only if not silent (if silent, we assume cache is already loaded via constructor)
      if (!silent) {
        final cachedEntries = await _service.loadCache();
        if (cachedEntries != null && cachedEntries.isNotEmpty) {
          _entries = cachedEntries;
          _buildFlatList();
          notifyListeners(); 
          // Keep isLoading false to show content while loading files in background?
          // Strategy: If we show cache, we are "loaded".
          // But 'silent' is false here, so we are in standard load.
          // Let's set isLoading = false so user sees content.
          _isLoading = false; 
          notifyListeners();
        }
      }

      // 2. 读取真实文件 (Source of Truth)
      final fileEntries = await _service.getEntries();
      
      // Sort Descending
      fileEntries.sort((a, b) {
        int res = b.dateString.compareTo(a.dateString);
        if (res != 0) return res;
        if (a.lastModified != null && b.lastModified != null) {
          return b.lastModified!.compareTo(a.lastModified!);
        }
        return 0;
      });
      
      // 3. 更新内存 (Diff check could be optimized, but for now just replace)
      _entries = fileEntries;
      _buildFlatList();
      await _loadBookMetadata(); 
      
      // 4. 更新缓存文件
      await _service.saveCache(_entries);

    } catch (e) {
      debugPrint("Error loading entries: $e");
    } finally {
      _lastUpdateTick++; // Increment version after any data change
      if (!silent) {
         _isLoading = false;
         notifyListeners();
      } else {
         notifyListeners();
      }
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

  // --- Persistent Metadata Logic (JSON + Sync) ---

  Future<void> _loadBookMetadata() async {
    try {
      // 1. Ensure Service Init
      await _service.init();
      if (_service.dataDir == null) return;

      final metaFile = File(path.join(_service.dataDir!.path, 'book_metadata.json'));
      
      if (await metaFile.exists()) {
        try {
          final jsonStr = await metaFile.readAsString();
          final data = jsonDecode(jsonStr);
          
          // Parse "books"
          if (data['books'] != null) {
            Map<String, dynamic> books = data['books'];
            books.forEach((yearStr, val) {
               final year = int.tryParse(yearStr);
               if (year != null && val is Map) {
                 if (val['title'] != null) _bookTitles[year] = val['title'];
                 if (val['subtitle'] != null) _bookSubtitles[year] = val['subtitle'];
                 
                 // Reconstruct absolute path for cover
                 if (val['cover'] != null) {
                   final coverName = val['cover'];
                   final coverFile = File(path.join(_service.dataDir!.path, coverName));
                   _bookCoverPaths[year] = coverFile.path;
                 }
               }
            });
          }
          
          // Parse "months"
          if (data['months'] != null) {
            Map<String, dynamic> months = data['months'];
            months.forEach((key, val) {
               _monthTitles[key] = val.toString();
            });
          }
          
          notifyListeners();
          return; // Successfully loaded from JSON, skip SharedPreferences fallback
        } catch (e) {
          debugPrint("Error parsing book_metadata.json: $e");
        }
      }

      // 2. Fallback to SharedPreferences (Migration or Legacy)
      await _loadBookTitlesLegacy(); 
      
    } catch (e) {
       debugPrint("Error loading book metadata: $e");
    }
  }

  Future<void> _loadBookTitlesLegacy() async {
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
      debugPrint("Error loading legacy book meta: $e");
    }
  }

  Future<void> _saveBookMetadata() async {
    if (_service.dataDir == null) return;
    
    final Map<String, dynamic> data = {
      'books': {},
      'months': _monthTitles,
    };
    
    // Aggregate Book Info
    Set<int> allYears = {};
    allYears.addAll(_bookTitles.keys);
    allYears.addAll(_bookSubtitles.keys);
    allYears.addAll(_bookCoverPaths.keys);
    
    for (var year in allYears) {
      Map<String, dynamic> bookInfo = {};
      if (_bookTitles.containsKey(year)) bookInfo['title'] = _bookTitles[year];
      if (_bookSubtitles.containsKey(year)) bookInfo['subtitle'] = _bookSubtitles[year];
      
      if (_bookCoverPaths.containsKey(year)) {
        // Convert strict absolute path to filename if possible
        String fullPath = _bookCoverPaths[year]!;
        String filename = path.basename(fullPath);
        // Only save filename if it lives in dataDir (standardized)
        // If it's a legacy path (random spot), we might lose it on sync, 
        // but setBookInfo now enforces copying, so this should remain valid for new edits.
        bookInfo['cover'] = filename; 
      }
      data['books'][year.toString()] = bookInfo;
    }
    
    try {
      final jsonStr = jsonEncode(data);
      final metaFile = File(path.join(_service.dataDir!.path, 'book_metadata.json'));
      await metaFile.writeAsString(jsonStr);
      
      // Update Manifest for Sync
      _service.manifestService.updateItem('book_metadata.json', isDeleted: false);
    } catch (e) {
      debugPrint("Error saving book_metadata.json: $e");
    }
  }

  /// Sets book metadata and handles persistence/sync
  Future<void> setBookInfo(int year, {String? title, String? subtitle, String? coverPath}) async {
    await _service.init();
    
    if (title != null) _bookTitles[year] = title;
    if (subtitle != null) _bookSubtitles[year] = subtitle;
    
    if (coverPath != null) {
      // 1. Copy Image to Permanent Storage
      if (_service.dataDir != null) {
        try {
          final file = File(coverPath);
          if (await file.exists()) {
             final ext = path.extension(coverPath);
             // Use consistent filename: cover_2026.jpg
             final newFilename = 'cover_$year$ext'; 
             final newPath = path.join(_service.dataDir!.path, newFilename);
             
             // Avoid copy if already there
             if (path.normalize(coverPath) != path.normalize(newPath)) {
                await file.copy(newPath);
             }
             
             _bookCoverPaths[year] = newPath;
             
             // Update Manifest for Custom Cover
             _service.manifestService.updateItem(newFilename, isDeleted: false);
          }
        } catch (e) {
           debugPrint("Error copying cover image: $e");
           _bookCoverPaths[year] = coverPath; // Fallback
        }
      } else {
         _bookCoverPaths[year] = coverPath;
      }
    }

    notifyListeners(); // Immediate UI update
    
    // 2. Persist to JSON
    await _saveBookMetadata();
    
    // 3. Legacy Backup (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();
    if (title != null) await prefs.setString('book_title_$year', title);
    if (subtitle != null) await prefs.setString('book_subtitle_$year', subtitle);
    if (coverPath != null) await prefs.setString('book_cover_$year', _bookCoverPaths[year]!);
  }

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
      // Logic: If we reset cover, should we delete the file?
      // Optionally yes, to clean up, or just remove reference.
      // Let's remove reference for safety.
      if (_bookCoverPaths.containsKey(year)) {
      }
      _bookCoverPaths.remove(year);
      await prefs.remove('book_cover_$year');
      
      // Note: We don't mark cover file as isDeleted in manifest because we didn't physically delete it.
      // If we wanted to, we would:
      // _service.manifestService.updateItem('cover_$year.jpg', isDeleted: true);
    }

    notifyListeners();
    await _saveBookMetadata();
  }
  
  // Month Title Methods
  
  Future<void> setMonthTitle(int year, int month, String title) async {
    final key = '${year}_$month';
    _monthTitles[key] = title;
    notifyListeners();
    
    await _saveBookMetadata();
    
    // Legacy
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('month_title_$key', title);
  }
  
  Future<void> resetMonthTitle(int year, int month) async {
    final key = '${year}_$month';
    _monthTitles.remove(key);
    notifyListeners();
    
    await _saveBookMetadata();
    
    // Legacy
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('month_title_$key');
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
