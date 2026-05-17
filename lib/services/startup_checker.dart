import 'dart:io';
import 'package:android_manager/services/adb_service.dart';

/// 单项工具检测结果
class ToolCheckItem {
  final String id;
  final String name;
  final String icon;
  final bool required;
  final String description;
  final String? installHint;
  bool available;
  bool checking;

  ToolCheckItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.required,
    required this.description,
    this.installHint,
    this.available = false,
    this.checking = true,
  });
}

/// 启动检测结果
class StartupCheckResult {
  final List<ToolCheckItem> items;
  final bool allRequiredReady;

  StartupCheckResult(this.items)
      : allRequiredReady = items.where((i) => i.required).every((i) => i.available);
}

/// 启动检测服务：逐项检测依赖工具
class StartupChecker {
  final AdbService _adb;

  StartupChecker(this._adb);

  /// 定义所有需要检测的工具
  List<ToolCheckItem> buildCheckList() {
    final items = <ToolCheckItem>[
      ToolCheckItem(
        id: 'adb',
        name: 'ADB',
        icon: '📱',
        required: true,
        description: 'Android 调试桥，核心通信工具',
        installHint: Platform.isMacOS ? 'brew install android-platform-tools' : null,
      ),
    ];

    // scrcpy 非必须但推荐
    items.add(ToolCheckItem(
      id: 'scrcpy',
      name: 'scrcpy',
      icon: '🖥️',
      required: false,
      description: '投屏与录屏工具（缺失时无法使用投屏功能）',
      installHint: Platform.isMacOS ? 'brew install scrcpy' : null,
    ));

    return items;
  }

  /// 逐项检测，每完成一项回调通知 UI 更新
  Future<StartupCheckResult> checkAll(void Function(List<ToolCheckItem>) onUpdate) async {
    final items = buildCheckList();
    onUpdate(List.from(items));

    for (int i = 0; i < items.length; i++) {
      items[i].checking = true;
      onUpdate(List.from(items));

      switch (items[i].id) {
        case 'adb':
          items[i].available = await _adb.isAdbAvailable();
          break;
        case 'scrcpy':
          items[i].available = _adb.hasScrcpy;
          break;
      }

      items[i].checking = false;
      onUpdate(List.from(items));

      // 项之间稍作间隔，让动画更自然
      if (i < items.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    return StartupCheckResult(items);
  }

  /// 重新检测指定工具
  Future<void> recheck(ToolCheckItem item, void Function(List<ToolCheckItem>) onUpdate, List<ToolCheckItem> allItems) async {
    item.checking = true;
    onUpdate(List.from(allItems));

    switch (item.id) {
      case 'adb':
        item.available = await _adb.isAdbAvailable();
        break;
      case 'scrcpy':
        _adb.reDetectScrcpy();
        item.available = _adb.hasScrcpy;
        break;
    }

    item.checking = false;
    onUpdate(List.from(allItems));
  }
}
