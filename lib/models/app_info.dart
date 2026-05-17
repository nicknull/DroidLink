class AppInfo {
  final String packageName;
  final String apkPath;
  final String label;
  final String versionName;
  final String versionCode;
  final bool isSystem;
  final int size;
  bool isFavorite;

  AppInfo({
    required this.packageName,
    this.apkPath = '',
    this.label = '',
    this.versionName = '',
    this.versionCode = '',
    this.isSystem = false,
    this.size = 0,
    this.isFavorite = false,
  });

  factory AppInfo.fromPmLine(String line) {
    // 格式: package:/path/to/base.apk=com.example.app versionCode:123
    // 或:   package:/path/to/base.apk=com.example.app
    final versionCodeMatch = RegExp(r'versionCode:(\d+)').firstMatch(line);
    final versionCode = versionCodeMatch?.group(1) ?? '';
    final cleanLine = versionCodeMatch != null
        ? line.substring(0, versionCodeMatch.start).trim()
        : line;

    final eqIndex = cleanLine.lastIndexOf('=');
    final packageName = eqIndex != -1 ? cleanLine.substring(eqIndex + 1) : '';
    final colonIndex = cleanLine.indexOf(':');
    final apkPath =
        colonIndex != -1 && eqIndex != -1
            ? cleanLine.substring(colonIndex + 1, eqIndex)
            : '';

    return AppInfo(
      packageName: packageName,
      apkPath: apkPath,
      versionCode: versionCode,
    );
  }

  /// 从包名提取可读名称作为 fallback label
  static String extractLabel(String packageName) {
    final parts = packageName.split('.');
    if (parts.isEmpty) return packageName;
    // 取最后一段，首字母大写
    final last = parts.last;
    if (last.isEmpty && parts.length >= 2) return _capitalize(parts[parts.length - 2]);
    return _capitalize(last);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String get displayLabel => label.isNotEmpty ? label : extractLabel(packageName);

  AppInfo copyWith({
    String? packageName,
    String? apkPath,
    String? label,
    String? versionName,
    String? versionCode,
    bool? isSystem,
    int? size,
    bool? isFavorite,
  }) {
    return AppInfo(
      packageName: packageName ?? this.packageName,
      apkPath: apkPath ?? this.apkPath,
      label: label ?? this.label,
      versionName: versionName ?? this.versionName,
      versionCode: versionCode ?? this.versionCode,
      isSystem: isSystem ?? this.isSystem,
      size: size ?? this.size,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
