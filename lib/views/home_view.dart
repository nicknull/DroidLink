import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/services/update_service.dart';
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
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.checkForUpdate();
    if (info != null && mounted) {
      setState(() => _updateInfo = info);
    }
  }
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
                  if (_updateInfo != null)
                    Tooltip(
                      message: '新版本 v${_updateInfo!.version} 可用',
                      child: IconButton(
                        icon: Badge(
                          isLabelVisible: true,
                          child: Icon(Icons.system_update, size: 20, color: Theme.of(context).colorScheme.primary),
                        ),
                        onPressed: () => _showUpdateDialog(context),
                      ),
                    ),
                  if (!vm.adbAvailable || !vm.adb.hasScrcpy)
                    IconButton(
                      icon: Badge(
                        isLabelVisible: true,
                        child: Icon(Icons.build_outlined, size: 20, color: !vm.adbAvailable ? Colors.red : Colors.orange),
                      ),
                      tooltip: '工具检测',
                      onPressed: () => _showToolStatus(context, vm),
                    ),
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
                ? const _NoToolHint()
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

  void _showToolStatus(BuildContext context, DeviceViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('工具状态'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toolRow('ADB', vm.adbAvailable),
            const SizedBox(height: 8),
            _toolRow('scrcpy', vm.adb.hasScrcpy),
            const SizedBox(height: 16),
            Text(
              '缺失工具请重启应用，在启动页完成安装',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); vm.recheckTools(); },
            child: const Text('重新检测'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Widget _toolRow(String name, bool available) {
    return Row(
      children: [
        Icon(available ? Icons.check_circle : Icons.cancel,
          size: 18, color: available ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Text(name),
        const Spacer(),
        Text(available ? '已安装' : '未安装',
          style: TextStyle(fontSize: 12, color: available ? Colors.green : Colors.red)),
      ],
    );
  }

  void _showAbout(BuildContext context) {
    bool checking = false;
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (ctx, snap) {
          final version = snap.data?.version ?? '-';
          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: Row(
                children: [
                  Image.asset('assets/icon.png', width: 32, height: 32),
                  const SizedBox(width: 12),
                  const Text('DroidLink'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('版本：$version'),
                  const SizedBox(height: 8),
                  const Text('Android 设备桌面管理工具'),
                  const SizedBox(height: 16),
                  const _LinkButton(icon: Icons.code, label: 'GitHub', url: 'https://github.com/nicknull/DroidLink'),
                ],
              ),
              actions: [
                if (checking)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  TextButton(
                    onPressed: () async {
                      setDialogState(() => checking = true);
                      final info = await UpdateService.checkForUpdate();
                      if (!ctx.mounted) return;
                      setDialogState(() => checking = false);
                      if (info != null) {
                        Navigator.pop(ctx);
                        _showUpdateDialog(context, info);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已是最新版本')),
                        );
                      }
                    },
                    child: const Text('检查更新'),
                  ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, [UpdateInfo? updateInfo]) {
    final info = updateInfo ?? _updateInfo;
    if (info == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新版本：v${info.version}'),
            const SizedBox(height: 8),
            const Text('前往 GitHub 下载最新版本'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(info.url));
            },
            child: const Text('去下载'),
          ),
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

class _NoToolHint extends StatelessWidget {
  const _NoToolHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('工具未就绪', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '请重启应用，在启动页完成工具安装',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
