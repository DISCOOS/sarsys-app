import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/settings/data/models/app_config_model.dart';
import 'package:SarSys/features/settings/data/services/app_config_service.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/domain/repositories/app_config_repository.dart';
import 'package:SarSys/core/domain/box_repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';

const int APP_CONFIG_VERSION = 1;

class AppConfigRepositoryImpl extends BoxRepository<int, AppConfig, AppConfigService> implements AppConfigRepository {
  AppConfigRepositoryImpl(
    this.version, {
    @required AppConfigService service,
    @required this.assets,
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  final int version;
  final String assets;

  /// Get current [AppConfig] instance
  AppConfig get config => this[version];

  /// Get current state
  StorageState<AppConfig> get state => getState(version);

  @override
  int toKey(StorageState<AppConfig> state) => version;

  /// Create [AppConfig] from json
  AppConfig fromJson(Map<String, dynamic> json) => AppConfigModel.fromJson(json);

  @override
  Future<AppConfig> local() async {
    beginTransaction();
    return push(
      await _open(force: true),
    );
  }

  @override
  Future<AppConfig> init({
    Completer<Iterable<AppConfig>> onRemote,
  }) async {
    final onPush = Completer<AppConfig>();
    onPush.future.then(
      (value) => onRemote.complete([value]),
      onError: onRemote.completeError,
    );
    return push(
      await _open(force: true),
      onResult: onPush,
    );
  }

  @override
  Future<AppConfig> load({
    Completer<Iterable<AppConfig>> onRemote,
  }) async {
    final state = await _open();
    if (state.isLocal) {
      final onPush = Completer<AppConfig>();
      onPush.future.then(
        (value) => onRemote.complete([value]),
        onError: onRemote.completeError,
      );
      return containsKey(version)
          ? requestQueue.push(
              toKey(state),
              onResult: onPush,
            )
          : push(
              state,
              onResult: onPush,
            );
    }
    return _load(
      onRemote: onRemote,
    );
  }

  /// Ensure that [config] exists
  Future<StorageState<AppConfig>> _open({bool force = false}) async {
    if (force || !isReady) {
      await prepare(force: force);
    }
    var current = getState(version);
    if (force || current == null) {
      current = await _initFromAssets(current);
    } else if ((current.value.version ?? 0) < version) {
      current = await _upgrade(current);
    }
    return current;
  }

  /// Initialize from assets
  Future<StorageState<AppConfig>> _initFromAssets(StorageState<AppConfig> current) async {
    var assetData = await rootBundle.loadString(assets);
    final newJson = jsonDecode(assetData) as Map<String, dynamic>;
    var init = AppConfigModel.fromJson(newJson);
    final udid = await FlutterUdid.consistentUdid;
    final next = init.copyWith(
      uuid: current?.value?.uuid ?? Uuid().v4(),
      udid: udid,
      version: version,
    );
    return current?.isRemote == true
        ? StorageState.updated(
            next,
          )
        : StorageState.created(
            next,
          );
  }

  /// Upgrade current configuration
  Future<StorageState<AppConfig>> _upgrade(StorageState<AppConfig> state) async {
    var assetData = await rootBundle.loadString(assets);
    final newJson = jsonDecode(assetData) as Map<String, dynamic>;
    // Overwrite current configuration
    final next = state.value.toJson();
    next.addAll(newJson);
    return state.replace(AppConfigModel.fromJson(next
      ..addAll({
        'version': version,
      })));
  }

  Future<AppConfig> _load({
    Completer<Iterable<AppConfig>> onRemote,
  }) async {
    final state = getState(version);
    requestQueue.load(
      () async {
        final response = await service.fetch(state.value.uuid);
        return response?.copyWith<Iterable<AppConfig>>(
          body: [response.body],
        );
      },
      shouldEvict: true,
      onResult: onRemote,
    );
    return state.value;
  }

  @override
  Future<Iterable<AppConfig>> onReset({Iterable<AppConfig> previous}) async => [await _load()];

  @override
  Future<AppConfig> onCreate(StorageState<AppConfig> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    }
    throw AppConfigServiceException(
      'Failed to create AppConfig ${state.value}',
      response: response,
    );
  }

  Future<AppConfig> onUpdate(StorageState<AppConfig> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    } else if (response.is204) {
      return state.value;
    } else if (response.is404) {
      return onCreate(state);
    }
    throw AppConfigServiceException(
      'Failed to update AppConfig ${state.value}',
      response: response,
    );
  }

  Future<AppConfig> onDelete(StorageState<AppConfig> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    }
    throw AppConfigServiceException(
      'Failed to delete AppConfig ${state.value}',
      response: response,
    );
  }
}
