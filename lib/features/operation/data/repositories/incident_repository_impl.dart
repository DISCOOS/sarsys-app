import 'dart:async';

import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/domain/repositories/incident_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/features/operation/data/services/incident_service.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';

class IncidentRepositoryImpl extends ConnectionAwareRepository<String, Incident, IncidentService>
    implements IncidentRepository {
  IncidentRepositoryImpl(
    IncidentService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Incident> state) {
    return state?.value?.uuid;
  }

  /// Create [Incident] from json
  Incident fromJson(Map<String, dynamic> json) => IncidentModel.fromJson(json);

  /// Load incidents
  Future<List<Incident>> load({
    bool force = true,
    Completer<Iterable<Incident>> onRemote,
  }) async {
    await prepare(
      force: force ?? false,
    );
    return _load(
      onRemote: onRemote,
    );
  }

  /// GET ../incidents
  Future<List<Incident>> _load({
    Completer<Iterable<Incident>> onRemote,
  }) async {
    scheduleLoad(
      service.fetchAll,
      shouldEvict: true,
      onResult: onRemote,
    );
    return values;
  }

  @override
  Future<Iterable<Incident>> onReset({Iterable<Incident> previous}) async => await _load();

  @override
  Future<Incident> onCreate(StorageState<Incident> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    }
    throw IncidentServiceException(
      'Failed to create Incident ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Incident> onUpdate(StorageState<Incident> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    } else if (response.is204) {
      return state.value;
    }
    throw IncidentServiceException(
      'Failed to update Incident ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Incident> onDelete(StorageState<Incident> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    }
    throw IncidentServiceException(
      'Failed to delete Incident ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}
