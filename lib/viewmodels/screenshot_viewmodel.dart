import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:android_manager/services/adb_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

String get _scrcpyInstallHint => Platform.isWindows
    ? '录屏/投屏需要 scrcpy，请访问 https://github.com/Genymobile/scrcpy 下载'
    : '录屏/投屏需要 scrcpy，请安装: brew install scrcpy';

class ScreenshotRecord {
  final String localPath;
  final DateTime time;
  final bool isVideo;

  ScreenshotRecord({required this.localPath, required this.time, required this.isVideo});
}

class ScreenshotViewModel extends ChangeNotifier {
  final AdbService _adb;
  final String _serial;

  final List<ScreenshotRecord> _history = [];
  bool _capturing = false;
  bool _recording = false;
  String? _previewPath;
  String? _error;
  Process? _recordProcess;
  bool _disposed = false;

  ScreenshotViewModel(this._adb, this._serial);

  List<ScreenshotRecord> get history => _history;
  bool get capturing => _capturing;
  bool get recording => _recording;
  String? get previewPath => _previewPath;
  String? get error => _error;
  bool get canRecord => _adb.hasScrcpy;

  /// 获取保存目录：~/Documents/DroidLink/Screenshots 或 ~/Recordings
  Future<String> _getSaveDir(String subDir) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = p.join(docsDir.path, 'DroidLink', subDir);
    await Directory(dir).create(recursive: true);
    return dir;
  }

  Future<void> takeScreenshot() async {
    _capturing = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      final saveDir = await _getSaveDir('Screenshots');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // 先截到设备临时路径
      final deviceTempPath = '/sdcard/screenshot_$timestamp.png';
      // 最终保存到设备相册目录
      final deviceAlbumPath = '/sdcard/Pictures/Screenshots/screenshot_$timestamp.png';
      final localPath = p.join(saveDir, 'screenshot_$timestamp.png');

      await _adb.screencap(_serial, deviceTempPath);
      // 拉到电脑
      final ok = await _adb.pullFile(_serial, deviceTempPath, localPath);
      if (ok && !_disposed) {
        _previewPath = localPath;
        _history.insert(0, ScreenshotRecord(
          localPath: localPath,
          time: DateTime.now(),
          isVideo: false,
        ));
        // 移到设备相册目录（保留在手机上）
        await _adb.shell(_serial, 'mkdir -p /sdcard/Pictures/Screenshots');
        await _adb.shell(_serial, 'mv "$deviceTempPath" "$deviceAlbumPath"');
      }
    } catch (e) {
      _error = e.toString();
    }

    _capturing = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> startRecording() async {
    if (!_adb.hasScrcpy) {
      _error = _scrcpyInstallHint;
      if (!_disposed) notifyListeners();
      return;
    }

    _recording = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      final saveDir = await _getSaveDir('Recordings');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final localPath = p.join(saveDir, 'recording_$timestamp.mp4');

      _recordProcess = await _adb.startScrcpyRecord(_serial, localPath);

      _recordProcess!.exitCode.then((code) async {
        if (_disposed) return;
        _recording = false;
        _recordProcess = null;

        final file = File(localPath);
        if (file.existsSync() && file.lengthSync() > 0) {
          _previewPath = localPath;
          _history.insert(0, ScreenshotRecord(
            localPath: localPath,
            time: DateTime.now(),
            isVideo: true,
          ));
          // 录屏文件 push 回手机相册
          final fileName = p.basename(localPath);
          await _adb.shell(_serial, 'mkdir -p /sdcard/Movies/Recordings');
          await _adb.pushFile(_serial, localPath, '/sdcard/Movies/Recordings/$fileName');
        }
        if (!_disposed) notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _recording = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    if (_recordProcess != null) {
      _recordProcess!.kill();
    }
  }

  Future<void> openMirror() async {
    if (!_adb.hasScrcpy) {
      _error = _scrcpyInstallHint;
      if (!_disposed) notifyListeners();
      return;
    }
    try {
      await _adb.startScrcpyMirror(_serial);
    } catch (e) {
      _error = e.toString();
      if (!_disposed) notifyListeners();
    }
  }

  /// 用系统播放器打开视频/图片
  Future<void> openInSystem(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }

  /// 在 Finder/资源管理器中显示文件
  Future<void> revealInFinder(String path) async {
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [p.dirname(path)]);
    }
  }

  void setPreview(String? path) {
    _previewPath = path;
    if (!_disposed) notifyListeners();
  }

  void deleteRecord(int index) {
    if (index < 0 || index >= _history.length) return;
    final record = _history[index];
    final file = File(record.localPath);
    if (file.existsSync()) file.deleteSync();
    if (_previewPath == record.localPath) {
      _previewPath = null;
    }
    _history.removeAt(index);
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    _error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _recordProcess?.kill();
    super.dispose();
  }
}
