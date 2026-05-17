import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:android_manager/viewmodels/device_viewmodel.dart';
import 'package:android_manager/viewmodels/screenshot_viewmodel.dart';

String get _scrcpyTooltip => Platform.isWindows
    ? '录屏/投屏需要 scrcpy\n请访问 github.com/Genymobile/scrcpy 下载'
    : '录屏/投屏需要 scrcpy\n安装: brew install scrcpy';

String get _revealLabel => Platform.isMacOS ? '在 Finder 中显示' : '在资源管理器中显示';

class ScreenshotView extends StatefulWidget {
  const ScreenshotView({super.key});

  @override
  State<ScreenshotView> createState() => _ScreenshotViewState();
}

class _ScreenshotViewState extends State<ScreenshotView> {
  ScreenshotViewModel? _vm;
  String? _currentSerial;

  // 视频播放器
  Player? _player;
  VideoController? _videoController;
  String? _playingVideoPath;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _player = Player();
    _videoController = VideoController(_player!);
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
        _vm = ScreenshotViewModel(deviceVM.adb, serial);
      } else {
        _vm = null;
      }
      _stopVideo();
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    _vm?.dispose();
    super.dispose();
  }

  void _disposePlayer() {
    _player?.dispose();
    _player = null;
    _videoController = null;
    _playingVideoPath = null;
  }

  void _stopVideo() {
    _player?.stop();
    _playingVideoPath = null;
  }

  void _playVideo(String path) {
    if (_playingVideoPath == path) return;
    _playingVideoPath = path;
    _player!.open(Media(path));
  }

  @override
  Widget build(BuildContext context) {
    if (_vm == null) return const SizedBox.shrink();

    return ChangeNotifierProvider.value(
      value: _vm!,
      child: Builder(builder: (context) => Column(
        children: [
          _buildToolbar(context),
          if (_vm?.error != null)
            MaterialBanner(
              content: Text(_vm!.error!, style: const TextStyle(fontSize: 12)),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: () { _vm?.clearError(); },
                  child: const Text('关闭'),
                ),
              ],
            ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: _buildHistory(context),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildPreview(context)),
              ],
            ),
          ),
        ],
      )),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final vm = context.watch<ScreenshotViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: vm.capturing ? null : () => vm.takeScreenshot(),
            icon: const Icon(Icons.screenshot),
            label: const Text('截屏'),
          ),
          if (vm.canRecord)
            OutlinedButton.icon(
              onPressed: () => vm.openMirror(),
              icon: const Icon(Icons.screen_share),
              label: const Text('投屏'),
            ),
          if (vm.canRecord)
            if (vm.recording)
              FilledButton.icon(
                onPressed: () => vm.stopRecording(),
                icon: const Icon(Icons.stop),
                label: const Text('停止录屏'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => vm.startRecording(),
                icon: const Icon(Icons.videocam),
                label: const Text('录屏'),
              ),
          if (!vm.canRecord)
            Tooltip(
              message: _scrcpyTooltip,
              child: FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.videocam),
                label: const Text('录屏 (需 scrcpy)'),
              ),
            ),
          if (vm.recording)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)),
                SizedBox(width: 8),
                Text('正在录制...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          if (vm.capturing)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          if (vm.previewPath != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _formatPath(vm.previewPath!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    final vm = context.watch<ScreenshotViewModel>();
    if (vm.history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无记录\n截图和录屏会显示在这里', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: vm.history.length,
      itemBuilder: (context, index) {
        final record = vm.history[index];
        final time = '${record.time.hour}:${record.time.minute.toString().padLeft(2, '0')}:${record.time.second.toString().padLeft(2, '0')}';
        final isSelected = vm.previewPath == record.localPath;
        return ListTile(
          dense: true,
          leading: record.isVideo
              ? const Icon(Icons.videocam, size: 20)
              : (File(record.localPath).existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(File(record.localPath), width: 32, height: 32, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.screenshot, size: 20)),
          title: Text(time, style: const TextStyle(fontSize: 12)),
          subtitle: Text(
            record.isVideo ? '视频 · ${_formatSize(File(record.localPath).lengthSync())}' : '截图',
            style: const TextStyle(fontSize: 10),
          ),
          selected: isSelected,
          onTap: () {
            vm.setPreview(record.localPath);
            if (record.isVideo) {
              _playVideo(record.localPath);
            } else {
              _stopVideo();
            }
          },
          trailing: PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'open', child: Text('用系统播放器打开')),
              PopupMenuItem(value: 'reveal', child: Text(_revealLabel)),
              const PopupMenuItem(value: 'delete', child: Text('删除文件')),
            ],
            onSelected: (action) {
              switch (action) {
                case 'open':
                  vm.openInSystem(record.localPath);
                  break;
                case 'reveal':
                  vm.revealInFinder(record.localPath);
                  break;
                case 'delete':
                  vm.deleteRecord(index);
                  break;
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildPreview(BuildContext context) {
    final vm = context.watch<ScreenshotViewModel>();

    if (vm.capturing) return const Center(child: CircularProgressIndicator());
    if (vm.previewPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screenshot_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('点击截屏或录屏按钮开始', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }

    final file = File(vm.previewPath!);
    if (!file.existsSync()) {
      return const Center(child: Text('文件不存在'));
    }

    final isVideo = vm.previewPath!.endsWith('.mp4');

    if (isVideo) {
      return _buildVideoPreview(context, vm);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
        // 右下角操作按钮
        Positioned(
          right: 16,
          bottom: 16,
          child: Wrap(
            spacing: 8,
            children: [
              FloatingActionButton.small(
                heroTag: 'open',
                onPressed: () => vm.openInSystem(vm.previewPath!),
                child: const Icon(Icons.open_in_new),
              ),
              FloatingActionButton.small(
                heroTag: 'reveal',
                onPressed: () => vm.revealInFinder(vm.previewPath!),
                child: const Icon(Icons.folder_open),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreview(BuildContext context, ScreenshotViewModel vm) {
    // 如果还没开始播放这个视频
    if (_playingVideoPath != vm.previewPath) {
      // 延迟一帧再播放，避免在 build 中触发状态变更
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && vm.previewPath != null) {
          _playVideo(vm.previewPath!);
        }
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_videoController != null)
          Video(
            controller: _videoController!,
            fit: BoxFit.contain,
          ),
        // 右下角操作按钮
        Positioned(
          right: 16,
          bottom: 16,
          child: Wrap(
            spacing: 8,
            children: [
              FloatingActionButton.small(
                heroTag: 'open',
                onPressed: () => vm.openInSystem(vm.previewPath!),
                child: const Icon(Icons.open_in_new),
              ),
              FloatingActionButton.small(
                heroTag: 'reveal',
                onPressed: () => vm.revealInFinder(vm.previewPath!),
                child: const Icon(Icons.folder_open),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatPath(String path) {
    final home = Platform.environment['HOME']
        ?? Platform.environment['USERPROFILE']
        ?? '';
    if (home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
