import 'dart:async';

import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/services/division_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/repositories/division_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';

class DivisionRepositoryImpl extends StatefulRepository<String, Division, DivisionService>
    implements DivisionRepository {
  DivisionRepositoryImpl(
    DivisionService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Division.uuid] from [value]
  @override
  String toKey(Division value) {
    return value?.uuid;
  }

  /// Create [Division] from json
  Division fromJson(Map<String, dynamic> json) => DivisionModel.fromJson(json);

  /// Load divisions
  @override
  Future<List<Division>> load({
    bool force = true,
    Completer<Iterable<Division>> onRemote,
  }) async {
    await prepare(
      force: force ?? false,
    );
    return _load(
      onRemote: onRemote,
    );
  }

  /// GET ../divisions
  Iterable<Division> _load({
    Completer<Iterable<Division>> onRemote,
  }) {
    return requestQueue.load(
      service.getList,
      shouldEvict: true,
      onResult: onRemote,
    );
  }

  @override
  Future<Iterable<Division>> onReset({Iterable<Division> previous = const []}) => Future.value(_load());

  @override
  Future<StorageState<Division>> onCreate(StorageState<Division> state) async {
    var response = await service.create(state);
    if (response.isOK) {
      return response.body;
    }
    throw DivisionServiceException(
      'Failed to create Division ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Division>> onUpdate(StorageState<Division> state) async {
    var response = await service.update(state);
    if (response.isOK) {
      return response.body;
    }
    throw DivisionServiceException(
      'Failed to update Division ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Division>> onDelete(StorageState<Division> state) async {
    var response = await service.delete(state);
    if (response.isOK) {
      return response.body;
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
