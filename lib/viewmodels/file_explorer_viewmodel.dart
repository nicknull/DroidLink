import 'package:flutter/foundation.dart';
import 'package:android_manager/models/file_item.dart';
import 'package:android_manager/services/adb_service.dart';
import 'package:android_manager/utils/constants.dart';
import 'package:path/path.dart' as p;

class FileExplorerViewModel extends ChangeNotifier {
  final AdbService _adb;
  final String _serial;

  String _currentPath = AppConstants.defaultStartPath;
  List<FileItem> _files = [];
  Set<String> _selectedPaths = {};
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  FileExplorerViewModel(this._adb, this._serial);

  String get currentPath => _currentPath;
  List<FileItem> get files => _files;
  Set<String> get selectedPaths => _selectedPaths;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasSelection => _selectedPaths.isNotEmpty;

  Future<void> loadDirectory([String? path]) async {
    _currentPath = path ?? _currentPath;
    _loading = true;
    _error = null;
    _selectedPaths.clear();
    if (!_disposed) notifyListeners();

    try {
      final lines = await _adb.listFiles(_serial, _currentPath);
      _files = lines
          .skip(1)
          .map((l) => FileItem.fromLsLine(l, _currentPath))
          .where((f) => f.name.isNotEmpty && f.name != '.' && f.name != '..')
          .toList();

      _files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    if (!_disposed) notifyListeners();
  }

  void toggleSelection(String path) {
    if (_selectedPaths.contains(path)) {
      _selectedPaths.remove(path);
    } else {
      _selectedPaths.add(path);
    }
    if (!_disposed) notifyListeners();
  }

  void selectAll() {
    _selectedPaths = _files.map((f) => f.path).toSet();
    if (!_disposed) notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    if (!_disposed) notifyListeners();
  }

  void navigateUp() {
    if (_currentPath == '/') return;
    final parent = _currentPath.substring(0, _currentPath.lastIndexOf('/'));
    loadDirectory(parent.isEmpty ? '/' : parent);
  }

  Future<int> deleteSelected() async {
    int count = 0;
    final items = _files.where((f) => _selectedPaths.contains(f.path)).toList();
    for (final item in items) {
      final ok = await _adb.deleteFile(_serial, item.path, recursive: item.isDirectory);
      if (ok) count++;
    }
    _selectedPaths.clear();
    await loadDirectory();
    return count;
  }

  Future<bool> uploadFile(String localPath) async {
    final name = p.basename(localPath);
    final remotePath = '$_currentPath/$name';
    final ok = await _adb.pushFile(_serial, localPath, remotePath);
    if (ok) await loadDirectory();
    return ok;
  }

  Future<int> downloadSelected(String localDir) async {
    int count = 0;
    final items = _files.where((f) => _selectedPaths.contains(f.path)).toList();
    for (final item in items) {
      final localPath = p.join(localDir, item.name);
      final ok = await _adb.pullFile(_serial, item.path, localPath);
      if (ok) count++;
    }
    _selectedPaths.clear();
    if (!_disposed) notifyListeners();
    return count;
  }

  Future<bool> createFolder(String name) async {
    final ok = await _adb.mkdir(_serial, '$_currentPath/$name');
    if (ok) await loadDirectory();
    return ok;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
