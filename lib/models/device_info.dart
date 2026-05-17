class DeviceInfo {
  final String serial;
  final String model;
  final String androidVersion;
  final String sdkVersion;
  final String batteryLevel;
  final String batteryStatus;
  final String storageTotal;
  final String storageUsed;
  final String screenResolution;

  const DeviceInfo({
    required this.serial,
    this.model = '',
    this.androidVersion = '',
    this.sdkVersion = '',
    this.batteryLevel = '',
    this.batteryStatus = '',
    this.storageTotal = '',
    this.storageUsed = '',
    this.screenResolution = '',
  });

  factory DeviceInfo.fromGetprop(String output, {String serial = ''}) {
    String getProp(String key) {
      final escapedKey = RegExp.escape(key);
      final regex = RegExp('\\[$escapedKey\\]: \\[(.*?)\\]');
      final match = regex.firstMatch(output);
      return match?.group(1) ?? '';
    }

    return DeviceInfo(
      serial: serial,
      model: getProp('ro.product.model'),
      androidVersion: getProp('ro.build.version.release'),
      sdkVersion: getProp('ro.build.version.sdk'),
    );
  }

  DeviceInfo copyWith({
    String? serial,
    String? model,
    String? androidVersion,
    String? sdkVersion,
    String? batteryLevel,
    String? batteryStatus,
    String? storageTotal,
    String? storageUsed,
    String? screenResolution,
  }) {
    return DeviceInfo(
      serial: serial ?? this.serial,
      model: model ?? this.model,
      androidVersion: androidVersion ?? this.androidVersion,
      sdkVersion: sdkVersion ?? this.sdkVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      storageTotal: storageTotal ?? this.storageTotal,
      storageUsed: storageUsed ?? this.storageUsed,
      screenResolution: screenResolution ?? this.screenResolution,
    );
  }
}
