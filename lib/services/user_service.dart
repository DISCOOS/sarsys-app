import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:jose/jose.dart';

class UserService {
  final String url;
  final Client client;

  // TODO: Take into account that several users may use the app and handle token storage accordingly
  // TODO: Hash the password and save after successful authentication (for offline login to app)? Possible as long as token is valid?

  // static final UserService _singleton = new UserService();
  static final storage = new FlutterSecureStorage();

  UserService(this.url, this.client);

  //  factory UserService() {
  //    return _singleton;
  //  }

  Future<void> logout() async {
    // Delete token from storage
    await storage.delete(key: 'token');
  }

  // Log in to backed to get token
  Future<bool> login(String username, String password) async {
    // TODO: Change to http_client to get better control of timeout, retries etc.
    // TODO: Handle various login/network errors and throw appropriate errors
    var response = await http.post(url, body: {'username': username, 'password': password});

    // Save to token and other userdata to Secure Storage
    if (response.statusCode == 200) {
      // TODO: Validate JWT
      var responseObject = jsonDecode(response.body);

      await storage.write(key: 'token', value: responseObject['token']);
      // TODO: Save other userdata in User object with data from token
      var jwt = JsonWebToken.unverified(responseObject['token']);
      return true;
    } else if (response.statusCode == 401) {
      // wrong credentials
      throw "Feil brukernavn/passord";
    } else if (response.statusCode == 403) {
      // Forbidden
      throw "Du har ikke tilgang";
    }
    throw "${response.statusCode}: ${response.reasonPhrase}";
  }

  Future<String> getToken() async {
    String _tokenFromStorage = await storage.read(key: "token");
    if (_tokenFromStorage != null) {
      // TODO: Validate token (checks only for expired, should probably do a bit more)
      try {
        var jwt = new JsonWebToken.unverified(_tokenFromStorage);
        print("claims: ${jwt.claims}");
        print(new DateTime.now().millisecondsSinceEpoch / 1000);
        if (jwt.claims.expiry.isAfter(new DateTime.now())) {
          print("token still valid");
          return _tokenFromStorage;
        }
      } catch (error) {
        print("Invalid token structure");
        return null;
      }
    }
    return null;
  }
}
