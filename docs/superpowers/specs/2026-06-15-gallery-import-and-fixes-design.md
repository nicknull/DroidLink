# 相册拖拽导入与选择/删除 bug 修复

## 背景

当前相册页面存在三个问题需修复，同时新增拖拽导入功能：

1. **选择 bug**：全选或圈选后，点击已选中的项目无法取消选择
2. **删除可靠性 bug**：adb shell rm 的 exit code 不可靠，可能误报成功
3. **右键菜单缺失**：项目右键菜单没有删除选项
4. **新功能**：支持拖拽图片/视频到窗口直接导入

## 修复 1：选择 bug（手势冲突）

### 根因

`gallery_view.dart` 第 204-219 行：当 item 被选中时，条件性地用 `DragItemWidget` 包裹它，未选中时返回裸的 `MediaGridItem`。这种条件性包裹导致：
- widget 树结构在选中/取消时发生切换
- `DragItemWidget` 的手势识别器与 `MediaGridItem.GestureDetector.onTap` 竞争同一 pointer
- 已选中状态下点击无法触发 `toggleSelection`

### 修复方案

保持 widget 树结构一致：始终用 `DragItemWidget` 包裹每个 item，但通过 `dragItemProvider` 在未选中时返回 `null`。这样手势识别器行为一致，不会因选中状态切换而干扰 `onTap`。

```dart
// 修改前
if (isSelected && _supportsDragExport) {
  return DragItemWidget(...);
}
return MediaGridItem(...);

// 修改后
return DragItemWidget(
  dragItemProvider: (_) async => isSelected ? _createDragItem(item) : null,
  allowedOperations: () => [DropOperation.copy],
  child: MediaGridItem(...),
);
```

移除 `_dragItemKeys` 缓存逻辑（不再需要 GlobalKey 来跟踪状态切换）。

## 修复 2：删除可靠性

### 根因

`adb_service.dart` 第 402-405 行：`Process.run('adb', ['shell', 'rm ...'])` 返回的 exit code 是 adb 进程的，不一定反映内部 rm 命令的结果。

### 修复方案

修改 `deleteFile` 命令构造方式，用 `&&` 连接 rm 和一个 echo 标记，通过检查 stdout 判断真实结果：

```dart
Future<bool> deleteFile(String serial, String path, {bool recursive = false}) async {
  final rmCmd = recursive ? 'rm -rf' : 'rm';
  final cmd = '$rmCmd ${_shellEscape(path)} 2>/dev/null && echo OK || echo FAIL';
  final result = await _runCommand(['-s', serial, 'shell', cmd]);
  return result.stdout.contains('OK');
}
```

同时在 ViewModel 删除成功后触发媒体扫描，让系统相册也同步更新：

```dart
// deleteSelected/deleteSingle 成功后
await _adb.shell(_serial, 'am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://${p.dirname(item.path)}/');
```

## 修复 3：右键菜单加删除

### 修复方案

`MediaGridItem` 增加 `onDelete` 回调参数，在 `_showContextMenu` 的菜单项里加入「删除」选项（红色文字），点击后调用 `onDelete`。

```dart
class MediaGridItem extends StatelessWidget {
  ...
  final VoidCallback? onDelete;
  ...
  children: [
    if (onExport != null)
      _MenuItem(icon: Icons.download, label: '导出到电脑', onTap: ...),
    if (onDelete != null)
      _MenuItem(icon: Icons.delete, label: '删除', color: Colors.red, onTap: ...),
  ],
}
```

在 `gallery_view.dart` 的 itemBuilder 里传入 `onDelete: () => _deleteSingleWithConfirm(vm, item)`，复用删除确认对话框逻辑。

## 新功能：拖拽导入

### 设计

在 `gallery_view.dart` 根 `Column` 外层包一个 `DropRegion`，监听拖入事件：

```dart
DropRegion(
  formats: Formats.fileUri,  // 接受文件拖入
  onDropOver: (event) {
    // 检查是否有图片/视频文件
    final hasMedia = event.session.items.any((item) => _isMediaItem(item));
    if (!hasMedia) return DropOperation.none;
    setState(() => _isDragOver = true);
    return DropOperation.copy;
  },
  onDropLeave: (_) => setState(() => _isDragOver = false),
  onPerformDrop: (event) async {
    final paths = <String>[];
    for (final item in event.session.items) {
      // 读取拖入文件的本地路径
      final path = await item.getVirtualFile(format: Formats.fileUri);
      if (path != null && _isMediaExtension(path.path)) {
        paths.add(path.path);
      }
    }
    if (paths.isNotEmpty) {
      await vm.importFiles(paths);
      vm.loadMedia();
    }
    setState(() => _isDragOver = false);
  },
  child: Stack(
    children: [
      Column(...),  // 原有内容
      if (_isDragOver) _buildDragOverlay(),  // 遮罩
    ],
  ),
)
```

### 拖拽视觉反馈

遮罩层：半透明蓝色背景 + 居中大图标 + 提示文字。

```dart
Widget _buildDragOverlay() {
  return IgnorePointer(
    child: Container(
      color: Colors.blue.withValues(alpha: 0.2),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_upload, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text('松开以导入到手机相册',
              style: TextStyle(fontSize: 18, color: Colors.blue)),
          ],
        ),
      ),
    ),
  );
}
```

### 文件类型过滤

复用已有的扩展名列表（jpg, jpeg, png, gif, bmp, webp, mp4, 3gp, webm, mkv, avi, mov），非媒体文件忽略。

## 工具栏调整

将「导入」按钮从当前位置移到刷新按钮右侧（工具栏最右侧）：

```dart
// 修改后布局
[共X项] [全选] [导出][删除][清除] ... [刷新] [导入]
```

## 涉及文件

| 文件 | 改动 |
|------|------|
| `lib/views/gallery_view.dart` | DropRegion 包裹、遮罩 UI、DragItemWidget 修复、按钮位置调整、右键删除回调 |
| `lib/viewmodels/gallery_viewmodel.dart` | 无需改动（复用 importFiles） |
| `lib/services/adb_service.dart` | deleteFile 改用 echo 标记验证真实结果 |
| `lib/views/components/media_grid_item.dart` | 增加 onDelete 回调和菜单项 |

## 风险

- `super_drag_and_drop` 的 `DropRegion.getVirtualFile` API 在不同平台行为可能略有差异（macOS 通过 NSItemProvider，Windows 通过 IDataObject）。对于本地文件拖入，通常能直接拿到路径。
- `DragItemWidget` 始终包裹后，未选中状态下拖拽单个 item 不会启动拖拽（返回 null），符合预期。
