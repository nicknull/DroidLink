import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:android_manager/constants/app_names.dart';
import 'package:android_manager/services/apk_resource_parser.dart';

class DeviceEntry {
  final String serial;
  final bool isAuthorized;

  const DeviceEntry({required this.serial, required this.isAuthorized});
}

/// 对 Android shell 中的路径参数进行安全转义（单引号包裹，转义内部单引号）
String _shellEscape(String s) {
  return "'${s.replaceAll("'", "'\\''")}'";
}

class AdbService {
  String _adbPath;
  String? _adbDetectionError;
  String? _aaptPath;

  AdbService({String? adbPath}) : _adbPath = adbPath ?? '' {
    if (_adbPath.isEmpty) {
      _autoDetectAdb();
    }
    _detectAapt();
    _detectScrcpy();
  }

  String get adbPath => _adbPath;
  String? get adbDetectionError => _adbDetectionError;
  bool get hasAapt => _aaptPath != null;

  String? _scrcpyPath;
  bool get hasScrcpy => _scrcpyPath != null;
  String? get scrcpyPath => _scrcpyPath;

  void _autoDetectAdb() {
    final isWindows = Platform.isWindows;
    final adbName = isWindows ? 'adb.exe' : 'adb';

    // 1. 检查 ANDROID_HOME
    final androidHome = Platform.environment['ANDROID_HOME'];
    if (androidHome != null && androidHome.isNotEmpty) {
      final path = p.join(androidHome, 'platform-tools', adbName);
      if (File(path).existsSync()) {
        _adbPath = path;
        return;
      }
    }

    // 2. 检查 macOS 常见位置
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      final macDefault = p.join(home, 'Library', 'Android', 'sdk', 'platform-tools', adbName);
      if (File(macDefault).existsSync()) {
        _adbPath = macDefault;
        return;
      }
    }

    // 3. 检查 Windows 常见位置
    if (isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      if (localAppData.isNotEmpty) {
        final winDefault = p.join(localAppData, 'Android', 'Sdk', 'platform-tools', adbName);
        if (File(winDefault).existsSync()) {
          _adbPath = winDefault;
          return;
        }
      }
    }

    // 4. 检查 ANDROID_SDK_ROOT
    final sdkRoot = Platform.environment['ANDROID_SDK_ROOT'];
    if (sdkRoot != null && sdkRoot.isNotEmpty) {
      final path = p.join(sdkRoot, 'platform-tools', adbName);
      if (File(path).existsSync()) {
        _adbPath = path;
        return;
      }
    }

    // 5. 检查 Homebrew 安装路径（打包后 PATH 不可靠）
    if (Platform.isMacOS) {
      final brewPaths = [
        '/opt/homebrew/bin/adb',
        '/usr/local/bin/adb',
      ];
      for (final path in brewPaths) {
        if (File(path).existsSync()) {
          _adbPath = path;
          return;
        }
      }
    }

