import 'package:flutter/material.dart';
import 'package:android_manager/models/file_item.dart';

class FileListTile extends StatelessWidget {
  final FileItem file;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;
  final VoidCallback? onSelect;

  const FileListTile({
    super.key,
    required this.file,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.onExport,
    this.onDelete,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
      child: ListTile(
        selected: isSelected,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle, color: Colors.blue, size: 20),
              ),
            Icon(
              file.isDirectory ? Icons.folder : _fileIcon(file.extension),
              color: file.isDirectory ? Colors.amber : null,
            ),
          ],
        ),
        title: Text(file.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${_formatSize(file.size)}  ${file.modifiedDate}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onTap,
        onLongPress: onLongPress,
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
          _MenuItem(
            icon: Icons.folder_open,
            label: '打开',
            onTap: () { entry.remove(); onTap(); },
          ),
          if (onExport != null)
            _MenuItem(
              icon: Icons.download,
              label: '下载到本地',
              onTap: () { entry.remove(); onExport!(); },
            ),
          if (onDelete != null)
            _MenuItem(
              icon: Icons.delete_outline,
              label: '删除',
              onTap: () { entry.remove(); onDelete!(); },
            ),
          if (onSelect != null)
            _MenuItem(
              icon: Icons.check_circle_outline,
              label: '选择',
              onTap: () { entry.remove(); onSelect!(); },
            ),
        ],
      ),
    );
    overlay.insert(entry);
  }

  IconData _fileIcon(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case '3gp':
      case 'mkv':
      case 'avi':
        return Icons.videocam;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'apk':
        return Icons.android;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'txt':
      case 'log':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
        Positioned.fill(child: GestureDetector(onTap: onDismiss, child: Container(color: Colors.transparent))),
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
