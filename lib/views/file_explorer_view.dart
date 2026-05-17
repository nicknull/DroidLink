import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/viewmodels/file_explorer_viewmodel.dart';
import 'package:android_manager/views/components/file_list_tile.dart';

class FileExplorerView extends StatefulWidget {
  const FileExplorerView({super.key});

  @override
  State<FileExplorerView> createState() => _FileExplorerViewState();
}

class _FileExplorerViewState extends State<FileExplorerView> {
  FileExplorerViewModel? _vm;
  String? _currentSerial;
  bool _selectMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final deviceVM = context.watch<DeviceViewModel>();
    final serial = deviceVM.selectedDevice?.serial;
    if (serial != _currentSerial) {
      _vm?.dispose();
      _currentSerial = serial;
      if (serial != null) {
        _vm = FileExplorerViewModel(deviceVM.adb, serial);
        _vm!.loadDirectory();
      } else {
        _vm = null;
      }
    }
  }

  @override
  void dispose() {
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
          Expanded(child: _buildFileList(context)),
        ],
      )),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final vm = context.watch<FileExplorerViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: '上级目录',
            onPressed: vm.currentPath != '/sdcard' ? () => vm.navigateUp() : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              vm.currentPath,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 选择模式切换
          Tooltip(
            message: _selectMode ? '切换到浏览模式' : '切换到选择模式',
            child: IconButton(
              icon: Icon(_selectMode ? Icons.check_circle : Icons.folder),
              color: _selectMode ? Theme.of(context).colorScheme.primary : null,
              onPressed: () {
                setState(() => _selectMode = !_selectMode);
                if (!_selectMode) vm.clearSelection();
              },
            ),
          ),
          if (_selectMode && vm.hasSelection) ...[
            Text('已选 ${vm.selectedPaths.length} 项', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _downloadSelected(vm),
              child: const Text('下载'),
            ),
            TextButton(
              onPressed: () => _deleteSelected(vm),
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
            TextButton(onPressed: vm.clearSelection, child: const Text('取消')),
          ] else if (_selectMode) ...[
            TextButton(onPressed: vm.selectAll, child: const Text('全选')),
          ],
          if (!_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: () => vm.loadDirectory(),
            ),
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: '新建文件夹',
              onPressed: () => _showCreateFolderDialog(context, vm),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: '上传文件',
              onPressed: () async {
                final file = await openFile();
                if (file != null) {
                  vm.uploadFile(file.path);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context) {
    final vm = context.watch<FileExplorerViewModel>();

    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) return Center(child: Text('错误: ${vm.error}'));
    if (vm.files.isEmpty) return const Center(child: Text('空目录'));

    return ListView.builder(
      itemCount: vm.files.length,
      itemBuilder: (context, index) {
        final file = vm.files[index];
        return FileListTile(
          file: file,
          isSelected: vm.selectedPaths.contains(file.path),
          onTap: () {
            if (_selectMode) {
              vm.toggleSelection(file.path);
            } else {
              if (file.isDirectory) vm.loadDirectory(file.path);
            }
          },
          onLongPress: () {
            if (!_selectMode) setState(() => _selectMode = true);
            vm.toggleSelection(file.path);
          },
          onExport: () => _downloadSingle(vm, file),
          onDelete: () => _deleteSingle(vm, file),
          onSelect: () {
            if (!_selectMode) setState(() => _selectMode = true);
            vm.toggleSelection(file.path);
          },
        );
      },
    );
  }

  Future<void> _downloadSelected(FileExplorerViewModel vm) async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    final count = await vm.downloadSelected(dir);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已下载 $count 个文件到 $dir')),
      );
    }
  }

  Future<void> _downloadSingle(FileExplorerViewModel vm, file) async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    vm.toggleSelection(file.path);
    final count = await vm.downloadSelected(dir);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(count > 0 ? '已下载 ${file.name}' : '下载失败')),
      );
    }
  }

  Future<void> _deleteSelected(FileExplorerViewModel vm) async {
    final ok = await _confirmDelete(context, vm.selectedPaths.length);
    if (!ok) return;
    final count = await vm.deleteSelected();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 $count 个文件')),
      );
    }
  }

  Future<void> _deleteSingle(FileExplorerViewModel vm, file) async {
    final ok = await _confirmDelete(context, 1);
    if (!ok) return;
    vm.toggleSelection(file.path);
    final count = await vm.deleteSelected();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(count > 0 ? '已删除 ${file.name}' : '删除失败')),
      );
    }
  }

  void _showCreateFolderDialog(BuildContext context, FileExplorerViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                vm.createFolder(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, int count) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 $count 个项目吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }
}
