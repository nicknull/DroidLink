import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/viewmodels/app_manager_viewmodel.dart';
import 'package:android_manager/views/components/app_list_tile.dart';

class AppManagerView extends StatefulWidget {
  const AppManagerView({super.key});

  @override
  State<AppManagerView> createState() => _AppManagerViewState();
}

class _AppManagerViewState extends State<AppManagerView> {
  AppManagerViewModel? _vm;
  String? _currentSerial;
  final _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final deviceVM = context.watch<DeviceViewModel>();
    final serial = deviceVM.selectedDevice?.serial;
    if (serial != _currentSerial) {
      _vm?.dispose();
      _currentSerial = serial;
      if (serial != null) {
        _vm = AppManagerViewModel(deviceVM.adb, serial);
        _vm!.loadApps();
      } else {
        _vm = null;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_vm == null) return const SizedBox.shrink();

    return ChangeNotifierProvider.value(
      value: _vm!,
      child: Builder(builder: (context) => Column(
        children: [
          _buildToolbar(context),
          const Divider(height: 1),
          Expanded(child: _buildAppList(context)),
        ],
      )),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final vm = context.watch<AppManagerViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: vm.installing ? null : _installApk,
            icon: vm.installing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.install_desktop),
            label: Text(vm.installing ? '安装中...' : '安装 APK'),
          ),
          SegmentedButton(
            segments: const [
              ButtonSegment(value: false, label: Text('用户应用')),
              ButtonSegment(value: true, label: Text('系统应用')),
            ],
            selected: {vm.showSystem},
            onSelectionChanged: (_) => vm.toggleSystem(),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜索应用',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: vm.setSearch,
            ),
          ),
          Text('共 ${vm.filteredApps.length} 个',
              style: Theme.of(context).textTheme.bodySmall),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => vm.loadApps(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppList(BuildContext context) {
    final vm = context.watch<AppManagerViewModel>();

    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) return Center(child: Text('错误: ${vm.error}'));
    if (vm.filteredApps.isEmpty) return const Center(child: Text('没有应用'));

    return ListView.builder(
      itemCount: vm.filteredApps.length,
      itemBuilder: (context, index) {
        final app = vm.filteredApps[index];
        return AppListTile(
          app: app,
          onUninstall: () => _confirmUninstall(vm, app),
          onExport: () => _exportApk(vm, app),
        );
      },
    );
  }

  Future<void> _installApk() async {
    final vm = _vm;
    if (vm == null) return;
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'APK', extensions: ['apk']),
    ]);
    if (file == null) return;
    final ok = await vm.installApk(file.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '安装成功' : '安装失败')),
      );
    }
  }

  Future<void> _exportApk(AppManagerViewModel vm, app) async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    final ok = await vm.exportApk(app, dir);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已导出到 $dir' : '导出失败')),
      );
    }
  }

  Future<void> _confirmUninstall(AppManagerViewModel vm, app) async {
    final ok = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认卸载'),
        content: Text('确定要卸载「${app.displayLabel}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('卸载', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await vm.uninstall(app.packageName);
      vm.loadApps();
    }
  }
}