    // 6. 回退到 PATH 中的 adb
    _adbPath = 'adb';
  }

  void _detectAapt() {
    final aaptName = Platform.isWindows ? 'aapt.exe' : 'aapt';
    final searchDirs = <Directory>[];

    // ANDROID_HOME/build-tools
    final androidHome = Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'] ?? '';
    if (androidHome.isNotEmpty) {
      searchDirs.add(Directory(p.join(androidHome, 'build-tools')));
    }

    // macOS 默认
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      searchDirs.add(Directory(p.join(home, 'Library', 'Android', 'sdk', 'build-tools')));
    }

    // Windows 默认
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      if (localAppData.isNotEmpty) {
        searchDirs.add(Directory(p.join(localAppData, 'Android', 'Sdk', 'build-tools')));
      }
    }

    // Homebrew 安装的 aapt
    if (Platform.isMacOS) {
      for (final brewAapt in ['/opt/homebrew/bin/aapt', '/usr/local/bin/aapt']) {
        if (File(brewAapt).existsSync()) {
          _aaptPath = brewAapt;
          return;
        }
      }
    }

    for (final buildToolsDir in searchDirs) {
      if (!buildToolsDir.existsSync()) continue;
      final versions = buildToolsDir.listSync()
          .whereType<Directory>()
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final dir in versions) {
        final aapt = p.join(dir.path, aaptName);
        if (File(aapt).existsSync()) {
          _aaptPath = aapt;
          return;
        }
      }
    }
  }

  void _detectScrcpy() {
    final name = Platform.isWindows ? 'scrcpy.exe' : 'scrcpy';

    // 1. 直接检查已知安装路径（打包后 PATH 可能不包含这些目录）
    if (Platform.isMacOS) {
      final knownPaths = [
        '/opt/homebrew/bin/scrcpy',
        '/usr/local/bin/scrcpy',
      ];
      for (final path in knownPaths) {
        if (File(path).existsSync()) {
          _scrcpyPath = path;
          return;
        }
      }
    }

    // 2. 通过 which/where 查找（开发模式下有效）
    final cmd = Platform.isWindows ? 'where' : 'which';
    final result = Process.runSync(cmd, [name], runInShell: true);
    if (result.exitCode == 0) {
      final output = (result.stdout as String).trim();
      final path = output.split('\n').first.trim();
      if (File(path).existsSync()) {
        _scrcpyPath = path;
      }
    }
  }

  void setAdbPath(String path) {
    _adbPath = path;
    _adbDetectionError = null;
  }

  /// 重新检测 scrcpy（安装后调用）
  void reDetectScrcpy() {
    _scrcpyPath = null;
    _detectScrcpy();
  }

  // 安装缺失的工具，返回安装日志流
  Stream<String> installTool(String tool) async* {
    if (Platform.isWindows) {
      yield 'Windows 请手动安装:\n';
      if (tool == 'adb') {
        yield 'ADB: https://developer.android.com/tools/releases/platform-tools\n';
      } else {
        yield 'scrcpy: https://github.com/Genymobile/scrcpy\n';
      }
      return;
    }

    final whichCmd = Platform.isWindows ? 'where' : 'which';
    bool hasBrew = Process.runSync(whichCmd, ['brew'], runInShell: true).exitCode == 0;

    // 打包后 PATH 可能不包含 Homebrew，检查已知路径
    if (!hasBrew && Platform.isMacOS) {
      hasBrew = const ['/opt/homebrew/bin/brew', '/usr/local/bin/brew']
          .any((p) => File(p).existsSync());
    }

    if (Platform.isMacOS && hasBrew) {
      yield '正在通过 Homebrew 安装 $tool...\n';
      final package = tool == 'adb' ? 'android-platform-tools' : tool;
      // 使用 brew 完整路径，打包后 PATH 不可靠
      final brewPath = const ['/opt/homebrew/bin/brew', '/usr/local/bin/brew']
          .firstWhere((p) => File(p).existsSync(), orElse: () => 'brew');
      final process = await Process.start(
        brewPath, ['install', package],
        runInShell: true,
      );

      await for (final line in process.stdout.transform(const SystemEncoding().decoder)) {
        yield line;
      }
      await for (final line in process.stderr.transform(const SystemEncoding().decoder)) {
        yield line;
      }

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        yield '\n安装成功！\n';
        if (tool == 'adb') {
          _autoDetectAdb();
        } else if (tool == 'scrcpy') {
          _detectScrcpy();
        }
      } else {
        yield '\n安装失败，退出码: $exitCode\n';
      }
    } else if (Platform.isMacOS) {
      yield '请先安装 Homebrew: /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n';
    } else {
      yield '请手动安装:\n';
      if (tool == 'adb') {
        yield 'ADB: https://developer.android.com/tools/releases/platform-tools\n';
      } else {
        yield 'scrcpy: https://github.com/Genymobile/scrcpy\n';
      }
    }
  }

  Future<bool> isAdbAvailable() async {
    try {
      final result = await _runCommand(['version']);
      if (result.exitCode == 0) {
        _adbDetectionError = null;
        return true;
      }
      _adbDetectionError = 'adb 返回错误: ${result.stderr}';
      return false;
    } catch (e) {
      final isWindows = Platform.isWindows;
      _adbDetectionError =
          '未找到 adb，请安装 Android SDK 并设置 ANDROID_HOME 环境变量\n'
          '${isWindows ? ' Windows: set ANDROID_HOME=%LOCALAPPDATA%\\Android\\Sdk' : ' macOS: export ANDROID_HOME=\$HOME/Library/Android/sdk'}\n'
          ' 或下载: https://developer.android.com/tools/releases/platform-tools';
      return false;
    }
  }

  Future<List<DeviceEntry>> getDevices() async {
    final result = await _runCommand(['devices']);
    if (result.exitCode != 0) return [];
    return parseDevices(result.stdout);
  }

  static List<DeviceEntry> parseDevices(String output) {
    final lines = output.split('\n');
    final devices = <DeviceEntry>[];
    for (final line in lines) {
      if (line.startsWith('List of') || line.trim().isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length >= 2) {
        devices.add(
          DeviceEntry(
            serial: parts[0],
            isAuthorized: parts[1].trim() == 'device',
          ),
        );
      }
    }
    return devices;
  }

  Future<String> shell(String serial, String command) async {
    final result = await _runCommand(['-s', serial, 'shell', command]);
    return result.exitCode == 0 ? result.stdout.trim() : '';
  }

  Future<List<String>> listFiles(String serial, String path) async {
    final output = await shell(serial, 'ls -la ${_shellEscape('$path/')}');
    if (output.isEmpty) return [];
    return output.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  Future<bool> pullFile(String serial, String remote, String local) async {
    // 确保本地目录存在
    final dir = Directory(p.dirname(local));
    if (!await dir.exists()) await dir.create(recursive: true);
    final result = await _runCommand(['-s', serial, 'pull', remote, local]);
    return result.exitCode == 0;
  }

  Future<bool> pushFile(String serial, String local, String remote) async {
    final result = await _runCommand(['-s', serial, 'push', local, remote]);
    return result.exitCode == 0;
  }

  Future<bool> deleteFile(String serial, String path, {bool recursive = false}) async {
    final cmd = recursive ? 'rm -rf ${_shellEscape(path)}' : 'rm ${_shellEscape(path)}';
    final result = await _runCommand(['-s', serial, 'shell', cmd]);
    return result.exitCode == 0;
  }

  Future<bool> mkdir(String serial, String path) async {
    final result = await _runCommand([
      '-s',
      serial,
      'shell',
      'mkdir',
      '-p',
      path,
    ]);
    return result.exitCode == 0;
  }

  Future<bool> rename(String serial, String oldPath, String newPath) async {
    final result = await _runCommand([
      '-s',
      serial,
      'shell',
      'mv',
      oldPath,
      newPath,
    ]);
    return result.exitCode == 0;
  }

  Future<bool> installApk(String serial, String apkPath) async {
    final result = await _runCommand([
      '-s',
      serial,
      'install',
      '-r',
      apkPath,
    ]);
    return result.exitCode == 0;
  }

  Future<bool> uninstallApp(String serial, String packageName) async {
    final result = await _runCommand([
      '-s',
      serial,
      'uninstall',
      packageName,
    ]);
    return result.exitCode == 0;
  }

  Future<String> getPackages(String serial, {bool includeSystem = true}) async {
    final args = includeSystem
        ? ['pm', 'list', 'packages', '-f', '--show-versioncode']
        : ['pm', 'list', 'packages', '-f', '-3', '--show-versioncode'];
    return shell(serial, args.join(' '));
  }

  Future<String> getprop(String serial) async {
    return shell(serial, 'getprop');
  }

  Future<String> getPackageDump(String serial, String packageName) async {
    return shell(serial, 'dumpsys package $packageName');
  }

  Future<String> getApkSize(String serial, String apkPath) async {
    return shell(serial, 'stat -c "%s" ${_shellEscape(apkPath)} 2>/dev/null || echo "0"');
  }

  /// 获取应用名称（三层策略：映射表 → aapt → APK 解析）
  Future<String?> getAppLabel(String serial, String apkPath, {String? packageName}) async {
    // 第一层：内置映射表，秒出结果
    if (packageName != null && kAppNames.containsKey(packageName)) {
      return kAppNames[packageName];
    }

    // 第二层：aapt（如果可用）
    if (_aaptPath != null) {
      final label = await _getLabelByAapt(serial, apkPath);
      if (label != null && label.isNotEmpty) return label;
    }

    // 第三层：Dart 解析 APK 资源表
    return _getLabelByApkParser(serial, apkPath);
  }

  /// 使用 aapt 提取应用名
  Future<String?> _getLabelByAapt(String serial, String apkPath) async {
    final tempDir = Directory.systemTemp.createTempSync('apk_');
    try {
      final localApk = p.join(tempDir.path, 'base.apk');
      final pullOk = await pullFile(serial, apkPath, localApk);
      if (!pullOk) return null;

      final result = await Process.run(_aaptPath!, ['dump', 'badging', localApk]);
      if (result.exitCode != 0) return null;

      final match = RegExp(r"application: label='([^']*)'").firstMatch(result.stdout.toString());
      return match?.group(1);
    } catch (_) {
      return null;
    } finally {
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
    }
  }

  /// 使用 Dart 解析 APK 资源表提取应用名
  Future<String?> _getLabelByApkParser(String serial, String apkPath) async {
    final tempDir = Directory.systemTemp.createTempSync('apk_');
    try {
      final localApk = p.join(tempDir.path, 'base.apk');
      final pullOk = await pullFile(serial, apkPath, localApk);
      if (!pullOk) return null;

      return ApkResourceParser.parseAppLabel(localApk);
    } catch (_) {
      return null;
    } finally {
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
    }
  }

  Future<bool> screencap(String serial, String devicePath) async {
    final result = await _runCommand([
      '-s',
      serial,
      'shell',
      'screencap',
      '-p',
      devicePath,
    ]);
    return result.exitCode == 0;
  }

  /// 构建 scrcpy 所需的环境变量（注入已知工具路径）
  Map<String, String> _scrcpyEnv() {
    final env = Map<String, String>.from(Platform.environment);
    if (Platform.isMacOS) {
      final extraDirs = ['/opt/homebrew/bin', '/usr/local/bin'];
      final currentPath = env['PATH'] ?? '';
      final missing = extraDirs.where((d) => !currentPath.contains(d));
      if (missing.isNotEmpty) {
        env['PATH'] = '${missing.join(':')}:$currentPath';
      }
    }
    return env;
  }

  /// 使用 scrcpy 录屏（无窗口模式）
  /// 返回 Process 对象，调用 kill() 停止录制
  Future<Process> startScrcpyRecord(String serial, String localPath) async {
    if (_scrcpyPath == null) throw Exception('scrcpy 未安装');
    return Process.start(
      _scrcpyPath!,
      ['--no-window', '--serial', serial, '--record', localPath],
      environment: _scrcpyEnv(),
    );
  }

  /// 启动 scrcpy 投屏（带窗口，置顶）
  Future<void> startScrcpyMirror(String serial) async {
    if (_scrcpyPath == null) throw Exception('scrcpy 未安装');
    await Process.start(
      _scrcpyPath!,
      ['--serial', serial, '--always-on-top'],
      environment: _scrcpyEnv(),
    );
  }

  Future<String> getBatteryInfo(String serial) async {
    return shell(serial, 'dumpsys battery');
  }

  Future<String> getStorageInfo(String serial) async {
    return shell(serial, 'df -h /sdcard');
  }

  Future<String> getScreenResolution(String serial) async {
    return shell(serial, 'wm size');
  }

  /// 获取应用的已授权权限列表
  Future<List<String>> getAppPermissions(String serial, String packageName) async {
    final output = await shell(serial, 'dumpsys package $packageName');
    final permissions = <String>{};
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.contains('granted=true')) {
        var perm = trimmed
            .split(RegExp(r'[,:]'))
            .first
            .trim();
        // 过滤掉非权限行（如 flags 等）
        if (perm.contains('.') && !perm.contains(' ') && perm.length > 5) {
          permissions.add(perm);
        }
      }
    }
    return permissions.toList()..sort();
  }

  /// 授予权限
  Future<bool> grantPermission(String serial, String packageName, String permission) async {
    final result = await _runCommand(['-s', serial, 'shell', 'pm', 'grant', packageName, permission]);
    return result.exitCode == 0;
  }

  /// 撤销权限
  Future<bool> revokePermission(String serial, String packageName, String permission) async {
    final result = await _runCommand(['-s', serial, 'shell', 'pm', 'revoke', packageName, permission]);
    return result.exitCode == 0;
  }

  /// 清除应用数据
  Future<bool> clearAppData(String serial, String packageName) async {
    final result = await _runCommand(['-s', serial, 'shell', 'pm', 'clear', packageName]);
    return result.exitCode == 0;
  }

  /// 强制停止应用
  Future<bool> forceStopApp(String serial, String packageName) async {
    final result = await _runCommand(['-s', serial, 'shell', 'am', 'force-stop', packageName]);
    return result.exitCode == 0;
  }

  Future<_CmdResult> _runCommand(List<String> args) async {
    try {
      final process = await Process.run(_adbPath, args);
      return _CmdResult(
        exitCode: process.exitCode,
        stdout: process.stdout.toString(),
        stderr: process.stderr.toString(),
      );
    } catch (e) {
      return _CmdResult(exitCode: -1, stdout: '', stderr: e.toString());
    }
  }
}

class _CmdResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _CmdResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}
