import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:android_manager/models/media_item.dart';
import 'package:android_manager/services/adb_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GalleryViewModel extends ChangeNotifier {
  final AdbService _adb;
  final String _serial;

  List<MediaItem> _allItems = [];
  int _displayCount = 0;
  static const int _pageSize = 60;
  Set<String> _selectedPaths = {};
  MediaItem? _previewItem;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  final Set<String> _exportedPaths = {};
  bool _disposed = false;

  bool _importing = false;
  int _importProgress = 0;
  int _importTotal = 0;

  // 缩略图并发控制：最多 3 个同时拉取
  final Map<String, Future<String?>> _pendingThumbs = {};
  int _activeThumbDownloads = 0;
  static const int _maxConcurrentThumbs = 3;

  GalleryViewModel(this._adb, this._serial);

  List<MediaItem> get items => _allItems.take(_displayCount).toList();
  List<MediaItem> get allItems => _allItems;
  int get displayCount => _displayCount;
  int get totalCount => _allItems.length;
  bool get hasMore => _displayCount < _allItems.length;
  Set<String> get selectedPaths => _selectedPaths;
  MediaItem? get previewItem => _previewItem;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  String? get error => _error;
  bool get importing => _importing;
  int get importProgress => _importProgress;
  int get importTotal => _importTotal;

  Future<void> loadMedia() async {
    _loading = true;
    _error = null;
    _displayCount = 0;
    if (!_disposed) notifyListeners();

    try {
      _allItems = await _scanAllMedia();
      _allItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _displayCount = _allItems.length < _pageSize ? _allItems.length : _pageSize;
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    if (!_disposed) notifyListeners();
  }

  /// 通过 MediaStore 查询媒体文件，和系统相册用同一数据源，保证内容完全一致
  Future<List<MediaItem>> _scanAllMedia() async {
    final allItems = <MediaItem>[];

    final queries = [
      ('content://media/external/images/media', false),
      ('content://media/external/video/media', true),
    ];

    for (final (uri, isVideo) in queries) {
      if (_disposed) return allItems;

      final cmd = 'content query --uri $uri --projection _data:_size:date_added';
      final output = await _adb.shell(_serial, cmd);
      if (output.isEmpty) continue;

      for (final line in output.split('\n')) {
        if (!line.startsWith('Row:')) continue;

        // content query 输出格式: Row: N _data=/path, _size=123, date_added=456
        // _data 用下一个字段锚定，避免路径含逗号时截断
        final dataMatch = RegExp(r'_data=(.+), _size=').firstMatch(line);
        if (dataMatch == null) continue;

        final filePath = dataMatch.group(1)!.trim();
        if (filePath.isEmpty || filePath == 'null') continue;

        final sizeMatch = RegExp(r'_size=(\d+)').firstMatch(line);
        final dateMatch = RegExp(r'date_added=(\d+)').firstMatch(line);

        final name = p.basename(filePath);
        final size = int.tryParse(sizeMatch?.group(1) ?? '') ?? 0;
        final timestamp = int.tryParse(dateMatch?.group(1) ?? '') ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

        allItems.add(MediaItem(
          name: name,
          path: filePath,
          size: size,
          modifiedDate: dateStr,
          timestamp: timestamp,
          isVideo: isVideo,
        ));
      }
    }

    return allItems;
  }

  void loadMore() {
    if (_loadingMore || _displayCount >= _allItems.length) return;
    _loadingMore = true;
    if (!_disposed) notifyListeners();

    final next = _displayCount + _pageSize;
    _displayCount = next > _allItems.length ? _allItems.length : next;
    _loadingMore = false;
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
    _selectedPaths = _allItems.map((i) => i.path).toSet();
    if (!_disposed) notifyListeners();
  }

  void selectNew() {
    _selectedPaths = _allItems
        .where((i) => !_exportedPaths.contains(i.path))
        .map((i) => i.path)
        .toSet();
    if (!_disposed) notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    if (!_disposed) notifyListeners();
  }

  void updateDragSelection(Set<String> paths) {
    _selectedPaths = paths;
    if (!_disposed) notifyListeners();
  }

  void setPreview(MediaItem? item) {
    _previewItem = item;
    if (!_disposed) notifyListeners();
  }

  /// 下载单个文件到临时目录并返回本地路径
  Future<String?> downloadToTemp(MediaItem item) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final previewDir = Directory(p.join(tempDir.path, 'previews'));
      if (!await previewDir.exists()) await previewDir.create(recursive: true);
      final localPath = p.join(previewDir.path, item.name);
      final file = File(localPath);
      if (await file.exists()) return localPath;
      final ok = await _adb.pullFile(_serial, item.path, localPath);
      if (ok) return localPath;
    } catch (_) {}
    return null;
  }

  Future<int> exportSelected(String localDir) async {
    int count = 0;
    for (final item in _allItems.where((i) => _selectedPaths.contains(i.path))) {
      if (_disposed) return count;
      final ok = await _adb.pullFile(_serial, item.path, p.join(localDir, item.name));
      if (ok) {
        _exportedPaths.add(item.path);
        count++;
      }
    }
    _selectedPaths.clear();
    if (!_disposed) notifyListeners();
    return count;
  }

  Future<bool> exportSingle(String localDir, MediaItem item) async {
    final ok = await _adb.pullFile(_serial, item.path, p.join(localDir, item.name));
    if (ok) _exportedPaths.add(item.path);
    return ok;
  }

  static const _importDeviceDir = '/sdcard/DCIM/Camera';

  Future<int> importFiles(List<String> localPaths) async {
    _importing = true;
    _importProgress = 0;
    _importTotal = localPaths.length;
    if (!_disposed) notifyListeners();

    int count = 0;
    for (final localPath in localPaths) {
      if (_disposed) break;
      final name = p.basename(localPath);
      final remotePath = '$_importDeviceDir/$name';
      final ok = await _adb.pushFile(_serial, localPath, remotePath);
      if (ok) count++;
      _importProgress++;
      if (!_disposed) notifyListeners();
    }

    // 触发媒体扫描
    if (count > 0) {
      await _adb.shell(_serial, 'am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://$_importDeviceDir/');
    }

    _importing = false;
    if (!_disposed) notifyListeners();
    return count;
  }

  Future<int> deleteSelected() async {
    int count = 0;
    String? lastDir;
    final toDelete = _allItems.where((i) => _selectedPaths.contains(i.path)).toList();
    for (final item in toDelete) {
      if (_disposed) break;
      final ok = await _adb.deleteFile(_serial, item.path);
      if (ok) {
        _allItems.remove(item);
        _exportedPaths.remove(item.path);
        lastDir = p.dirname(item.path);
        count++;
      }
    }
    _selectedPaths.clear();
    if (_displayCount > _allItems.length) {
      _displayCount = _allItems.length;
    }
    // 触发媒体扫描让系统相册同步
    if (count > 0 && lastDir != null) {
      await _adb.shell(_serial, 'am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://$lastDir/');
    }
    if (!_disposed) notifyListeners();
    return count;
  }

  Future<bool> deleteSingle(MediaItem item) async {
    final ok = await _adb.deleteFile(_serial, item.path);
    if (ok) {
      _allItems.remove(item);
      _exportedPaths.remove(item.path);
      if (_displayCount > _allItems.length) {
        _displayCount = _allItems.length;
      }
      // 触发媒体扫描让系统相册同步
      await _adb.shell(_serial, 'am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://${p.dirname(item.path)}/');
    }
    if (!_disposed) notifyListeners();
    return ok;
  }

  /// 获取缩略图，带并发控制
  Future<String?> getThumbnail(MediaItem item) async {
    if (item.localThumbnailPath != null) return item.localThumbnailPath;
    if (_disposed) return null;

    // 如果已经在拉取中，返回同一个 Future
    if (_pendingThumbs.containsKey(item.path)) {
      return _pendingThumbs[item.path];
    }

    // 等待并发槽位
    while (_activeThumbDownloads >= _maxConcurrentThumbs) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_disposed) return null;
    }

    _activeThumbDownloads++;
    final future = _doGetThumbnail(item);
    _pendingThumbs[item.path] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _activeThumbDownloads--;
      _pendingThumbs.remove(item.path);
    }
  }

  Future<String?> _doGetThumbnail(MediaItem item) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbDir = Directory(p.join(tempDir.path, 'thumbnails'));
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);

      if (item.isVideo) {
        return _getVideoThumbnail(item, thumbDir);
      }

      final localPath = p.join(thumbDir.path, item.name);
      final file = File(localPath);

      // 检查缓存
      if (await file.exists() && await file.length() > 0) {
        item.localThumbnailPath = localPath;
        return localPath;
      }
      if (await file.exists()) await file.delete();

      final ok = await _adb.pullFile(_serial, item.path, localPath);
      if (ok && await file.exists() && await file.length() > 0) {
        item.localThumbnailPath = localPath;
        return localPath;
      }
      if (await file.exists()) await file.delete();
    } catch (_) {}
    return null;
  }

  /// 视频缩略图：拉取视频 → media_kit 截取第一帧
  Future<String?> _getVideoThumbnail(MediaItem item, Directory thumbDir) async {
    final thumbPath = p.join(thumbDir.path, '${item.name}.jpg');
    final thumbFile = File(thumbPath);
    if (await thumbFile.exists() && await thumbFile.length() > 0) {
      item.localThumbnailPath = thumbPath;
      return thumbPath;
    }

    // 拉取视频到临时目录
    final videoDir = Directory(p.join(thumbDir.path, 'videos'));
    if (!await videoDir.exists()) await videoDir.create(recursive: true);
    final videoPath = p.join(videoDir.path, item.name);
    final videoFile = File(videoPath);

    if (!await videoFile.exists() || await videoFile.length() == 0) {
      final ok = await _adb.pullFile(_serial, item.path, videoPath);
      if (!ok || !await videoFile.exists() || await videoFile.length() == 0) {
        if (await videoFile.exists()) await videoFile.delete();
        return null;
      }
    }

    // media_kit 截取第一帧
    Player? player;
    try {
      player = Player(configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.error,
      ));
      await player.open(Media(videoPath));
      await player.seek(const Duration(milliseconds: 0));
      await Future.delayed(const Duration(milliseconds: 500));
      final Uint8List? bytes = await player.screenshot(format: 'image/jpeg');
      if (bytes != null && bytes.isNotEmpty) {
        await thumbFile.writeAsBytes(bytes);
        if (await thumbFile.exists() && await thumbFile.length() > 0) {
          item.localThumbnailPath = thumbPath;
          return thumbPath;
        }
      }
    } catch (_) {} finally {
      player?.dispose();
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
