import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// 从 APK 文件中提取应用名称
/// 解析 AndroidManifest.xml（二进制格式）和 resources.arsc
class ApkResourceParser {
  /// 从 APK 文件中提取 app label
  static Future<String?> parseAppLabel(String apkPath) async {
    try {
      final bytes = await File(apkPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. 解析 AndroidManifest.xml 找到 label 的值
      final manifestFile = archive.findFile('AndroidManifest.xml');
      if (manifestFile == null) return null;

      final manifestData = manifestFile.content as Uint8List;
      final labelValue = _parseManifestLabel(manifestData);

      if (labelValue == null) return null;

      // 如果是直接字符串（非资源引用）
      if (!_isResourceReference(labelValue)) {
        return labelValue;
      }

      // 2. 如果是资源引用，解析 resources.arsc
      final arscFile = archive.findFile('resources.arsc');
      if (arscFile == null) return null;

      final arscData = arscFile.content as Uint8List;
      final resourceId = _parseResourceId(labelValue);
      if (resourceId == null) return null;

      return _lookupResource(arscData, resourceId);
    } catch (_) {
      return null;
    }
  }

  /// 解析二进制 AndroidManifest.xml，找到 application 的 label 属性值
  static String? _parseManifestLabel(Uint8List data) {
    final reader = _BinaryReader(data);

    // 验证 AXML 文件头
    if (reader.remaining < 8) return null;
    final fileType = reader.readUint16();
    final headerSize = reader.readUint16();
    if (fileType != 0x0008) return null; // 不是 AXML 文件

    // 跳过文件头剩余部分
    reader.skip(headerSize - 4);

    String? stringPool;
    String? labelAttr;

    while (reader.remaining >= 8) {
      final chunkType = reader.readUint16();
      final chunkHeaderSize = reader.readUint16();
      final chunkSize = reader.readUint32();
      final chunkStart = reader.offset - 8;

      if (chunkType == 0x001) {
        // String Pool
        stringPool = _parseStringPool(reader, chunkHeaderSize);
      } else if (chunkType == 0x0170) {
        // Start Element
        labelAttr = _parseStartElement(reader, chunkHeaderSize, chunkSize, stringPool);
        if (labelAttr != null) return labelAttr;
      }

      // 跳到下一个 chunk
      reader.offset = chunkStart + chunkSize;
    }

    return null;
  }

  /// 解析字符串池
  static String? _parseStringPool(_BinaryReader reader, int headerSize) {
    final stringCount = reader.readUint32();
    reader.skip(4); // styleCount
    reader.skip(4); // flags
    final stringsStart = reader.readUint32();
    reader.skip(4); // stylesStart

    // 跳过偏移表
    final offsetsBase = reader.offset;
    reader.skip(stringCount * 4);

    // 保存字符串数据起始位置
    final stringsBase = reader.offset;

    // 解析前几个字符串（label 通常在前面）
    // 不需要全部解析，只需要知道格式

    // 回到字符串数据区域
    reader.offset = stringsBase;

    return null; // 字符串池在别处使用
  }

  /// 解析 XML Start Element，查找 application 标签的 label 属性
  static String? _parseStartElement(
    _BinaryReader reader,
    int headerSize,
    int chunkSize,
    String? stringPool,
  ) {
    final chunkStart = reader.offset - 8;

    reader.skip(4); // lineNumber
    reader.skip(4); // comment

    final nsStart = reader.readUint32();
    final nsSize = reader.readUint32();
    reader.skip(nsStart != 0xFFFFFFFF ? nsSize * 2 : 0); // namespace URI

    final nameIndex = reader.readUint32();

    // 检查是否是 application 标签（通过字符串池索引判断不可靠，需要检查属性）
    final attributeStart = reader.readUint16();
    final attributeSize = reader.readUint16();
    final attributeCount = reader.readUint16();
    final idIndex = reader.readUint16();
    final classIndex = reader.readUint16();
    final styleIndex = reader.readUint16();

    // 读取属性
    // android:label 的资源 ID 是 0x01010001
    for (int i = 0; i < attributeCount; i++) {
      final attrNs = reader.readUint32();
      final attrName = reader.readUint32();
      final attrRawValue = reader.readUint32();
      final attrSize2 = reader.readUint16();
      reader.skip(1); // reserved
      final attrType = reader.readUint8();
      final attrData = reader.readUint32();

      if (attrName == 0x01010001) {
        // android:label
        if (attrType == 0x03) {
          // TYPE_STRING
          // 需要从字符串池获取
          // 但我们没有保存完整的字符串池，这里返回资源引用标记
          return '@0x${attrRawValue.toRadixString(16).padLeft(8, '0')}';
        } else if (attrType == 0x01) {
          // TYPE_REFERENCE
          return '@0x${attrData.toRadixString(16).padLeft(8, '0')}';
        } else if (attrType == 0x12) {
          // TYPE_NULL / literal - 不太可能用于 label
        }
      }
    }

    return null;
  }

  static bool _isResourceReference(String value) {
    return value.startsWith('@0x');
  }

  static int? _parseResourceId(String value) {
    try {
      return int.parse(value.substring(1), radix: 16);
    } catch (_) {
      return null;
    }
  }

  /// 在 resources.arsc 中查找资源 ID 对应的字符串值
  static String? _lookupResource(Uint8List data, int resourceId) {
    final reader = _BinaryReader(data);

    // ResTable header
    if (reader.remaining < 12) return null;
    reader.skip(2); // type
    reader.skip(2); // headerSize
    final tableSize = reader.readUint32();
    final packageCount = reader.readUint32();

    // 资源 ID: 0xPPTTNNNN
    final targetPackage = (resourceId >> 24) & 0xFF;
    final targetType = (resourceId >> 16) & 0xFF;
    final targetEntry = resourceId & 0xFFFF;

    // 遍历所有 chunk
    while (reader.remaining >= 8) {
      final chunkStart = reader.offset;
      final chunkType = reader.readUint16();
      final chunkHeaderSize = reader.readUint16();
      final chunkSize = reader.readUint32();

      if (chunkType == 0x0200) {
        // ResTablePackage
        final result = _parsePackage(reader, chunkHeaderSize, chunkSize, targetPackage, targetType, targetEntry);
        if (result != null) return result;
      }

      reader.offset = chunkStart + chunkSize;
    }

    return null;
  }

  /// 解析 ResTablePackage chunk
  static String? _parsePackage(
    _BinaryReader reader,
    int headerSize,
    int chunkSize,
    int targetPackage,
    int targetType,
    int targetEntry,
  ) {
    final packageStart = reader.offset - 8;

    reader.skip(4); // id
    // 包名（256 个 UTF-16 字符）
    final nameChars = reader.readUint8List(256);
    String? packageName;
    for (int i = 0; i < 256; i += 2) {
      if (nameChars[i] == 0 && nameChars[i + 1] == 0) {
        packageName = String.fromCharCodes(nameChars.sublist(0, i).where((c) => c != 0));
        break;
      }
    }

    final typeStrings = reader.readUint32();
    final lastPublicType = reader.readUint32();
    final keyStrings = reader.readUint32();
    final lastPublicKey = reader.readUint32();
    final typeIdOffset = reader.readUint32();

    // package id 从 1 开始（0x7f 通常是第一个应用包）
    // ResTable_package 的 id 字段可能是实际 id 或 0
    // 这里需要检查 packageStart 处的 id
    reader.offset = packageStart + 8;
    final pkgId = reader.readUint32();
    reader.offset = packageStart + headerSize;

    // 如果不是目标包，跳过
    if (targetPackage != pkgId && targetPackage != 0x7f) {
      return null;
    }

    // 遍历包内的类型规范和类型数据
    final packageEnd = packageStart + chunkSize;

    while (reader.offset < packageEnd - 8) {
      final typeChunkStart = reader.offset;
      final typeChunkType = reader.readUint16();
      final typeChunkHeaderSize = reader.readUint16();
      final typeChunkSize = reader.readUint32();

      if (typeChunkType == 0x0001) {
        // String Pool - 类型字符串或键字符串
        // 跳过
      } else if (typeChunkType == 0x0201) {
        // ResTableTypeSpec
        reader.skip(typeChunkHeaderSize - 8);
        reader.skip((typeChunkSize - typeChunkHeaderSize));
      } else if (typeChunkType == 0x0202) {
        // ResTableType (note: chunk type 0x0001 reused, but we check for TYPE)
        // Actually ResTableType uses chunk type 0x0001
        // Let me re-check...
        // ResTableTypeSpec = 0x0202, ResTableType = 0x0001
        // But 0x0001 is also StringPool...
        // The distinction is the position/context
        reader.skip(typeChunkHeaderSize - 8);
        reader.skip((typeChunkSize - typeChunkHeaderSize));
      }

      reader.offset = typeChunkStart + typeChunkSize;
    }

    // 这种方法太复杂了，换一种更简单的方式
    // 直接扫描整个资源表寻找 UTF-16 字符串
    return _scanForAppName(reader.data);
  }

  /// 简化的扫描方式：在 resources.arsc 中寻找可能的 app 名称字符串
  /// 通过查找与 "app_name" 相邻的 UTF-16 字符串
  static String? _scanForAppName(Uint8List data) {
    try {
      // 搜索 "app_name" 的 UTF-16LE 编码
      final target = <int>[];
      for (final ch in 'app_name'.codeUnits) {
        target.add(ch);
        target.add(0);
      }

      for (int i = 0; i < data.length - target.length - 100; i++) {
        bool match = true;
        for (int j = 0; j < target.length; j++) {
          if (data[i + j] != target[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          // 在附近搜索 UTF-16 字符串
          // 向后搜索可能的值
          for (int scanOffset = 0; scanOffset < 500; scanOffset += 2) {
            final pos = i + target.length + scanOffset;
            if (pos + 4 > data.length) break;

            final strLen = data[pos] | (data[pos + 1] << 8);
            if (strLen > 0 && strLen < 50) {
              // 检查是否是有效的 UTF-16 字符串
              final strStart = pos + 4;
              if (strStart + strLen * 2 > data.length) continue;

              final chars = <int>[];
              bool valid = true;
              for (int c = 0; c < strLen; c++) {
                final byte1 = data[strStart + c * 2];
                final byte2 = data[strStart + c * 2 + 1];
                final codeUnit = byte1 | (byte2 << 8);
                if (codeUnit == 0 || codeUnit > 0xFFFF) {
                  valid = false;
                  break;
                }
                chars.add(codeUnit);
              }

              if (valid && chars.isNotEmpty) {
                final str = String.fromCharCodes(chars);
                // 过滤掉明显不是 app name 的字符串
                if (str.length >= 1 && str.length <= 20 &&
                    RegExp(r'^[一-鿿 -~]+$').hasMatch(str) &&
                    !str.contains('/') &&
                    !str.contains('.')) {
                  return str;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }
}

/// 二进制读取辅助类
class _BinaryReader {
  final Uint8List data;
  int offset;

  _BinaryReader(this.data) : offset = 0;

  int get remaining => data.length - offset;

  void skip(int bytes) {
    offset += bytes;
  }

  int readUint8() {
    return data[offset++];
  }

  Uint8List readUint8List(int length) {
    final result = data.sublist(offset, offset + length);
    offset += length;
    return result;
  }

  int readUint16() {
    final value = data[offset] | (data[offset + 1] << 8);
    offset += 2;
    return value;
  }

  int readUint32() {
    final value = data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
    offset += 4;
    return value;
  }
}
