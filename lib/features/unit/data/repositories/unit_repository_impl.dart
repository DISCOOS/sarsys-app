

import 'dart:async';

import 'package:SarSys/core/domain/stateful_catchup_mixins.dart';

import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/features/unit/domain/repositories/unit_repository.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/data/services/unit_service.dart';
import 'package:SarSys/core/data/services/service.dart';

class UnitRepositoryImpl extends StatefulRepository<String, Unit, UnitService>
    with StatefulCatchup<Unit, UnitService>
    implements UnitRepository {
  UnitRepositoryImpl(
    UnitService service, {
    required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        ) {
    // Handle messages
    // pushed from backend.
    catchupTo(service.messages);
  }

  /// Get [Operation.uuid]
  String? get ouuid => _ouuid;
  String? _ouuid;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady => super.isReady && _ouuid != null;

  /// Get [Unit.uuid] from [value]
  @override
  String toKey(Unit value) {
    return value.uuid;
  }

  /// Create [Unit] from json
  Unit fromJson(Map<String, dynamic>? json) => UnitModel.fromJson(json!);

  /// Open repository for given [Operation.uuid] is open
  Future<Iterable<Unit?>> open(String? ouuid) async {
    if (isEmptyOrNull(ouuid)) {
      throw ArgumentError('Operation uuid can not be empty or null');
    }
    if (_ouuid != ouuid) {
      _ouuid = ouuid;
      await prepare(
        force: true,
        postfix: ouuid,
      );
    }
    return values;
  }

  /// Get [Unit] count
  int count({
    UnitType? type,
    List<UnitStatus> exclude: const [UnitStatus.retired],
  }) =>
      exclude.isNotEmpty == false
          ? length
          : values
              .where(
                (unit) => type == null || type == unit.type,
              )
              .where(
                (unit) => !exclude.contains(unit.status),
              )
              .length;

  /// Find unit from personnel
  Iterable<Unit?> findPersonnel(
    String? puuid, {
    List<UnitStatus> exclude: const [UnitStatus.retired],
  }) =>
      values
          .where(
            (unit) => !exclude.contains(unit.status),
          )
          .where(
            (unit) => unit.personnels.any((uuid) => puuid == uuid),
          );

  /// Get next available [Unit.number]
  int nextAvailableNumber(UnitType type, {bool reuse = true}) {
    if (reuse) {
      var prev = 0;
      final numbers = values
          .where(
            (unit) => UnitStatus.retired != unit.status,
          )
          .where(
            (unit) => type == unit.type,
          )
          .map((unit) => unit.number)
          .toList();
      numbers.sort((n1, n2) => n1!.compareTo(n2!));
      final candidates = numbers.takeWhile((next) => (next! - prev++) == 1).toList();
      return (candidates.length == 0 ? numbers.length : candidates.last)! + 1;
    }
    return count(exclude: [], type: type) + 1;
  }

  @override
  Future<List<Unit?>> load(
    String? ouuid, {
    Completer<Iterable<Unit>>? onRemote,
  }) async {
    await open(ouuid);
    return requestQueue!.load(
      () => service.getListFromId(ouuid),
      shouldEvict: true,
      onResult: onRemote,
    ) as FutureOr<List<Unit?>>;
  }

  /// Unload all devices for given [ouuid]
  Future<List<Unit>> close() async {
    _ouuid = null;
    return super.close();
  }

  @override
  Future<Iterable<Unit>> onReset({Iterable<Unit>? previous}) => _ouuid != null ? load(_ouuid) as Future<Iterable<Unit>> : Future.value(previous);

  @override
  Future<StorageState<Unit>> onCreate(StorageState<Unit> state) async {
    assert(state.value.operation!.uuid == _ouuid);
    var response = await service.create(state);
    if (response.isOK) {
      return response.body!;
    }

    throw UnitServiceException(
      'Failed to create Unit ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Unit>?> onUpdate(StorageState<Unit> state) async {
    var response = await service.update(state);
    if (response.isOK) {
      return response.body;
    }

    throw UnitServiceException(
      'Failed to update Unit ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Unit>?> onDelete(StorageState<Unit> state) async {
    ServiceResponse<StorageState<Unit>> response = await service.delete(state);
    if (response.isOK) {
      return response.body;
    }
    throw UnitServiceException(
      'Failed to delete Unit ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}
