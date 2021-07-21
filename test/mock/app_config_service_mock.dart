// @dart=2.11

import 'dart:convert';

import 'package:SarSys/features/settings/data/models/app_config_model.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/settings/data/services/app_config_service.dart';
import 'package:SarSys/core/data/services/service.dart';

class AppConfigServiceMock extends Mock implements AppConfigService {
  static AppConfigService build(String asset, String baseUrl, Client client) {
    var version = StateVersion.first;
    final AppConfigServiceMock mock = AppConfigServiceMock();
    when(mock.getFromId(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      final value = await _readConfig(uuid);
      if (value == null) {
        return ServiceResponse.notFound(
          message: 'AppConfigModel $uuid not found',
        );
      }
      final json = jsonDecode(value);
      final version = await _readVersion(uuid);
      final config = AppConfigModel.fromJson(json);
      return ServiceResponse.ok(
        body: StorageState(
          value: config,
          isRemote: true,
          version: version,
          status: version.isFirst ? StorageStatus.created : StorageStatus.updated,
        ),
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<AppConfig>;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final config = state.value;
      final json = jsonEncode(config.toJson());
      await _writeConfig(config, json);
      await _writeVersion(config);
      return ServiceResponse.ok(
        body: StorageState(
          value: config,
          isRemote: true,
          version: version,
          status: version.isFirst ? StorageStatus.created : StorageStatus.updated,
        ),
      );
    });
    when(mock.update(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<AppConfig>;
      final next = state.value;
      final uuid = next.uuid;
      final previous = await _readConfig(next.uuid);
      if (previous != null) {
        final version = await _readVersion(uuid);
        final delta = state.version.value - version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        final oldJson = jsonDecode(previous) as Map<String, dynamic>;
        final newJson = next.toJson();
        oldJson.addAll(newJson);
        final config = AppConfigModel.fromJson(oldJson);
        await _writeConfig(config, jsonEncode(oldJson));
        return ServiceResponse.ok(
          body: StorageState(
            value: config,
            isRemote: true,
            version: version,
            status: StorageStatus.updated,
          ),
        );
      }
      return ServiceResponse.notFound(
        message: 'AppConfigModel ${next.uuid} not found',
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<AppConfig>;
      final uuid = state.value.uuid;
      final value = await _readConfig(uuid);
      if (value != null) {
        final version = await _readVersion(uuid);
        final json = jsonDecode(value);
        final config = AppConfigModel.fromJson(json);
        await _delete(uuid);
        return ServiceResponse.ok(
          body: StorageState(
            value: config,
            isRemote: true,
            version: version + 1,
            status: StorageStatus.deleted,
          ),
        );
      }
      return ServiceResponse.notFound(
        message: "AppConfig not found: $uuid",
      );
    });
    return mock;
  }

  static Future<String> _readConfig(uuid) {
    return Storage.secure.read(
      key: 'app_config_$uuid',
    );
  }

  static Future<void> _delete(String uuid) async {
    await Storage.secure.delete(
      key: 'app_config_$uuid',
    );
    return Storage.secure.delete(
      key: 'app_config_${uuid}_version',
    );
  }

  static Future<void> _writeVersion(config) async {
    await Storage.secure.write(
      key: 'app_config_${config.uuid}_version',
      value: '${StateVersion.first}',
    );
  }

  static Future<void> _writeConfig(AppConfigModel config, String json) async {
    return await Storage.secure.write(
      key: 'app_config_${config.uuid}',
      value: json,
    );
  }

  static Future<StateVersion> _readVersion(uuid) async {
    return StateVersion(int.parse(await Storage.secure.read(
      key: 'app_config_${uuid}_version',
    )));
  }
}
