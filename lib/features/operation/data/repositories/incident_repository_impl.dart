

import 'dart:async';

import 'package:SarSys/core/domain/stateful_catchup_mixins.dart';
import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/domain/repositories/incident_repository.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/features/operation/data/services/incident_service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';

class IncidentRepositoryImpl extends StatefulRepository<String, Incident, IncidentService>
    with StatefulCatchup<Incident, IncidentService>
    implements IncidentRepository {
  IncidentRepositoryImpl(
    IncidentService service, {
    required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        ) {
    // Handle messages
    // pushed from backend.
    catchupTo(service.messages);
  }

  /// Get [Operation.uuid] from [value]
  @override
  String toKey(Incident? value) {
    return value!.uuid;
  }

  /// Create [Incident] from json
  Incident fromJson(Map<String, dynamic>? json) => IncidentModel.fromJson(json!);

  /// Load incidents
  Future<List<Incident?>> load({
    bool force = true,
    Completer<Iterable<Incident>>? onRemote,
  }) async {
    await prepare(
      force: force,
    );
    return _load(
      onRemote: onRemote,
    ) as FutureOr<List<Incident?>>;
  }

  /// GET ../incidents
  Iterable<Incident> _load({
    Completer<Iterable<Incident>>? onRemote,
  }) {
    return requestQueue!.load(
      service.getList,
      shouldEvict: true,
      onResult: onRemote,
    );
  }

  @override
  Future<Iterable<Incident>> onReset({Iterable<Incident?>? previous}) => Future.value(_load());

  @override
  Future<StorageState<Incident>> onCreate(StorageState<Incident> state) async {
    var response = await service.create(state);
    if (response.isOK) {
      return response.body!;
    }
    throw IncidentServiceException(
      'Failed to create Incident ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Incident>?> onUpdate(StorageState<Incident> state) async {
    var response = await service.update(state);
    if (response.isOK) {
      return response.body;
    }
    throw IncidentServiceException(
      'Failed to update Incident ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Incident>?> onDelete(StorageState<Incident> state) async {
    var response = await service.delete(state);
    if (response.isOK) {
      return response.body;
    }
    throw IncidentServiceException(
      'Failed to delete Incident ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}
