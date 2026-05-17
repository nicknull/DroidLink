import 'package:flutter_test/flutter_test.dart';
import 'package:android_manager/models/file_item.dart';

void main() {
  group('FileItem', () {
    test('从 ls 行解析目录', () {
      const line = 'drwxrwx--x 16 root sdcard_rw 4096 2024-01-15 10:30 DCIM';
      final item = FileItem.fromLsLine(line, '/sdcard');
      expect(item.name, 'DCIM');
      expect(item.isDirectory, true);
      expect(item.path, '/sdcard/DCIM');
    });

    test('从 ls 行解析文件', () {
      const line = '-rw-rw---- 1 root sdcard_rw 2048 2024-01-15 10:30 test.jpg';
      final item = FileItem.fromLsLine(line, '/sdcard');
      expect(item.name, 'test.jpg');
      expect(item.isDirectory, false);
      expect(item.extension, 'jpg');
    });

    test('路径拼接正确', () {
      final item = FileItem.fromLsLine(
        '-rw-rw---- 1 root root 100 2024-01-01 00:00 a.txt',
        '/',
      );
      expect(item.path, '/a.txt');
    });
  });
}
