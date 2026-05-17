class MediaItem {
  final String name;
  final String path;
  final int size;
  final String modifiedDate;
  final int timestamp; // 原始时间戳，用于精确排序
  final bool isVideo;
  String? localThumbnailPath;

  MediaItem({
    required this.name,
    required this.path,
    required this.size,
    required this.modifiedDate,
    required this.isVideo,
    this.timestamp = 0,
    this.localThumbnailPath,
  });

  bool get isImage => !isVideo;

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot == -1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static bool isImageFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  static bool isVideoFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['mp4', '3gp', 'webm', 'mkv', 'avi', 'mov'].contains(ext);
  }
}
