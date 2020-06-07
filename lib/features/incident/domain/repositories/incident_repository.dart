import 'package:SarSys/core/storage.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/features/incident/data/services/incident_service.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';

abstract class IncidentRepository implements ConnectionAwareRepository<String, Incident> {
  /// Incident service
  IncidentService get service;

  /// Get [Incident.uuid] from [state]
  @override
  String toKey(StorageState<Incident> state) {
    return state?.value?.uuid;
  }

  /// Load incidents
  Future<List<Incident>> load({bool force = true});

  /// Update [incident]
  Future<Incident> create(Incident incident);

  /// Update [incident]
  Future<Incident> update(Incident incident);

  /// Delete [Incident] with given [uuid]
  Future<Incident> delete(String uuid);
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
