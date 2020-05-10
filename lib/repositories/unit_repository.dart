import 'dart:io';

import 'package:SarSys/services/service.dart';
import 'package:flutter/foundation.dart';
import 'package:json_patch/json_patch.dart';

import 'package:SarSys/core/storage.dart';
import 'package:SarSys/repositories/repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:SarSys/core/extensions.dart';

class UnitRepository extends ConnectionAwareRepository<String, Unit> {
  UnitRepository(
    this.service, {
    @required ConnectivityService connectivity,
    int compactWhen = 10,
  }) : super(
          connectivity: connectivity,
          compactWhen: compactWhen,
        );

  /// [UnitService] service
  final UnitService service;

  /// Get [Incident.uuid]
  String get iuuid => _iuuid;
  String _iuuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady => super.isReady && _iuuid != null;

  /// Get [Unit.uuid] from [state]
  @override
  String toKey(StorageState<Unit> state) {
    return state.value.uuid;
  }

  /// Ensure that box for given [Incident.uuid] is open
  Future<void> _ensure(String iuuid) async {
    if (isEmptyOrNull(iuuid)) {
      throw ArgumentError('Incident uuid can not be empty or null');
    }
    if (_iuuid != iuuid) {
      await prepare(
        force: true,
        postfix: iuuid,
      );
      _iuuid = iuuid;
    }
  }

  /// Get [Unit] count
  int count({
    List<UnitStatus> exclude: const [UnitStatus.Retired],
  }) =>
      exclude?.isNotEmpty == false
          ? length
          : values
              .where(
                (unit) => !exclude.contains(unit.status),
              )
              .length;

  /// Find unit from personnel
  Iterable<Unit> find(
    Personnel personnel, {
    List<UnitStatus> exclude: const [UnitStatus.Retired],
  }) =>
      values
          .where(
            (unit) => !exclude.contains(unit.status),
          )
          .where(
            (unit) => unit.personnels.any((p) => p.uuid == personnel.uuid),
          );

  /// Find and replace given [Personnel]
  Unit findAndReplace(Personnel personnel) {
    // TODO: Stable replace to keep order (plays better with json patch)
    final unit = find(personnel, exclude: []).firstOrNull;
    if (unit != null) {
      final next = _findAndRemove(
        unit,
        personnel,
      );
      return unit.cloneWith(
        personnel: next..add(personnel),
      );
    }
    return unit;
  }

  /// Find and remove given [Personnel]
  Unit findAndRemove(Personnel personnel) {
    final unit = find(personnel, exclude: []).firstOrNull;
    if (unit != null) {
      return unit.cloneWith(
        personnel: _findAndRemove(
          unit,
          personnel,
        ),
      );
    }
    return unit;
  }

  List<Personnel> _findAndRemove(
    Unit unit,
    Personnel personnel,
  ) =>
      unit.personnels.toList()
        ..removeWhere(
          (next) => next.uuid == personnel.uuid,
        );

  /// Get next available [Unit.number]
  int nextAvailableNumber(bool reuse) {
    if (reuse) {
      var prev = 0;
      final numbers = values
          .where(
            (unit) => UnitStatus.Retired != unit.status,
          )
          .map((unit) => unit.number)
          .toList();
      numbers.sort((n1, n2) => n1.compareTo(n2));
      final candidates = numbers.takeWhile((next) => (next - prev++) == 1).toList();
      return (candidates.length == 0 ? numbers.length : candidates.last) + 1;
    }
    return count(exclude: []) + 1;
  }

  /// GET ../units
  Future<List<Unit>> load(String iuuid) async {
    await _ensure(iuuid);
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch(iuuid);
        if (response.is200) {
          await clear();
          await Future.wait(response.body.map(
            (unit) => commit(
              StorageState.created(
                unit,
                remote: true,
              ),
            ),
          ));
          return response.body;
        }
        throw UnitServiceException(
          'Failed to fetch personnel for incident $iuuid',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return values;
  }

  /// Create [unit]
  Future<Unit> create(String iuuid, Unit unit) async {
    await _ensure(iuuid);
    return apply(
      StorageState.created(unit),
    );
  }

  /// Update [unit]
  Future<Unit> update(Unit unit) async {
    checkState();
    return apply(
      StorageState.updated(unit),
    );
  }

  /// PUT ../devices/{deviceId}
  Future<Unit> patch(Unit unit) async {
    checkState();
    final old = this[unit.uuid];
    final oldJson = old?.toJson() ?? {};
    final patches = JsonPatch.diff(oldJson, unit.toJson());
    final newJson = JsonPatch.apply(old, patches, strict: false);
    return update(
      Unit.fromJson(newJson..addAll({'uuid': unit.uuid})),
    );
  }

  /// Delete [Unit] with given [uuid]
  Future<Unit> delete(String uuid) async {
    checkState();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  /// Unload all devices for given [iuuid]
  Future<List<Unit>> unload() async {
    final devices = await clear();
    _iuuid = null;
    return devices;
  }

  @override
  Future<Unit> onCreate(StorageState<Unit> state) async {
    var response = await service.create(_iuuid, state.value);
    if (response.is200) {
      return response.body;
    }
    throw UnitServiceException(
      'Failed to create Unit ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Unit> onUpdate(StorageState<Unit> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    }
    throw UnitServiceException(
      'Failed to update Unit ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Unit> onDelete(StorageState<Unit> state) async {
    var response = await service.delete(state.value);
    if (response.is204) {
      return state.value;
    }
    throw UnitServiceException(
      'Failed to delete Unit ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}

class UnitServiceException implements Exception {
  UnitServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'UnitServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
