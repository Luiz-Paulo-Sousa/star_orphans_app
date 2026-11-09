import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CredentialStorageImpl {
  static Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/star_orphans_credentials.json');
  }

  static Future<Map<String, dynamic>> loadCredentials() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return {'remember': true, 'username': '', 'password': ''};
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final bool remember = decoded['remember'] != false;
      return {
        'remember': remember,
        'username': remember ? (decoded['username'] ?? '').toString() : '',
        'password': remember ? (decoded['password'] ?? '').toString() : '',
      };
    } catch (_) {
      return {'remember': true, 'username': '', 'password': ''};
    }
  }

  static Future<void> saveCredentials({
    required bool remember,
    required String username,
    required String password,
  }) async {
    try {
      final file = await _getFile();
      if (remember) {
        await file.writeAsString(
          jsonEncode({
            'remember': true,
            'username': username,
            'password': password,
          }),
        );
      } else {
        await file.writeAsString(
          jsonEncode({
            'remember': false,
            'username': '',
            'password': '',
          }),
        );
      }
    } catch (_) {}
  }
}
