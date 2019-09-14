import 'dart:convert';
import 'dart:async' show Future;
import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:http/http.dart' show Client;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// TODO: Add dependency 'flutter_udid' for unique appId

class AppConfigService {
  final Client client;
  final String asset;
  final String baseUrl;

  SharedPreferences prefs;

  AppConfigService(this.asset, this.baseUrl, this.client) {
    init();
  }

  Future<AppConfig> init() async {
    final Map<String, dynamic> assets = json.decode(await rootBundle.loadString(asset));
    prefs = await SharedPreferences.getInstance();
    await _setAll(assets);
    return AppConfig.fromJson(assets);
  }

  Future<AppConfig> get config async {
    Map<String, dynamic> json = {};
    if (prefs == null) return init();
    prefs.getKeys().forEach((key) => _get(json, key));
    return AppConfig.fromJson(json);
  }

  void _get(Map<String, dynamic> json, String key) async {
    if (AppConfig.PARAMS.containsKey(key)) {
      switch (AppConfig.PARAMS[key]) {
        case "String":
          return json.putIfAbsent(key, () => prefs.getString(key));
        case "bool":
          return json.putIfAbsent(key, () => prefs.getBool(key));
        case "int":
          return json.putIfAbsent(key, () => prefs.getInt(key));
        case "double":
          return json.putIfAbsent(key, () => prefs.getDouble(key));
        case "StringList":
          return json.putIfAbsent(key, () => prefs.getStringList(key));
      }
    }
    throw "Type ${AppConfig.PARAMS[key]} for $key is not supported";
  }

  /// GET ../app-config
  Future<ServiceResponse<AppConfig>> fetch() async {
    // TODO: Implement fetch app-config
    throw "Not implemented";
  }

  Future<ServiceResponse<void>> save(AppConfig config) async {
    // TODO: Implement save app-config
    throw "Not implemented";
  }

  Future<void> _setAll(Map<String, dynamic> assets) async {
    return assets.forEach(_set);
  }

  Future<bool> _set(String key, value) async {
    return set(prefs, key, value);
  }

  static Future<bool> set(SharedPreferences prefs, String key, value) {
    if (AppConfig.PARAMS.containsKey(key)) {
      switch (AppConfig.PARAMS[key].toLowerCase()) {
        case "string":
          return prefs.setString(key, value);
        case "bool":
          return prefs.setBool(key, value);
        case "int":
          return prefs.setInt(key, value);
        case "double":
          return prefs.setDouble(key, value);
        case "stringlist":
          return prefs.setStringList(key, value);
      }
    }
    throw "Type ${AppConfig.PARAMS[key]} for $key is not supported";
  }

  static void setAll(SharedPreferences prefs, Map<String, dynamic> values) async {
    values.forEach((key, value) async => await set(prefs, key, value));
  }
}
