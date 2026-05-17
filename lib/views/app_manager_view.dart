import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/viewmodels/app_manager_viewmodel.dart';
import 'package:android_manager/views/components/app_list_tile.dart';
import 'package:android_manager/constants/permission_names.dart';

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
          onToggleFavorite: () => vm.toggleFavorite(app.packageName),
          onForceStop: () => _forceStop(vm, app),
          onClearData: () => _confirmClearData(vm, app),
          onManagePermissions: () => _showPermissionsDialog(vm, app),
          onExport: () => _exportApk(vm, app),
          onUninstall: () => _confirmUninstall(vm, app),
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

  Future<void> _forceStop(AppManagerViewModel vm, app) async {
    final ok = await vm.forceStopApp(app.packageName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已强制停止 ${app.displayLabel}' : '操作失败')),
      );
    }
  }

  Future<void> _confirmClearData(AppManagerViewModel vm, app) async {
    final ok = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除数据'),
        content: Text('确定要清除「${app.displayLabel}」的所有数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success = await vm.clearAppData(app.packageName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '已清除 ${app.displayLabel} 的数据' : '清除失败')),
        );
      }
    }
  }

  Future<void> _showPermissionsDialog(AppManagerViewModel vm, app) async {
    showDialog(
      context: context,
      builder: (ctx) => _PermissionsDialog(
        appName: app.displayLabel,
        packageName: app.packageName,
        vm: vm,
      ),
    );
  }
}

class _PermissionsDialog extends StatefulWidget {
  final String appName;
  final String packageName;
  final AppManagerViewModel vm;

  const _PermissionsDialog({
    required this.appName,
    required this.packageName,
    required this.vm,
  });

  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  List<String> _permissions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final perms = await widget.vm.getAppPermissions(widget.packageName);
    if (mounted) {
      setState(() {
        _permissions = perms..sort();
        _loading = false;
      });
    }
  }

  String _permDisplayName(String perm) {
    final chinese = kPermissionNames[perm];
    if (chinese != null) return '$chinese\n${perm.replaceFirst('android.permission.', '')}';
    return perm.replaceFirst('android.permission.', '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.appName} - 权限管理'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _permissions.isEmpty
                ? const Center(child: Text('没有已授权的权限'))
                : ListView.builder(
                    itemCount: _permissions.length,
                    itemBuilder: (context, index) {
                      final perm = _permissions[index];
                      return SwitchListTile(
                        title: Text(
                          _permDisplayName(perm),
                          style: const TextStyle(fontSize: 13),
                        ),
                        value: true,
                        onChanged: (value) async {
                          if (!value) {
                            final ok = await widget.vm.revokePermission(widget.packageName, perm);
                            if (ok && mounted) {
                              setState(() => _permissions.remove(perm));
                            }
                          }
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final ok = await widget.vm.forceStopApp(widget.packageName);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ok ? '已强制停止' : '操作失败')),
              );
            }
          },
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: const Text('强制停止'),
        ),
        TextButton.icon(
          onPressed: () async {
            final confirm = await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('确认清除数据'),
                content: Text('确定要清除「${widget.appName}」的所有数据吗？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('清除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              final ok = await widget.vm.clearAppData(widget.packageName);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '已清除数据' : '清除失败')),
                );
                Navigator.pop(context);
              }
            }
          },
          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          label: const Text('清除数据'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
