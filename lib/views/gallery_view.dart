import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/viewmodels/gallery_viewmodel.dart';
import 'package:android_manager/models/media_item.dart';
import 'package:android_manager/views/components/media_grid_item.dart';

class GalleryView extends StatefulWidget {
  const GalleryView({super.key});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  GalleryViewModel? _vm;
  String? _currentSerial;
  final ScrollController _scrollController = ScrollController();
  bool _selectMode = false;

  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDragging = false;
  double _gridWidth = 0;

  static const _crossAxisCount = 5;
  static const _crossAxisSpacing = 4.0;
  static const _mainAxisSpacing = 4.0;
  static const _gridPadding = 8.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _vm?.loadMore();
    }
    if (_isDragging && _vm != null) {
      _updateDragSelection(_vm!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final deviceVM = context.watch<DeviceViewModel>();
    final serial = deviceVM.selectedDevice?.serial;
    if (serial != _currentSerial) {
      _vm?.dispose();
      _currentSerial = serial;
      if (serial != null) {
        _vm = GalleryViewModel(deviceVM.adb, serial);
        _vm!.loadMedia();
      } else {
        _vm = null;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
          Expanded(child: _buildGrid(context)),
        ],
      )),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final vm = context.watch<GalleryViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('共 ${vm.totalCount} 项${vm.hasMore ? "，已加载 ${vm.displayCount}" : ""}',
            style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Tooltip(
            message: _selectMode ? '切换到浏览模式' : '切换到选择模式',
            child: IconButton(
              icon: Icon(_selectMode ? Icons.check_circle : Icons.photo_library),
              color: _selectMode ? Theme.of(context).colorScheme.primary : null,
              onPressed: () {
                setState(() => _selectMode = !_selectMode);
                if (!_selectMode) vm.clearSelection();
              },
            ),
          ),
          if (_selectMode) ...[
            if (vm.selectedPaths.isNotEmpty) ...[
              Text('已选 ${vm.selectedPaths.length} 项', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              TextButton(onPressed: () => _exportSelected(vm), child: const Text('导出')),
              TextButton(onPressed: vm.clearSelection, child: const Text('取消')),
            ] else ...[
              TextButton(onPressed: vm.selectAll, child: const Text('全选')),
              TextButton(onPressed: vm.selectNew, child: const Text('全选新的')),
            ],
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => vm.loadMedia(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final vm = context.watch<GalleryViewModel>();

    if (vm.loading) return const Center(child: CircularProgressIndicator());
    if (vm.error != null) return Center(child: Text('错误: ${vm.error}'));
    if (vm.items.isEmpty) return const Center(child: Text('未找到照片或视频'));

    return LayoutBuilder(builder: (context, constraints) {
      _gridWidth = constraints.maxWidth;

      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _dragStart = event.localPosition;
          _dragCurrent = event.localPosition;
        },
        onPointerMove: (event) {
          if (_dragStart == null) return;
          final delta = (event.localPosition - _dragStart!).distance;
          if (delta > 10) {
            if (!_isDragging) {
              _isDragging = true;
              if (!_selectMode) setState(() => _selectMode = true);
              vm.clearSelection();
            }
            _dragCurrent = event.localPosition;
            _updateDragSelection(vm);
            setState(() {});
          }
        },
        onPointerUp: (event) {
          if (_isDragging) {
            _isDragging = false;
            _dragStart = null;
            _dragCurrent = null;
            setState(() {});
          } else {
            _dragStart = null;
            _dragCurrent = null;
          }
        },
        child: Stack(
          children: [
            GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(_gridPadding),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                crossAxisSpacing: _crossAxisSpacing,
                mainAxisSpacing: _mainAxisSpacing,
              ),
              itemCount: vm.items.length + (vm.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= vm.items.length) {
                  return const Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final item = vm.items[index];
                return MediaGridItem(
                  item: item,
                  isSelected: vm.selectedPaths.contains(item.path),
                  onTap: () => _onItemTap(context, vm, item),
                  thumbnailLoader: (i) => vm.getThumbnail(i),
                  onExport: () => _exportSingle(vm, item),
                  onSelect: () {
                    if (!_selectMode) setState(() => _selectMode = true);
                    vm.toggleSelection(item.path);
                  },
                );
              },
            ),
            if (_isDragging && _dragStart != null && _dragCurrent != null)
              Positioned.fromRect(
                rect: Rect.fromPoints(_dragStart!, _dragCurrent!),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _updateDragSelection(GalleryViewModel vm) {
    if (_dragStart == null || _dragCurrent == null) return;

    final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
    final scrollOffset = _scrollController.offset;

    final itemWidth = (_gridWidth - _gridPadding * 2 - _crossAxisSpacing * (_crossAxisCount - 1)) / _crossAxisCount;
    final itemHeight = itemWidth;

    final selected = <String>{};
    for (int i = 0; i < vm.items.length; i++) {
      final row = i ~/ _crossAxisCount;
      final col = i % _crossAxisCount;

      final left = _gridPadding + col * (itemWidth + _crossAxisSpacing);
      final top = _gridPadding + row * (itemHeight + _mainAxisSpacing) - scrollOffset;

      final itemRect = Rect.fromLTWH(left, top, itemWidth, itemHeight);
      if (rect.overlaps(itemRect)) {
        selected.add(vm.items[i].path);
      }
    }

    vm.updateDragSelection(selected);
  }

  void _onItemTap(BuildContext context, GalleryViewModel vm, MediaItem item) {
    if (_selectMode) {
      vm.toggleSelection(item.path);
    } else {
      final index = vm.items.indexOf(item);
      showDialog(
        context: context,
        builder: (ctx) => _PreviewDialog(
          vm: vm,
          initialIndex: index >= 0 ? index : 0,
        ),
      );
    }
  }

  Future<void> _exportSelected(GalleryViewModel vm) async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    final count = await vm.exportSelected(dir);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 $count 个文件到 $dir')),
      );
    }
  }

  Future<void> _exportSingle(GalleryViewModel vm, MediaItem item) async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    final ok = await vm.exportSingle(dir, item);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已导出 ${item.name}' : '导出失败')),
      );
    }
  }
}

