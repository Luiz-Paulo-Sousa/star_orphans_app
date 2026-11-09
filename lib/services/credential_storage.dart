import 'credential_storage_stub.dart'
    if (dart.library.js_interop) 'credential_storage_web.dart'
    if (dart.library.io) 'credential_storage_io.dart';

class CredentialStorage {
  static Future<Map<String, dynamic>> loadCredentials() =>
      CredentialStorageImpl.loadCredentials();

  static Future<void> saveCredentials({
    required bool remember,
    required String username,
    required String password,
  }) =>
      CredentialStorageImpl.saveCredentials(
        remember: remember,
        username: username,
        password: password,
      );
}
