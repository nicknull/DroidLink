import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String url;
  final String? notes;

  UpdateInfo({required this.version, required this.url, this.notes});
}

class UpdateService {
  static const _repo = 'nicknull/DroidLink';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';
  static const _releasePage = 'https://github.com/$_repo/releases';

  static Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final current = await currentVersion();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.set('User-Agent', 'DroidLink');
      final response = await request.close();
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tagName = (json['tag_name'] as String?) ?? '';
      final remoteVersion = tagName.replaceFirst(RegExp(r'^v'), '');
      if (remoteVersion.isEmpty) return null;

      if (_isNewer(remoteVersion, current)) {
        return UpdateInfo(
          version: remoteVersion,
          url: (json['html_url'] as String?) ?? _releasePage,
          notes: json['body'] as String?,
        );
      }
    } catch (_) {}
    return null;
  }

  /// 简单 semver 比较：a > b 返回 true
  static bool _isNewer(String a, String b) {
    final pa = a.split('.').map(int.parse).toList();
    final pb = b.split('.').map(int.parse).toList();
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      if (pa[i] > pb[i]) return true;
      if (pa[i] < pb[i]) return false;
    }
    return pa.length > pb.length;
  }
}
