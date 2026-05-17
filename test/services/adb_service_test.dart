import 'package:flutter_test/flutter_test.dart';
import 'package:android_manager/services/adb_service.dart';

void main() {
  group('AdbService', () {
    test('isAdbAvailable 检测 adb 是否安装', () async {
      final adb = AdbService();
      final result = await adb.isAdbAvailable();
      expect(result, isA<bool>());
    });

    test('parseDevices 正确解析 adb devices 输出', () {
      const output = '''
List of devices attached
ABC123456\tdevice
DEF789012\tunauthorized

''';
      final devices = AdbService.parseDevices(output);
      expect(devices.length, 2);
      expect(devices[0].serial, 'ABC123456');
      expect(devices[0].isAuthorized, true);
      expect(devices[1].serial, 'DEF789012');
      expect(devices[1].isAuthorized, false);
    });

    test('parseDevices 空输出返回空列表', () {
      final devices = AdbService.parseDevices('');
      expect(devices, isEmpty);
    });

    test('parseDevices 只有表头返回空列表', () {
      const output = 'List of devices attached\n';
      final devices = AdbService.parseDevices(output);
      expect(devices, isEmpty);
    });
  });
}
