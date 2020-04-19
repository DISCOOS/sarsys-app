import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/storage.dart';
import 'package:SarSys/repositories/repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:SarSys/models/AppConfig.dart';

const int APP_CONFIG_VERSION = 1;

class AppConfigRepository extends ConnectionAwareRepository<int, AppConfig> {
  AppConfigRepository(
    this.version,
    this.service, {
    @required ConnectivityService connectivity,
    int compactWhen = 10,
  }) : super(
          connectivity: connectivity,
          compactWhen: compactWhen,
        );

  final int version;
  final AppConfigService service;

  /// Get current [AppConfig] instance
  AppConfig get config => this[version];

  /// POST ../configs
  Future<AppConfig> init() async => apply(
        await _ensure(force: true),
      );

  /// GET ../configs
  Future<AppConfig> load() async {
    final state = await _ensure();
    return state.isLocal ? apply(state) : _load();
  }

  /// PATCH ../configs/{configId}
  Future<AppConfig> update(AppConfig config) async {
    checkState();
    return apply(
      StorageState.changed(config),
    );
  }

  /// PUT ../configs/{configId}
  Future<AppConfig> delete() async {
    checkState();
    return apply(
      StorageState.deleted(config),
    );
  }

  /// Ensure that [config] exists
  Future<StorageState<AppConfig>> _ensure({bool force = false}) async {
    if (force || !isReady) {
      await prepare(force: force);
    }
    var current = getState(version);
    if (force || current == null) {
      current = await _local();
    } else if (current.value.version < version) {
      current = await _upgrade(current);
    }
    return current;
  }

  /// Initialize from local asset
  Future<StorageState<AppConfig>> _local() async {
    var asset = await rootBundle.loadString(service.asset);
    final newJson = jsonDecode(asset) as Map<String, dynamic>;
    var init = AppConfig.fromJson(newJson);
    final uuid = Uuid().v4();
    final udid = await FlutterUdid.udid;
    return StorageState.local(init.copyWith(
      uuid: uuid,
      udid: udid,
    ));
  }

  /// Upgrade current configuration
  Future<StorageState<AppConfig>> _upgrade(StorageState<AppConfig> state) async {
    var asset = await rootBundle.loadString(service.asset);
    final newJson = jsonDecode(asset) as Map<String, dynamic>;
    // Overwrite current configuration
    final next = state.value.toJson();
    next.addAll(newJson);
    return state.replace(AppConfig.fromJson(next));
  }

  Future<AppConfig> _load() async {
    final state = getState(version);
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch(state.value.uuid);
        if (response.is200) {
          await commit(
            StorageState.remote(
              response.body,
            ),
          );
          return response.body;
        }
        throw AppConfigServiceException(
          'Failed to load AppConfig $version:${state.value.uuid}',
          response: response,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return state.value;
  }

  @override
  int toKey(StorageState<AppConfig> state) => version;

  @override
  Future<AppConfig> onCreate(StorageState<AppConfig> state) async {
    var response = await service.create(state.value, version);
    if (response.is200) {
      return response.body;
    }
    throw AppConfigServiceException(
      'Failed to create AppConfig $config',
      response: response,
    );
  }

  Future<AppConfig> onUpdate(StorageState<AppConfig> state) async {
    var response = await service.update(config);
    if (response.is200) {
      return response.body;
    }
    throw AppConfigServiceException(
      'Failed to update AppConfig $config',
      response: response,
    );
  }

  Future<AppConfig> onDelete(StorageState<AppConfig> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return response.body;
    }
    throw AppConfigServiceException(
      'Failed to delete AppConfig $config',
      response: response,
    );
  }
}

class AppConfigServiceException implements Exception {
  AppConfigServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'AppConfigServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