/// 可拖拽调整大小的预览窗口
class _PreviewDialog extends StatefulWidget {
  final GalleryViewModel vm;
  final int initialIndex;

  const _PreviewDialog({required this.vm, required this.initialIndex});

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  late int _index;
  FocusNode? _focusNode;

  // 窗口大小
  double _width = 0;
  double _height = 0;
  static const double _minWidth = 500;
  static const double _minHeight = 400;

  // 控件渐隐
  double _controlsOpacity = 1.0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode?.requestFocus();
      final size = MediaQuery.of(context).size;
      setState(() {
        _width = size.width * 0.85;
        _height = size.height * 0.85;
      });
    });
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (_controlsOpacity != 1.0 && mounted) {
      setState(() => _controlsOpacity = 1.0);
    }
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _controlsOpacity = 0.0);
    });
  }

  MediaItem get _item => widget.vm.items[_index];
  bool get _hasPrev => _index > 0;
  bool get _hasNext => _index < widget.vm.items.length - 1;

  void _goTo(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.vm.items.length) return;
    setState(() => _index = newIndex);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final screenSize = MediaQuery.of(context).size;

    return KeyboardListener(
      focusNode: _focusNode!,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _hasPrev) {
            _goTo(_index - 1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && _hasNext) {
            _goTo(_index + 1);
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        }
      },
      child: Center(
        child: Container(
          width: _width.clamp(_minWidth, screenSize.width - 40),
          height: _height.clamp(_minHeight, screenSize.height - 40),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: 4),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: MouseRegion(
            onHover: (_) => _resetHideTimer(),
            onEnter: (_) => _resetHideTimer(),
            child: Stack(
              children: [
                Column(
                  children: [
                    // 标题栏
                    AnimatedOpacity(
                      opacity: _controlsOpacity,
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                Text('${_index + 1} / ${widget.vm.items.length}',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
                    // 内容区
                    Expanded(
                      child: item.isVideo ? _buildVideo(item) : _buildImage(item),
                    ),
                  ],
                ),
                // 渐隐的左右导航按钮
                AnimatedOpacity(
                  opacity: _controlsOpacity,
                  duration: const Duration(milliseconds: 300),
                  child: Stack(
                    children: [
                      if (_hasPrev)
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 20,
                          child: Center(
                            child: IconButton.filledTonal(
                              onPressed: () => _goTo(_index - 1),
                              icon: const Icon(Icons.chevron_left),
                              iconSize: 28,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      if (_hasNext)
                        Positioned(
                          right: 28,
                          top: 0,
                          bottom: 20,
                          child: Center(
                            child: IconButton.filledTonal(
                              onPressed: () => _goTo(_index + 1),
                              icon: const Icon(Icons.chevron_right),
                              iconSize: 28,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 右下角拖拽调整大小手柄
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _width = (_width + details.delta.dx).clamp(_minWidth, screenSize.width - 40);
                        _height = (_height + details.delta.dy).clamp(_minHeight, screenSize.height - 40);
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Icon(Icons.drag_handle, size: 14,
                        color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(MediaItem item) {
    return FutureBuilder<String?>(
      future: widget.vm.downloadToTemp(item),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasData && snap.data != null) {
          return InteractiveViewer(
            child: Image.file(File(snap.data!), fit: BoxFit.contain),
          );
        }
        return const Center(child: Text('无法加载'));
      },
    );
  }

  Widget _buildVideo(MediaItem item) {
    return _VideoPlayer(
      key: ValueKey(item.path),
      item: item,
      vm: widget.vm,
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  final MediaItem item;
  final GalleryViewModel vm;

  const _VideoPlayer({required this.item, required this.vm, super.key});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late Player _player;
  late VideoController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final path = await widget.vm.downloadToTemp(widget.item);
    if (!mounted) return;
    if (path != null) {
      setState(() => _loading = false);
      _player.open(Media(path));
    } else {
      setState(() { _error = '无法下载视频'; _loading = false; });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('正在下载视频...'),
        ],
      ));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    return Video(controller: _controller, controls: MaterialVideoControls);
  }
}
