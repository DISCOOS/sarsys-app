import 'dart:convert';
import 'dart:async' show Future;
import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_udid/flutter_udid.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' show Client;
import 'package:uuid/uuid.dart';

// TODO: Add dependency 'flutter_udid' for unique Security

class AppConfigService {
  static const VERSION = 1;
  static const KEY_JSON = 'json';
  static const KEY_VERSION = 'version';
  static const BOX_NAME = 'app_config';
  final Client client;
  final String asset;
  final String baseUrl;

  static Box box;

  AppConfigService(this.asset, this.baseUrl, this.client) {
    init();
  }

  /// Initializes configuration to default values.
  ///
  /// If configuration already exists [update()] will be called.
  Future<ServiceResponse<AppConfig>> init() async {
    // TODO: Store Hive.generateSecureKey() to secure storage and open box as encrypted
    box ??= await Hive.openBox(BOX_NAME);
    var defaults = await rootBundle.loadString(asset);
    final current = box.get(KEY_VERSION);
    if (current == null) {
      final uuid = Uuid().v4();
      final udid = await FlutterUdid.udid;
      box.put(KEY_VERSION, VERSION);
      final config = json.decode(defaults) as Map<String, dynamic>;
      config['uuid'] = uuid;
      config['udid'] = udid;
      // TODO: POST ../app-config
      await box.put(KEY_JSON, jsonEncode(config));
    } else if (current < VERSION) {
      // Overwrite current configuration
      final config = json.decode(box.get(KEY_JSON)) as Map<String, dynamic>;
      config.addAll(json.decode(defaults) as Map<String, dynamic>);
      final response = await update(AppConfig.fromJson(config));
      if (response.is204) {
        await box.clear();
        await box.put(KEY_VERSION, VERSION);
        await box.put(KEY_JSON, jsonEncode(response.body.toJson()));
      }
      return response;
    }
    await box.put(KEY_JSON, defaults);
    return ServiceResponse.ok(
      body: AppConfig.fromJson(json.decode(defaults)),
    );
  }

  /// GET ../app-config
  Future<ServiceResponse<AppConfig>> load() async {
    // TODO: Implement fetch app-config
    throw "Not implemented";
  }

  Future<ServiceResponse<AppConfig>> update(AppConfig config) async {
    // TODO: Implement save app-config
    throw "Not implemented";
  }
}
