import 'dart:io';
import 'package:android_manager/services/adb_service.dart';

/// 工具检测状态
enum ToolStatus { pending, checking, available, missing }

/// 单项工具检测结果
class ToolCheckItem {
  final String id;
  final String name;
  final String icon; // Material icon name
  final bool required;
  final String description;
  ToolStatus status;

  ToolCheckItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.required,
    required this.description,
    this.status = ToolStatus.pending,
  });
}

/// 启动检测结果
class StartupCheckResult {
  final List<ToolCheckItem> items;
  bool get allRequiredReady => items.where((i) => i.required).every((i) => i.status == ToolStatus.available);

  StartupCheckResult(this.items);
}

/// 启动检测服务：逐项检测依赖工具
class StartupChecker {
  final AdbService _adb;

  StartupChecker(this._adb);

  /// 定义所有需要检测的工具
  List<ToolCheckItem> buildCheckList() {
    final items = <ToolCheckItem>[];

    if (Platform.isMacOS) {
      items.add(ToolCheckItem(
        id: 'homebrew',
        name: 'Homebrew',
        icon: 'local_cafe',
        required: false,
        description: 'macOS 包管理器，用于自动安装其他工具',
      ));
    }

    items.add(ToolCheckItem(
      id: 'adb',
      name: 'ADB',
      icon: 'phone_android',
      required: true,
      description: 'Android 调试桥，核心通信工具',
    ));

    items.add(ToolCheckItem(
      id: 'scrcpy',
      name: 'scrcpy',
      icon: 'screen_share',
      required: true,
      description: '投屏与录屏工具',
    ));

    return items;
  }

  /// 逐项检测，每完成一项回调通知 UI 更新
  Future<StartupCheckResult> checkAll(void Function(List<ToolCheckItem>) onUpdate) async {
    final items = buildCheckList();
    onUpdate(List.from(items));

    for (int i = 0; i < items.length; i++) {
      items[i].status = ToolStatus.checking;
      onUpdate(List.from(items));

      switch (items[i].id) {
        case 'homebrew':
          items[i].status = _adb.hasHomebrew ? ToolStatus.available : ToolStatus.missing;
          break;
        case 'adb':
          items[i].status = await _adb.isAdbAvailable() ? ToolStatus.available : ToolStatus.missing;
          break;
        case 'scrcpy':
          items[i].status = _adb.hasScrcpy ? ToolStatus.available : ToolStatus.missing;
          break;
      }

      onUpdate(List.from(items));
      if (i < items.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return StartupCheckResult(items);
  }

  /// 重新检测指定工具
  Future<void> recheck(ToolCheckItem item, void Function(List<ToolCheckItem>) onUpdate, List<ToolCheckItem> allItems) async {
    item.status = ToolStatus.checking;
    onUpdate(List.from(allItems));

    switch (item.id) {
      case 'homebrew':
        item.status = _adb.hasHomebrew ? ToolStatus.available : ToolStatus.missing;
        break;
      case 'adb':
        item.status = await _adb.isAdbAvailable() ? ToolStatus.available : ToolStatus.missing;
        break;
      case 'scrcpy':
        _adb.reDetectScrcpy();
        item.status = _adb.hasScrcpy ? ToolStatus.available : ToolStatus.missing;
        break;
    }

    onUpdate(List.from(allItems));
  }
}
