import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as auth_io;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Linux-compatible wrapper that mimics GoogleSignInAccount
/// Uses OAuth2 credentials and fetches user info from Google API
class LinuxGoogleAccount implements GoogleSignInAccount {
  final auth_io.AccessCredentials _credentials;
  final Logger _logger = Logger();

  late final String? _email;
  late final String? _id;
  late final String? _displayName;
  late final String? _photoUrl;

  LinuxGoogleAccount(this._credentials);

  @override
  Future<GoogleSignInAuthentication> get authentication async {
    // Create a GoogleSignInAuthentication-like object
    // Note: This is a workaround since GoogleSignInAuthentication doesn't have a public constructor
    // The actual implementation may vary based on google_sign_in package version
    throw UnimplementedError('authentication getter not fully supported on Linux. Use authHeaders instead.');
  }

  @override
  String? get serverAuthCode => null;

  @override
  String get email => _email ?? '';

  @override
  String get id => _id ?? '';

  @override
  String get displayName => _displayName ?? '';

  @override
  String? get photoUrl => _photoUrl;

  @override
  Future<Map<String, String>> get authHeaders async => {'Authorization': 'Bearer ${_credentials.accessToken.data}'};

  /// Fetch user info from Google API
  Future<void> fetchUserInfo() async {
    try {
      final client = auth_io.authenticatedClient(http.Client(), _credentials);
      final response = await client.get(Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _email = data['email'] as String?;
        _id = data['id'] as String?;
        _displayName = data['name'] as String?;
        _photoUrl = data['picture'] as String?;
        _logger.i('User info fetched: $_email');
      } else {
        _logger.w('Failed to fetch user info: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching user info: $e');
    }
  }

  /// Get the underlying credentials (for refreshing)
  auth_io.AccessCredentials get credentials => _credentials;

  @override
  Future<void> clearAuthCache() async {
    // Not applicable for Linux OAuth2
  }

  // @override
  // Future<GoogleSignInAccount> requestScopes(List<String> scopes) async {
  //   // Scopes are already requested during OAuth flow
  //   return this;
  // }
}
