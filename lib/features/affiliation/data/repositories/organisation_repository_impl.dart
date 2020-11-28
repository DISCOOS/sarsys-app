import 'dart:async';

import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/services/fleet_map_service.dart';
import 'package:SarSys/features/affiliation/data/services/organisation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/repositories/organisation_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/box_repository.dart';

class OrganisationRepositoryImpl extends BoxRepository<String, Organisation, OrganisationService>
    implements OrganisationRepository {
  OrganisationRepositoryImpl(
    OrganisationService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Organisation> state) {
    return state?.value?.uuid;
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
  Future<Organisation> onCreate(StorageState<Organisation> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return await _withFleetMap(state.value);
    }
    throw OrganisationServiceException(
      'Failed to create Organisation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Organisation> onUpdate(StorageState<Organisation> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return _withFleetMap(response.body);
    } else if (response.is204) {
      return _withFleetMap(state.value);
    }
    throw OrganisationServiceException(
      'Failed to update Organisation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Organisation> onDelete(StorageState<Organisation> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return _withFleetMap(state.value);
    }
    throw OrganisationServiceException(
      'Failed to delete Organisation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  Future<Organisation> _withFleetMap(Organisation organisation) async {
    final fleetMap = await FleetMapService().fetchFleetMap(
      organisation.prefix,
    );
    return fleetMap == null ? organisation : (organisation as OrganisationModel).cloneWith(fleetMap);
  }
}
