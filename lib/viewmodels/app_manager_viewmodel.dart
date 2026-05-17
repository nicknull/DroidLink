import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:android_manager/models/app_info.dart';
import 'package:android_manager/services/adb_service.dart';
import 'package:android_manager/constants/app_names.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppManagerViewModel extends ChangeNotifier {
  final AdbService _adb;
  final String _serial;
  Map<String, String> _labelCache = {}; // 本地缓存的 packageName → label
  Set<String> _favoritePkgNames = {}; // 收藏的包名集合

  List<AppInfo> _userApps = [];
  List<AppInfo> _systemApps = [];
  bool _showSystem = false;
  bool _loading = false;
  bool _installing = false;
  String? _error;
  String _searchQuery = '';
  bool _disposed = false;

  AppManagerViewModel(this._adb, this._serial);

  List<AppInfo> get apps => _showSystem ? _systemApps : _userApps;
  bool get showSystem => _showSystem;
  bool get loading => _loading;
  bool get installing => _installing;
  String? get error => _error;
  bool get hasAapt => _adb.hasAapt;

  List<AppInfo> get filteredApps {
    final list = (_searchQuery.isEmpty
        ? apps
        : apps
            .where((a) =>
                a.packageName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                a.displayLabel.toLowerCase().contains(_searchQuery.toLowerCase()))
    ).toList();
    _sortWithFavorites(list);
    return list;
  }

  void _sortWithFavorites(List<AppInfo> list) {
    list.sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase());
    });
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleSystem() {
    _showSystem = !_showSystem;
    notifyListeners();
  }

  Future<void> loadApps() async {
    _loading = true;
    _error = null;
    notifyListeners();

    // 加载本地缓存
    await _loadLabelCache();
    await _loadFavorites();

    try {
      final output = await _adb.getPackages(_serial, includeSystem: true);
      final lines = output.split('\n').where((l) => l.trim().isNotEmpty);
      final userApps = <AppInfo>[];
      final systemApps = <AppInfo>[];

      for (final line in lines) {
        var info = AppInfo.fromPmLine(line);
        if (info.packageName.isEmpty) continue;
        // 同步查表：映射表 → 本地缓存
        final label = kAppNames[info.packageName] ?? _labelCache[info.packageName];
        if (label != null) {
          info = info.copyWith(label: label);
        }
        // 标记收藏
        if (_favoritePkgNames.contains(info.packageName)) {
          info.isFavorite = true;
        }
        final isSystem = info.apkPath.contains('/system/') ||
            info.apkPath.contains('/vendor/') ||
            info.apkPath.contains('/system_ext/') ||
            info.apkPath.contains('/product/');
        if (isSystem) {
          systemApps.add(info);
        } else {
          userApps.add(info);
        }
      }

      _sortWithFavorites(userApps);
      _sortWithFavorites(systemApps);
      _userApps = userApps;
      _systemApps = systemApps;
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();

    // 异步加载详情（版本号、大小、应用名）
    _loadAppDetails();
  }

  Future<void> _loadAppDetails() async {
    // 先快速获取版本号和大小
    final allApps = [..._userApps, ..._systemApps];
    for (int i = 0; i < allApps.length; i++) {
      if (_disposed) return;
      final app = allApps[i];
      if (app.versionName.isNotEmpty && app.size > 0) continue;

      try {
        final dump = await _adb.getPackageDump(_serial, app.packageName);
        final versionMatch = RegExp(r'versionName=(\S+)').firstMatch(dump);
        final versionName = versionMatch?.group(1) ?? '';

        final sizeStr = await _adb.getApkSize(_serial, app.apkPath);
        final size = int.tryParse(sizeStr.trim()) ?? 0;

        final updated = app.copyWith(versionName: versionName, size: size);
        _updateApp(updated);
        if (i % 10 == 0 && !_disposed) notifyListeners();
      } catch (_) {}
    }
    if (!_disposed) notifyListeners();

    // 然后获取真实应用名（三层策略：映射表 → aapt → APK 解析）
    final apps = List.of(_userApps).where((a) => a.label.isEmpty).toList();
    if (apps.isEmpty) return;
    const concurrency = 3;
    for (int i = 0; i < apps.length; i += concurrency) {
      if (_disposed) return;
      final batch = apps.skip(i).take(concurrency);
      final results = await Future.wait(
        batch.map((app) async {
          try {
            final label = await _adb.getAppLabel(
              _serial, app.apkPath,
              packageName: app.packageName,
            );
            return (app, label);
          } catch (_) {
            return (app, null as String?);
          }
        }),
      );
      for (final (app, label) in results) {
        if (label != null && label.isNotEmpty) {
          _updateApp(app.copyWith(label: label));
          _labelCache[app.packageName] = label;
        }
      }
      if (!_disposed) notifyListeners();
    }
    // 保存缓存到本地
    await _saveLabelCache();
  }

  void _updateApp(AppInfo updated) {
    final idx = _userApps.indexWhere((a) => a.packageName == updated.packageName);
    if (idx != -1) {
      _userApps[idx] = updated;
      _sortWithFavorites(_userApps);
    }
    final sidx = _systemApps.indexWhere((a) => a.packageName == updated.packageName);
    if (sidx != -1) {
      _systemApps[sidx] = updated;
      _sortWithFavorites(_systemApps);
    }
  }

  // ============ 收藏功能 ============

  Future<File> _favoritesFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'favorite_apps.json'));
  }

  Future<void> _loadFavorites() async {
    try {
      final file = await _favoritesFile();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as List;
        _favoritePkgNames = json.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
  }

  Future<void> _saveFavorites() async {
    try {
      final file = await _favoritesFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_favoritePkgNames.toList()));
    } catch (_) {}
  }

  void toggleFavorite(String packageName) {
    final list = _showSystem ? _systemApps : _userApps;
    final idx = list.indexWhere((a) => a.packageName == packageName);
    if (idx == -1) return;

    final app = list[idx];
    final newFavorite = !app.isFavorite;
    list[idx] = app.copyWith(isFavorite: newFavorite);

    if (newFavorite) {
      _favoritePkgNames.add(packageName);
    } else {
      _favoritePkgNames.remove(packageName);
    }
    _saveFavorites();
    notifyListeners();
  }

  // ============ 权限管理 ============

  Future<Map<String, bool>> getAppPermissions(String packageName) async {
    return _adb.getAppPermissions(_serial, packageName);
  }

  Future<bool> grantPermission(String packageName, String permission) async {
    return _adb.grantPermission(_serial, packageName, permission);
  }

  Future<bool> revokePermission(String packageName, String permission) async {
    return _adb.revokePermission(_serial, packageName, permission);
  }

  Future<bool> clearAppData(String packageName) async {
    return _adb.clearAppData(_serial, packageName);
  }

  Future<bool> forceStopApp(String packageName) async {
    return _adb.forceStopApp(_serial, packageName);
  }

  // ============ 缓存 ============

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'app_labels.json'));
  }

  Future<void> _loadLabelCache() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _labelCache = json.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
  }

  Future<void> _saveLabelCache() async {
    try {
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_labelCache));
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<bool> uninstall(String packageName) async {
    return _adb.uninstallApp(_serial, packageName);
  }

  Future<bool> installApk(String apkPath) async {
    _installing = true;
    notifyListeners();
    final ok = await _adb.installApk(_serial, apkPath);
    _installing = false;
    if (ok) await loadApps();
    notifyListeners();
    return ok;
  }

  Future<bool> exportApk(AppInfo app, String localDir) async {
    final localPath = p.join(localDir, '${app.packageName}.apk');
    return _adb.pullFile(_serial, app.apkPath, localPath);
  }
}
