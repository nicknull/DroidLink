import 'package:flutter_test/flutter_test.dart';
import 'package:android_manager/models/device_info.dart';
import 'package:android_manager/models/file_item.dart';
import 'package:android_manager/models/app_info.dart';
import 'package:android_manager/models/media_item.dart';

void main() {
  group('DeviceInfo', () {
    test('从 getprop 输出解析设备信息', () {
      const getpropOutput = '''
[ro.product.model]: [Pixel 7]
[ro.build.version.release]: [14]
[ro.build.version.sdk]: [34]
[persist.sys.timezone]: [Asia/Shanghai]
''';
      final info = DeviceInfo.fromGetprop(getpropOutput);
      expect(info.model, 'Pixel 7');
      expect(info.androidVersion, '14');
      expect(info.sdkVersion, '34');
    });
  });

  group('FileItem', () {
    test('从 ls -la 输出解析目录项', () {
      const lsLine =
          'drwxrwx--x 16 root sdcard_rw 4096 2024-01-15 10:30 DCIM';
      final item = FileItem.fromLsLine(lsLine, '/sdcard');
      expect(item.name, 'DCIM');
      expect(item.isDirectory, true);
      expect(item.size, 4096);
      expect(item.path, '/sdcard/DCIM');
    });

    test('解析文件行', () {
      const lsLine =
          '-rw-rw----  1 root sdcard_rw 2048 2024-01-15 10:30 test.jpg';
      final item = FileItem.fromLsLine(lsLine, '/sdcard');
      expect(item.name, 'test.jpg');
      expect(item.isDirectory, false);
      expect(item.size, 2048);
    });
  });

  group('AppInfo', () {
    test('从 pm list packages 输出解析应用信息', () {
      const pmLine =
          'package:/data/app/~~abc==/com.example.app-xyz==/base.apk=com.example.app';
      final info = AppInfo.fromPmLine(pmLine);
      expect(info.packageName, 'com.example.app');
      expect(info.apkPath,
          '/data/app/~~abc==/com.example.app-xyz==/base.apk');
    });
  });

  group('MediaItem', () {
    test('创建媒体项', () {
      final item = MediaItem(
        name: 'IMG_20240101.jpg',
        path: '/sdcard/DCIM/Camera/IMG_20240101.jpg',
        size: 3072000,
        modifiedDate: '2024-01-01 12:00',
        isVideo: false,
      );
      expect(item.isImage, true);
      expect(item.isVideo, false);
    });
  });
}
