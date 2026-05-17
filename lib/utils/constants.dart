class AppConstants {
  static const String defaultAdbPath = 'adb';
  static const List<String> mediaPaths = [
    '/sdcard/DCIM',
    '/sdcard/Pictures',
    '/sdcard/Movies',
  ];
  // find 命令中排除的路径模式（缩略图缓存、隐藏目录等）
  static const List<String> excludePatterns = [
    r"-not -path '*/.thumbnails/*'",
    r"-not -path '*/.thumb_*'",
    r"-not -path '*/.*'",
  ];
  static const String defaultStartPath = '/sdcard';
  static const String tempDir = 'android_manager_temp';
}
