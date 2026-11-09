class CredentialStorageImpl {
  static Future<Map<String, dynamic>> loadCredentials() async {
    return {'remember': true, 'username': '', 'password': ''};
  }

  static Future<void> saveCredentials({
    required bool remember,
    required String username,
    required String password,
  }) async {}
}
