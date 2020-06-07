import 'dart:convert';

import 'package:SarSys/features/app_config/data/models/app_config_model.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';

import 'package:SarSys/core/storage.dart';
import 'package:SarSys/features/app_config/data/services/app_config_service.dart';
import 'package:SarSys/services/service.dart';

class AppConfigServiceMock extends Mock implements AppConfigService {
  static AppConfigService build(String asset, String baseUrl, Client client) {
    final AppConfigServiceMock mock = AppConfigServiceMock();
    when(mock.create(any)).thenAnswer((_) async {
      final config = _.positionalArguments[0];
      final json = jsonEncode(config.toJson());
      await Storage.secure.write(
        key: 'app_config_${config.uuid}',
        value: json,
      );
      return ServiceResponse.created();
    });
    when(mock.fetch(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      final value = await Storage.secure.read(
        key: 'app_config_$uuid',
      );
      if (value == null) {
        return ServiceResponse.notFound(
          message: 'AppConfigModel $uuid not found',
        );
      }
      final json = jsonDecode(value);
      final config = AppConfigModel.fromJson(json);
      return ServiceResponse.ok(
        body: config,
      );
    });
    when(mock.update(any)).thenAnswer((_) async {
      final newConfig = _.positionalArguments[0] as AppConfigModel;
      final value = await Storage.secure.read(
        key: 'app_config_${newConfig.uuid}',
      );
      if (value == null) {
        return ServiceResponse.notFound(
          message: 'AppConfigModel ${newConfig.uuid} not found',
        );
      }
      final oldJson = jsonDecode(value) as Map<String, dynamic>;
      final newJson = newConfig.toJson();
      oldJson.addAll(newJson);
      final config = AppConfigModel.fromJson(oldJson);
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
