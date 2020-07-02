import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/affiliation/data/services/division_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/repositories/division_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/core/repository.dart';

class DivisionRepositoryImpl extends ConnectionAwareRepository<String, Division, DivisionService>
    implements DivisionRepository {
  DivisionRepositoryImpl(
    DivisionService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Division.uuid] from [state]
  @override
  String toKey(StorageState<Division> state) {
    return state?.value?.uuid;
  }

  /// Load divisions
  Future<List<Division>> load({bool force = true}) async {
    await prepare(
      force: force ?? false,
    );
    return _load();
  }

  /// Update [division]
  Future<Division> create(Division division) async {
    await prepare();
    return apply(
      StorageState.created(division),
    );
  }

  /// Update [division]
  Future<Division> update(Division division) async {
    await prepare();
    return apply(
      StorageState.updated(division),
    );
  }

  /// Delete [Division] with given [uuid]
  Future<Division> delete(String uuid) async {
    await prepare();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  /// GET ../divisions
  Future<List<Division>> _load() async {
    if (connectivity.isOnline) {
      try {
        var response = await service.fetchAll();
        if (response.is200) {
          evict(
            retainKeys: response.body.map((division) => division.uuid),
          );
          response.body.forEach(
            (division) => put(
              StorageState.created(
                division,
                remote: true,
              ),
            ),
          );
          return response.body;
        }
        throw DivisionServiceException(
          'Failed to load divisions',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return values;
  }

  @override
  Future<Iterable<Division>> onReset() async => await _load();

  @override
  Future<Division> onCreate(StorageState<Division> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw DivisionServiceException(
      'Failed to create Division ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Division> onUpdate(StorageState<Division> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    } else if (response.is204) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw DivisionServiceException(
      'Failed to update Division ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Division> onDelete(StorageState<Division> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw DivisionServiceException(
      'Failed to delete Division ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}

class DivisionServiceException implements Exception {
  DivisionServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'DivisionServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
