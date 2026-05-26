import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_manager/models/media_item.dart';

class MediaGridItem extends StatelessWidget {
  final MediaItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final Future<String?> Function(MediaItem) thumbnailLoader;
  final VoidCallback? onExport;

  const MediaGridItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.onDoubleTap,
    required this.thumbnailLoader,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 缩略图
          FutureBuilder<String?>(
            future: thumbnailLoader(item),
            builder: (context, snap) {
              if (snap.hasData && snap.data != null && File(snap.data!).existsSync()) {
                return Image.file(File(snap.data!), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                );
              }
              return _buildPlaceholder(context);
            },
          ),
          // 视频播放图标
          if (item.isVideo)
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
              ),
            ),
          if (isSelected)
            Positioned(
              top: 4, right: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ContextMenuOverlay(
        position: position,
        onDismiss: () => entry.remove(),
        children: [
          if (onExport != null)
            _MenuItem(icon: Icons.download, label: '导出到电脑', onTap: () { entry.remove(); onExport!(); }),
        ],
      ),
    );
    overlay.insert(entry);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          item.isVideo ? Icons.videocam : Icons.image,
          size: 32,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _ContextMenuOverlay extends StatelessWidget {
  final Offset position;
  final VoidCallback onDismiss;
  final List<_MenuItem> children;

  const _ContextMenuOverlay({required this.position, required this.onDismiss, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 点击空白关闭
        Positioned.fill(child: GestureDetector(onTap: onDismiss, child: Container(color: Colors.transparent))),
        // 菜单
        Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
