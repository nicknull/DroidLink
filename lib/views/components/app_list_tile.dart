import 'package:flutter/material.dart';
import 'package:android_manager/models/app_info.dart';

class AppListTile extends StatelessWidget {
  final AppInfo app;
  final VoidCallback onUninstall;
  final VoidCallback onExport;
  final VoidCallback onToggleFavorite;
  final VoidCallback onForceStop;
  final VoidCallback onClearData;
  final VoidCallback onManagePermissions;

  const AppListTile({
    super.key,
    required this.app,
    required this.onUninstall,
    required this.onExport,
    required this.onToggleFavorite,
    required this.onForceStop,
    required this.onClearData,
    required this.onManagePermissions,
  });

  @override
  Widget build(BuildContext context) {
    final initial = app.displayLabel.isNotEmpty ? app.displayLabel[0].toUpperCase() : '?';
    final hasVersion = app.versionName.isNotEmpty || app.versionCode.isNotEmpty;

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onToggleFavorite,
            child: Icon(
              app.isFavorite ? Icons.star : Icons.star_border,
              size: 16,
              color: app.isFavorite ? Colors.amber : Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _avatarColor(app.packageName),
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              app.displayLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (hasVersion)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                app.versionName.isNotEmpty ? 'v${app.versionName}' : '#${app.versionCode}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(app.packageName, style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis),
          if (app.size > 0)
            Text(_formatSize(app.size), style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
        ],
      ),
      isThreeLine: app.size > 0,
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'force_stop', child: Text('强制停止')),
          const PopupMenuItem(value: 'clear_data', child: Text('清除数据')),
          const PopupMenuItem(value: 'permissions', child: Text('权限管理')),
          const PopupMenuItem(value: 'export', child: Text('导出 APK')),
          if (!app.isSystem)
            const PopupMenuItem(value: 'uninstall', child: Text('卸载')),
        ],
        onSelected: (value) {
          switch (value) {
            case 'force_stop': onForceStop();
            case 'clear_data': onClearData();
            case 'permissions': onManagePermissions();
            case 'export': onExport();
            case 'uninstall': onUninstall();
          }
        },
      ),
    );
  }

  Color _avatarColor(String pkg) {
    final hash = pkg.hashCode.abs();
    const colors = [
      Color(0xFFE53935), Color(0xFF8E24AA), Color(0xFF3949AB),
      Color(0xFF00897B), Color(0xFF43A047), Color(0xFFFFB300),
      Color(0xFFFB8C00), Color(0xFF6D4C41), Color(0xFF546E7A),
      Color(0xFF1E88E5),
    ];
    return colors[hash % colors.length];
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
