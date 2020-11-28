import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/domain/repositories/affiliation_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/department_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/division_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/organisation_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/core/data/services/service.dart';

import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/box_repository.dart';

class AffiliationRepositoryImpl extends BoxRepository<String, Affiliation, AffiliationService>
    implements AffiliationRepository {
  AffiliationRepositoryImpl(
    AffiliationService service, {
    @required this.divs,
    @required this.deps,
    @required this.orgs,
    @required this.persons,
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
          dependencies: [persons, orgs, divs, deps],
        );

  /// [Organisation] repository
  @override
  final OrganisationRepository orgs;

  /// [Division] repository
  @override
  final DivisionRepository divs;

  /// [Department] repository
  @override
  final DepartmentRepository deps;

  /// [Person] repository
  @override
  final PersonRepository persons;

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Affiliation> state) {
    return state?.value?.uuid;
  }

  /// Create [Affiliation] from json
  Affiliation fromJson(Map<String, dynamic> json) => AffiliationModel.fromJson(json);

  @override
  Future<List<Affiliation>> load({
    bool force = true,
    Completer<Iterable<Affiliation>> onRemote,
  }) async {
    await prepare(
      force: force,
    );
    return _fetch(
      keys,
      replace: true,
      onRemote: onRemote,
    );
  }

  @override
  Future<List<Affiliation>> fetch(
    List<String> uuids, {
    bool replace = false,
    Completer<Iterable<Affiliation>> onRemote,
  }) async {
    await prepare();
    return _fetch(
      uuids,
      replace: replace,
      onRemote: onRemote,
    );
  }

  @override
  Future<List<Affiliation>> search(
    String filter, {
    int limit,
    int offset,
  }) async {
    await prepare();
    return _search(
      filter,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Affiliation>> _fetch(
    List<String> uuids, {
    bool replace = false,
    Completer<Iterable<Affiliation>> onRemote,
  }) async {
    // Replace current if not executed yet
    requestQueue.load(
      () async {
        // Keep local values! Will be
        // overwritten by remote values
        // if exists. If replace = true,
        // this will remove local values
        // with remote state.
        final next = states.values.where((state) => state.isLocal).map((state) => state.value).toList();
        final response = await service.getAll(uuids);
        if (response != null) {
          if (response.is200) {
            next.addAll(response.body);
            return ServiceResponse.ok<List<Affiliation>>(
              body: values
                  .whereNotNull((a) => a.person)
                  // Update persons repository
                  .map((a) => _toPerson(a, isRemote: true))
                  .toList(),
            );
          }
        }
        return response;
      },
      onResult: onRemote,
      shouldEvict: replace,
    );
    return uuids.map((uuid) => get(uuid)).whereNotNull().toList();
  }

  Future<List<Affiliation>> _search(
    String filter, {
    int limit,
    int offset,
  }) async {
    if (connectivity.isOnline) {
      try {
        final response = await service.search(filter, offset, limit);
        if (response.is200) {
          response.body.forEach((affiliation) {
            put(
              StorageState.created(
                affiliation,
                isRemote: true,
              ),
            );
            _toPerson(
              affiliation,
              isRemote: true,
            );
          });
          return response.body;
        }
        throw AffiliationServiceException(
          'Failed to search for affiliation matching $filter',
          response: response,
          stackTrace: StackTrace.current,
        );
      } on SocketException {
        // Assume offline
      }
    }
    return values;
  }

  Affiliation _toPerson(
    Affiliation affiliation, {
    @required bool isRemote,
  }) {
    assert(
      affiliation.person != null,
      "Person can not be null",
    );
    persons.replace(
      affiliation.person,
      isRemote: isRemote,
    );
    return affiliation;
  }

  @override
  Future<Iterable<Affiliation>> onReset({Iterable<Affiliation> previous}) => _fetch(
        (previous ?? values).map((a) => a.uuid).toList(),
        replace: true,
      );

  @override
  Future<Affiliation> onCreate(StorageState<Affiliation> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    }
    throw AffiliationServiceException(
      'Failed to create Affiliation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Affiliation> onUpdate(StorageState<Affiliation> state) async {
    var response = await service.update(state.value);
    if (response.is200) {
      return response.body;
    } else if (response.is204) {
      return state.value;
    }
    throw AffiliationServiceException(
      'Failed to update Affiliation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Affiliation> onDelete(StorageState<Affiliation> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    }
    throw AffiliationServiceException(
      'Failed to delete Affiliation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  /// Find [Affiliation]s for affiliate with given [Person.uuid]
  Iterable<Affiliation> findPerson(String puuid) => find(where: (affiliation) => affiliation.person?.uuid == puuid);

  /// Find [Affiliation]s matching given query
  Iterable<Affiliation> find({bool where(Affiliation affiliation)}) => isReady ? values.where(where) : [];
}
