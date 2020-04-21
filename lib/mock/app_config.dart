import 'dart:convert';

import 'package:http/http.dart';
import 'package:mockito/mockito.dart';

import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:SarSys/services/service.dart';

class AppConfigServiceMock extends Mock implements AppConfigService {
  static AppConfigService build(String asset, String baseUrl, Client client) {
    final AppConfigServiceMock mock = AppConfigServiceMock();
    when(mock.asset).thenAnswer((_) => asset);
    when(mock.baseUrl).thenAnswer((_) => baseUrl);
    when(mock.client).thenAnswer((_) => client);
    when(mock.create(any, any)).thenAnswer((_) async {
      final config = _.positionalArguments[0];
      final json = jsonEncode(config.toJson());
      await Storage.secure.write(
        key: 'app_config_${config.uuid}',
        value: json,
      );
      return ServiceResponse.ok(body: config);
    });
    when(mock.fetch(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      final value = await Storage.secure.read(
        key: 'app_config_$uuid',
      );
      if (value == null) {
        return ServiceResponse.notFound(
          message: 'AppConfig $uuid not found',
        );
      }
      final json = jsonDecode(value);
      final config = AppConfig.fromJson(json);
      return ServiceResponse.ok(
        body: config,
      );
    });
    when(mock.update(any)).thenAnswer((_) async {
      final newConfig = _.positionalArguments[0] as AppConfig;
      final value = await Storage.secure.read(
        key: 'app_config_${newConfig.uuid}',
      );
      if (value == null) {
        return ServiceResponse.notFound(
          message: 'AppConfig ${newConfig.uuid} not found',
        );
      }
      final oldJson = jsonDecode(value) as Map<String, dynamic>;
      final newJson = newConfig.toJson();
      oldJson.addAll(newJson);
      final config = AppConfig.fromJson(oldJson);
      await Storage.secure.write(
        key: 'app_config_${config.uuid}',
        value: jsonEncode(oldJson),
      );
      return ServiceResponse.ok(
        body: config,
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0] as String;
      await Storage.secure.delete(
        key: 'app_config_$uuid',
      );
      return ServiceResponse.noContent();
    });
    return mock;
  }
}
