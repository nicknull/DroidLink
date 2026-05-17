import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/views/components/device_info_card.dart';

class SidebarView extends StatelessWidget {
  const SidebarView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DeviceViewModel>();

    return NavigationDrawer(
      selectedIndex: vm.currentPage.index,
      onDestinationSelected: (i) => vm.switchPage(AppPage.values[i]),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'DroidLink',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        if (!vm.adbAvailable)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.adb.adbDetectionError ?? '未检测到 ADB',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (vm.devices.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('设备', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          ...vm.devices.map((d) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: DeviceInfoCard(
              device: d,
              isSelected: vm.selectedDevice?.serial == d.serial,
              onTap: () => vm.selectDevice(d.serial),
            ),
          )),
          const Divider(indent: 16, endIndent: 16),
        ] else if (vm.scanning)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),

        const NavigationDrawerDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: Text('文件管理'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.photo_library_outlined),
          selectedIcon: Icon(Icons.photo_library),
          label: Text('相册视频'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.apps_outlined),
          selectedIcon: Icon(Icons.apps),
          label: Text('应用管理'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.screenshot_outlined),
          selectedIcon: Icon(Icons.screenshot),
          label: Text('截图录屏'),
        ),
      ],
    );
  }
}
