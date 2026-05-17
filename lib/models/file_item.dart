class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final String modifiedDate;
  final String permissions;

  const FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modifiedDate = '',
    this.permissions = '',
  });

  factory FileItem.fromLsLine(String line, String parentPath) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 7) {
      return FileItem(name: '', path: parentPath, isDirectory: false);
    }

    final permissions = parts[0];
    final isDirectory = permissions.startsWith('d');
    final size = int.tryParse(parts[4]) ?? 0;
    final date = '${parts[5]} ${parts[6]}';
    final timeIndex = line.indexOf(parts[6]);
    final afterTime = line.substring(timeIndex + parts[6].length).trim();
    final name = afterTime;

    return FileItem(
      name: name,
      path: parentPath == '/'
          ? '/$name'
          : '$parentPath/$name',
      isDirectory: isDirectory,
      size: size,
      modifiedDate: date,
      permissions: permissions,
    );
  }

  String get extension {
    if (isDirectory) return '';
    final dot = name.lastIndexOf('.');
    if (dot == -1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}
