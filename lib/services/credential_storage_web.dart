import 'package:web/web.dart' as web;

class CredentialStorageImpl {
  static const String _keyRemember = 'so_remember_credentials';
  static const String _keyUsername = 'so_saved_username';
  static const String _keyPassword = 'so_saved_password';

  static Future<Map<String, dynamic>> loadCredentials() async {
    try {
      final storage = web.window.localStorage;
      final rememberStr = storage.getItem(_keyRemember);
      final bool remember = rememberStr == null ? true : (rememberStr == 'true');
      final String username = storage.getItem(_keyUsername) ?? '';
      final String password = storage.getItem(_keyPassword) ?? '';
      return {
        'remember': remember,
        'username': remember ? username : '',
        'password': remember ? password : '',
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
      final storage = web.window.localStorage;
      storage.setItem(_keyRemember, remember ? 'true' : 'false');
      if (remember) {
        storage.setItem(_keyUsername, username);
        storage.setItem(_keyPassword, password);
      } else {
        storage.removeItem(_keyUsername);
        storage.removeItem(_keyPassword);
      }
    } catch (_) {}
  }
}
