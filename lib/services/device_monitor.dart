import 'dart:async';
import 'package:android_manager/services/adb_service.dart';
import 'package:android_manager/models/device_info.dart';

class DeviceMonitor {
  final AdbService _adb;
  Timer? _timer;
  final _controller = StreamController<List<DeviceInfo>>.broadcast();

  DeviceMonitor(this._adb);

  Stream<List<DeviceInfo>> get deviceStream => _controller.stream;

  void startPolling({Duration interval = const Duration(seconds: 2)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _poll());
    _poll();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final entries = await _adb.getDevices();
      final devices = <DeviceInfo>[];
      for (final entry in entries) {
        if (!entry.isAuthorized) {
          devices.add(DeviceInfo(serial: entry.serial));
          continue;
        }
        final propOutput = await _adb.getprop(entry.serial);
        final info = DeviceInfo.fromGetprop(propOutput, serial: entry.serial);

        final batteryOutput = await _adb.getBatteryInfo(entry.serial);
        String batteryLevel = '';
        String batteryStatus = '';
        final levelMatch = RegExp(r'level:\s*(\d+)').firstMatch(batteryOutput);
        final statusMatch = RegExp(r'status:\s*(\w+)').firstMatch(batteryOutput);
        if (levelMatch != null) batteryLevel = levelMatch.group(1)!;
        if (statusMatch != null) batteryStatus = statusMatch.group(1)!;

        final storageOutput = await _adb.getStorageInfo(entry.serial);
        final resOutput = await _adb.getScreenResolution(entry.serial);

        devices.add(
          info.copyWith(
            batteryLevel: batteryLevel,
            batteryStatus: batteryStatus,
            storageTotal: _parseStorageTotal(storageOutput),
            storageUsed: _parseStorageUsed(storageOutput),
            screenResolution: _parseResolution(resOutput),
          ),
        );
      }
      _controller.add(devices);
    } catch (_) {
      // 静默失败，下次轮询重试
    }
  }

  String _parseStorageTotal(String output) {
    final parts = output.split('\n');
    if (parts.length > 1) {
      final cols = parts[1].split(RegExp(r'\s+'));
      if (cols.length > 1) return cols[1];
    }
    return '';
  }

  String _parseStorageUsed(String output) {
    final parts = output.split('\n');
    if (parts.length > 1) {
      final cols = parts[1].split(RegExp(r'\s+'));
      if (cols.length > 2) return cols[2];
    }
    return '';
  }

  String _parseResolution(String output) {
    final match = RegExp(r'(\d+x\d+)').firstMatch(output);
    return match?.group(1) ?? '';
  }

  void dispose() {
    stopPolling();
    _controller.close();
  }
}
