import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/settings/data/models/app_config_model.dart';
import 'package:SarSys/features/settings/data/services/app_config_service.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/domain/repositories/app_config_repository.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/services/connectivity_service.dart';

const int APP_CONFIG_VERSION = 1;

class AppConfigRepositoryImpl extends ConnectionAwareRepository<int, AppConfig, AppConfigService>
    implements AppConfigRepository {
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
  Future<AppConfig> local() async {
    beginTransaction();
    return apply(
      await _ensure(force: true),
    );
  }

  @override
  Future<AppConfig> init() async => apply(
        await _ensure(force: true),
      );

  @override
  Future<AppConfig> load() async {
    final state = await _ensure();
    if (state.isLocal) {
      return containsKey(version) ? schedule(state) : apply(state);
    }
    return _load();
  }

  @override
  Future<AppConfig> update(AppConfig config) async {
    checkState();
    return apply(
      StorageState.updated(config),
    );
  }

  @override
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

  Future<AppConfig> _load() async {
    final state = getState(version);
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch(state.value.uuid);
        if (response.is200) {
          put(
            StorageState.created(
              response.body,
              remote: true,
            ),
          );
          return response.body;
        } else if (response.is404) {
          return schedule(state.replace(state.value, remote: false));
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
  Future<Iterable<AppConfig>> onReset() async => [await _load()];

  @override
  Future<AppConfig> onCreate(StorageState<AppConfig> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw AppConfigServiceException(
      'Failed to delete AppConfig ${state.value}',
      response: response,
    );
  }
}
