import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:SarSys/core/storage.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/repositories/repository.dart';
import 'package:SarSys/models/Incident.dart';

class IncidentRepository extends ConnectionAwareRepository<String, Incident> {
  IncidentRepository(
    this.service, {
    @required ConnectivityService connectivity,
  }) : super(
          connectivity: connectivity,
        );

  /// Incident service
  final IncidentService service;

  /// Get [Incident.uuid] from [state]
  @override
  String toKey(StorageState<Incident> state) {
    return state?.value?.uuid;
  }

  /// Load incidents
  Future<List<Incident>> load({bool force = true}) async {
    await prepare(
      force: force ?? false,
    );
    return _load();
  }

  /// Update [incident]
  Future<Incident> create(Incident incident) async {
    await prepare();
    return apply(
      StorageState.created(incident),
    );
  }

  /// Update [incident]
  Future<Incident> update(Incident incident) async {
    await prepare();
    return apply(
      StorageState.updated(incident),
    );
  }

  /// Delete [Incident] with given [uuid]
  Future<Incident> delete(String uuid) async {
    await prepare();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  /// GET ../incidents
  Future<List<Incident>> _load() async {
    if (connectivity.isOnline) {
      try {
        var response = await service.fetch();
        if (response.is200) {
          evict(
            retainKeys: response.body.map((incident) => incident.uuid),
          );
          response.body.forEach(
            (incident) => commit(
              StorageState.created(
                incident,
                remote: true,
              ),
            ),
          );
          return response.body;
        }
        throw IncidentServiceException(
          'Failed to load incidents',
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
  Future<Incident> onCreate(StorageState<Incident> state) async {
    var response = await service.create(state.value);
    if (response.is200) {
      return response.body;
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

class IncidentServiceException implements Exception {
  IncidentServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'IncidentServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
