import 'dart:async';

import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/services/fleet_map_service.dart';
import 'package:SarSys/features/affiliation/data/services/organisation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/repositories/organisation_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';

class OrganisationRepositoryImpl extends StatefulRepository<String, Organisation, OrganisationService>
    implements OrganisationRepository {
  OrganisationRepositoryImpl(
    OrganisationService service, {
    @required ConnectivityService connectivity,
  }) : super(
            service: service,
            connectivity: connectivity,
            onGet: (StorageState<Organisation> state) {
              return state.replace(
                state.value.copyWith(
                  fleetMap: FleetMapService().fetchFleetMap(state.value.prefix),
                ),
              );
            });

  /// Get [Operation.uuid] from [value]
  @override
  String toKey(Organisation value) {
    return value?.uuid;
  }

  /// Create [Organisation] from json
  Organisation fromJson(Map<String, dynamic> json) => OrganisationModel.fromJson(json);

  /// Load organisations
  Future<List<Organisation>> load({
    bool force = true,
    Completer<Iterable<Organisation>> onRemote,
  }) async {
    await prepare(
      force: force ?? false,
    );
    return _load(
      onRemote: onRemote,
    );
  }

  /// GET ../organisations
  Iterable<Organisation> _load({
    Completer<Iterable<Organisation>> onRemote,
  }) {
    return requestQueue.load(
      service.getList,
      shouldEvict: true,
      onResult: onRemote,
    );
  }

  @override
  Future<Iterable<Organisation>> onReset({Iterable<Organisation> previous = const []}) => Future.value(_load());

  @override
  Future<StorageState<Organisation>> onCreate(StorageState<Organisation> state) async {
    var response = await service.create(state);
    if (response.isOK) {
      return await _withFleetMap(response.body);
    }
    throw OrganisationServiceException(
      'Failed to create Organisation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Organisation>> onUpdate(StorageState<Organisation> state) async {
    var response = await service.update(state);
    if (response.isOK) {
      return await _withFleetMap(response.body);
    }
    throw OrganisationServiceException(
      'Failed to update Organisation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<StorageState<Organisation>> onDelete(StorageState<Organisation> state) async {
    var response = await service.delete(state);
    if (response.isOK) {
      return await _withFleetMap(response.body);
    }
    throw OrganisationServiceException(
      'Failed to delete Organisation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  StorageState<Organisation> _withFleetMap(StorageState<Organisation> state) {
    final fleetMap = FleetMapService().fetchFleetMap(
      state.value.prefix,
    );
    return fleetMap == null
        ? state
        : state.replace(
            (state.value as OrganisationModel).cloneWith(fleetMap),
          );
  }
}
