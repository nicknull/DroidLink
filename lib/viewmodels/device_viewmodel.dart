import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:android_manager/models/device_info.dart';
import 'package:android_manager/services/adb_service.dart';
import 'package:android_manager/services/device_monitor.dart';

enum AppPage { files, gallery, apps, screenshot }

class DeviceViewModel extends ChangeNotifier {
  final AdbService _adb;
  late final DeviceMonitor _monitor;
  StreamSubscription? _sub;

  List<DeviceInfo> _devices = [];
  DeviceInfo? _selectedDevice;
  AppPage _currentPage = AppPage.files;
  bool _adbAvailable = false;
  bool _scanning = false;

  DeviceViewModel(this._adb) {
    _monitor = DeviceMonitor(_adb);
    _init();
  }

  List<DeviceInfo> get devices => _devices;
  DeviceInfo? get selectedDevice => _selectedDevice;
  AppPage get currentPage => _currentPage;
  bool get adbAvailable => _adbAvailable;
  bool get scanning => _scanning;
  AdbService get adb => _adb;

  void _init() async {
    _adbAvailable = await _adb.isAdbAvailable();
    if (_adbAvailable) {
      _sub = _monitor.deviceStream.listen((devices) {
        _devices = devices;
        if (_selectedDevice != null) {
          _selectedDevice = devices.where((d) => d.serial == _selectedDevice!.serial).firstOrNull;
        }
        _selectedDevice ??= devices.where((d) => d.model.isNotEmpty).firstOrNull;
        _scanning = false;
        notifyListeners();
      });
      _scanning = true;
      _monitor.startPolling();
    }
    notifyListeners();
  }

  void selectDevice(String serial) {
    _selectedDevice = _devices.where((d) => d.serial == serial).firstOrNull;
    notifyListeners();
  }

  void switchPage(AppPage page) {
    _currentPage = page;
    notifyListeners();
  }

  void recheckTools() async {
    _sub?.cancel();
    _sub = null;
    _adbAvailable = await _adb.isAdbAvailable();
    if (_adbAvailable) {
      _sub = _monitor.deviceStream.listen((devices) {
        _devices = devices;
        if (_selectedDevice != null) {
          _selectedDevice = devices.where((d) => d.serial == _selectedDevice!.serial).firstOrNull;
        }
        _selectedDevice ??= devices.where((d) => d.model.isNotEmpty).firstOrNull;
        _scanning = false;
        notifyListeners();
      });
      _scanning = true;
      _monitor.startPolling();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _monitor.dispose();
    super.dispose();
  }
}
