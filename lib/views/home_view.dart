import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/views/file_explorer_view.dart';
import 'package:android_manager/views/gallery_view.dart';
import 'package:android_manager/views/app_manager_view.dart';
import 'package:android_manager/views/screenshot_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _installing = false;
  String _installLog = '';
  String? _installingTool;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeviceViewModel>();

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: vm.currentPage.index,
            onDestinationSelected: (i) => vm.switchPage(AppPage.values[i]),
            leading: _buildDevicePanel(context, vm),
            trailing: Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: '关于',
                    onPressed: () => _showAbout(context),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('文件管理'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: Text('相册视频'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.apps_outlined),
                selectedIcon: Icon(Icons.apps),
                label: Text('应用管理'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.screenshot_outlined),
                selectedIcon: Icon(Icons.screenshot),
                label: Text('截图录屏'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: !vm.adbAvailable
                ? _buildSetupHint(context, vm)
                : vm.selectedDevice == null
                    ? const _NoDeviceHint()
                    : IndexedStack(
                        index: vm.currentPage.index,
                        children: const [
                          FileExplorerView(),
                          GalleryView(),
                          AppManagerView(),
                          ScreenshotView(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicePanel(BuildContext context, DeviceViewModel vm) {
    return Column(
      children: [
        const SizedBox(height: 12),
        if (!vm.adbAvailable)
          Tooltip(
            message: 'ADB 未安装',
            child: IconButton(
              icon: const Icon(Icons.error_outline, color: Colors.red, size: 20),
              onPressed: () => _installTool(context, vm, 'adb'),
            ),
          ),
        if (vm.adbAvailable && !vm.adb.hasScrcpy)
          Tooltip(
            message: 'scrcpy 未安装（录屏/投屏需要）',
            child: IconButton(
              icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
              onPressed: () => _installTool(context, vm, 'scrcpy'),
            ),
          ),
        if (vm.devices.isNotEmpty)
          PopupMenuButton(
            tooltip: '切换设备',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android, size: 24),
                  const SizedBox(height: 2),
                  Text(
                    vm.selectedDevice?.model.isNotEmpty == true
                        ? vm.selectedDevice!.model
                        : vm.selectedDevice?.serial.substring(0, 8) ?? '',
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (vm.selectedDevice?.batteryLevel.isNotEmpty == true)
                    Text(
                      '${vm.selectedDevice!.batteryLevel}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                    ),
                ],
              ),
            ),
            itemBuilder: (_) => vm.devices.map((d) => PopupMenuItem(
              value: d.serial,
              height: 40,
              child: Row(
                children: [
                  Icon(Icons.phone_android, size: 16,
                    color: d.serial == vm.selectedDevice?.serial ? Theme.of(context).colorScheme.primary : null),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.model.isNotEmpty ? '${d.model} (${d.serial.substring(0, 8)})' : d.serial,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: d.serial == vm.selectedDevice?.serial ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
            onSelected: (serial) => vm.selectDevice(serial),
          )
        else if (vm.scanning)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSetupHint(BuildContext context, DeviceViewModel vm) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.download_outlined, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text('需要安装必要工具', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (!vm.adbAvailable)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: FilledButton.icon(
                onPressed: _installing ? null : () => _installTool(context, vm, 'adb'),
                icon: const Icon(Icons.download),
                label: const Text('安装 ADB (必需)'),
              ),
            ),
          if (vm.adbAvailable && !vm.adb.hasScrcpy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: OutlinedButton.icon(
                onPressed: _installing ? null : () => _installTool(context, vm, 'scrcpy'),
                icon: const Icon(Icons.download),
                label: const Text('安装 scrcpy (录屏/投屏)'),
              ),
            ),
          if (_installing) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text('正在安装 $_installingTool...', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Future<void> _installTool(BuildContext context, DeviceViewModel vm, String tool) async {
    if (_installing) return;
    setState(() {
      _installing = true;
      _installingTool = tool;
      _installLog = '';
    });

    final logBuffer = StringBuffer();
    try {
      await for (final line in vm.adb.installTool(tool)) {
        logBuffer.write(line);
        if (mounted) setState(() => _installLog = logBuffer.toString());
      }
    } catch (e) {
      logBuffer.write('\n安装出错: $e');
    }

    if (mounted) {
      setState(() {
        _installing = false;
        _installingTool = null;
      });
      // 重新初始化 ViewModel 以重新检测工具
      vm.recheckTools();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_installLog.contains('安装成功') ? '$tool 安装成功' : '$tool 安装失败，请查看日志')),
      );
    }
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Image.asset('assets/icon.png', width: 32, height: 32),
            const SizedBox(width: 12),
            const Text('DroidLink'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本：0.0.2'),
            SizedBox(height: 8),
            Text('Android 设备桌面管理工具'),
            SizedBox(height: 16),
            _LinkButton(icon: Icons.code, label: 'GitHub', url: 'https://github.com/nicknull/DroidLink'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _LinkButton({required this.icon, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(url, style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(context).colorScheme.primary,
            )),
          ],
        ),
      ),
    );
  }
}

class _NoDeviceHint extends StatelessWidget {
  const _NoDeviceHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_android, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('请连接 Android 设备', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '确保已开启 USB 调试模式',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
