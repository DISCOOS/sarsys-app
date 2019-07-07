import 'dart:convert';

import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfigServiceMock extends Mock implements AppConfigService {
  static AppConfigService build(String asset, String baseUrl, Client client) {
    final AppConfigServiceMock mock = AppConfigServiceMock();
    AppConfig config;
    SharedPreferences prefs;
    when(mock.asset).thenAnswer((_) => asset);
    when(mock.baseUrl).thenAnswer((_) => baseUrl);
    when(mock.client).thenAnswer((_) => client);
    when(mock.prefs).thenAnswer((_) => prefs);
    when(mock.config).thenAnswer((_) async {
      return config;
    });
    when(mock.init()).thenAnswer((_) async {
      final Map<String, dynamic> assets = json.decode(await rootBundle.loadString(asset));
      prefs = await SharedPreferences.getInstance();
      return (config = AppConfig.fromJson(assets));
    });
    when(mock.fetch()).thenAnswer((_) async => Future.value(config));
    when(mock.save(any)).thenAnswer((c) async => Future.value(config = c.positionalArguments[0]));
    return mock;
  }
}
