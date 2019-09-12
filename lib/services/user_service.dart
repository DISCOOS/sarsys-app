import 'dart:convert';

import 'package:SarSys/services/service_response.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:jose/jose.dart';

class UserService {
  final String url;
  final Client client;

  // TODO: Take into account that several users may use the app and handle token storage accordingly
  // TODO: Hash the password and save after successful authentication (for offline login to app)? Possible as long as token is valid?

  static final storage = new FlutterSecureStorage();

  UserService(this.url, this.client);

  /// Authorize with basic auth and get token
  Future<ServiceResponse<String>> login(String username, String password) async {
    // TODO: Change to http_client to get better control of timeout, retries etc.
    // TODO: Handle various login/network errors and throw appropriate errors
    try {
      var response = await http.post(url, body: {'username': username, 'password': password});

      // Save to token and other userdata to Secure Storage
      if (response.statusCode == 200) {
        // TODO: Validate JWT
        var responseObject = jsonDecode(response.body);
        await storage.write(key: 'token', value: responseObject['token']);
        return ServiceResponse.ok(body: responseObject['token']);
      } else if (response.statusCode == 401) {
        // wrong credentials
        return ServiceResponse.unauthorized(message: "Feil brukernavn/passord");
      } else if (response.statusCode == 403) {
        // Forbidden
        return ServiceResponse.forbidden(message: "Du har ikke tilgang");
      }
      return ServiceResponse(
        code: response.statusCode,
        message: response.reasonPhrase,
      );
    } on Exception catch (e) {
      return ServiceResponse.error(message: "Failed to login", error: e);
    }
  }

  /// Get current token from secure storage
  Future<ServiceResponse<String>> getToken() async {
    String _tokenFromStorage = await storage.read(key: "token");
    if (_tokenFromStorage != null) {
      // TODO: Validate token (checks only for expired, should probably do a bit more)
      try {
        var jwt = JsonWebToken.unverified(_tokenFromStorage);
        print("claims: ${jwt.claims}");
        print(new DateTime.now().millisecondsSinceEpoch / 1000);
        if (jwt.claims.expiry.isAfter(new DateTime.now())) {
          print("token still valid");
          return ServiceResponse.ok(body: _tokenFromStorage);
        }
      } catch (e) {
        return ServiceResponse.error(error: e);
      }
    }
    return ServiceResponse.unauthorized();
  }

  /// Delete token from secure storage
  Future<ServiceResponse<void>> logout() async {
    try {
      // Delete token from storage
      await storage.delete(key: 'token');
      return ServiceResponse.noContent();
    } on Exception catch (e) {
      return ServiceResponse.error(message: "Failed to delete token from storage", error: e);
    }
  }
}
