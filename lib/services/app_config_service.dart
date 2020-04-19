import 'dart:async' show Future;
import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/services/service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show Client;

class AppConfigService {
  final Client client;
  final String asset;
  final String baseUrl;

  AppConfigService({
    @required this.asset,
    @required this.client,
    @required this.baseUrl,
  });

  /// Initializes configuration to default values for given version.
  ///
  /// POST ../app-config/{version}
  Future<ServiceResponse<AppConfig>> create(AppConfig config, int version) async {
    // TODO: Implement fetch app-config
    throw "Not implemented";
  }

  /// GET ../app-config/{uuid}
  Future<ServiceResponse<AppConfig>> fetch(String uuid) async {
    // TODO: Implement fetch app-config
    throw "Not implemented";
  }

  /// PATCH ../app-config/{uuid}
  Future<ServiceResponse<AppConfig>> update(AppConfig config) async {
    // TODO: Implement save app-config
    throw "Not implemented";
  }

  /// DELETE ../app-config/{uuid}
  Future<ServiceResponse<AppConfig>> delete(String uuid) async {
    // TODO: Implement fetch app-config
    throw "Not implemented";
  }
}
