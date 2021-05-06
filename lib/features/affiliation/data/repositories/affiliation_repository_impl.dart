import 'dart:async';
import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/domain/stateful_merge_strategy.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
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
import 'package:SarSys/core/domain/stateful_repository.dart';

class AffiliationRepositoryImpl extends StatefulRepository<String, Affiliation, AffiliationService>
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
          // Keep person in sync with local copy
          onGet: (StorageState<Affiliation> state) {
            final value = state.value;
            final puuid = value.person.uuid;
            return state.replace(state.value.withPerson(persons.get(
              puuid,
            )));
          },
          onPut: (StorageState<Affiliation> state, bool isDeleted) {
            if (!isDeleted) {
              final affiliation = state.value;
              if (affiliation.isAffiliate) {
                final person = state.value.person;
                if (persons.containsKey(person.uuid)) {
                  // Patch locally only
                  persons.patch(
                    state.isRemote
                        ? person
                        : person.copyWith(
                            // Ensure temporary person if unorganized
                            temporary: affiliation.isUnorganized,
                          ),
                    isRemote: state.isRemote,
                    // TODO: Use actual version of person
                    // Until then, local version can diverge from remote
                    // version: person.version
                  );
                } else {
                  // Person is created during onboard,
                  // persist a-priori to keep state
                  // consistent locally
                  persons.put(
                    StorageState.created(
                      person,
                      // TODO: Use actual version of person
                      // Until then, local version can diverge from remote
                      StateVersion.first,
                      isRemote: state.isRemote,
                    ),
                  );
                }
              }
            }
          },
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
  String toKey(Affiliation value) {
    return value?.uuid;
  }

  /// Create [Affiliation] from json
  @override
  Affiliation fromJson(Map<String, dynamic> json) => AffiliationModel.fromJson(json);

  /// Find [Affiliation]s for affiliate with given [Person.uuid]
  @override
  Iterable<Affiliation> findPerson(String puuid) => find(where: (affiliation) => affiliation.person?.uuid == puuid);

  /// Find [Affiliation]s matching given query
  @override
  Iterable<Affiliation> find({bool where(Affiliation affiliation)}) => isReady ? values.where(where) : [];

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
        final next = states.values.where((state) => state.isLocal).toList();
        final response = await service.getListFromIds(uuids);
        if (response != null) {
          if (response.is200) {
            // Update persons repository
            response.body.map((s) => s.value).whereNotNull((a) => a.person).map(
                  (a) => _onPerson(a, isRemote: true),
                );
            next.addAll(response.body);
            return ServiceResponse.ok<List<StorageState<Affiliation>>>(
              body: next,
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
        final response = await service.search(
          filter,
          offset: offset,
          limit: limit,
        );
        if (response.is200) {
          response.body.forEach((affiliation) {
            put(affiliation);
            _onPerson(
              affiliation.value,
              isRemote: true,
            );
          });
          return response.body.map((s) => s.value);
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

  Affiliation _onPerson(
    Affiliation affiliation, {
    @required bool isRemote,
  }) {
    assert(
      affiliation.person != null,
      "Person can not be null",
    );
    // Ensure userId is set
    final next = _ensureUserId(affiliation);
    persons.patch(
      next,
      isRemote: isRemote,
    );
    return affiliation;
  }

  Person _ensureUserId(Affiliation affiliation) {
    if (affiliation.person.userId == null) {
      final person = persons[affiliation.person.uuid];
      if (person != null) {
        return person;
      }
    }
    return affiliation.person;
  }

  @override
  Future<StorageState<Affiliation>> onCreate(StorageState<Affiliation> state) async {
    final response = await service.create(state);
    if (response.isOK) {
      return response.body;
    }
    throw AffiliationServiceException(
      'Failed to create Affiliation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Affiliation>> onUpdate(StorageState<Affiliation> state) async {
    var response = await service.update(state);
    if (response.is200) {
      return response.body;
    } else if (response.is204) {
      return state;
    }
    throw AffiliationServiceException(
      'Failed to update Affiliation ${state.value}@${state.version}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Affiliation>> onDelete(StorageState<Affiliation> state) async {
    var response = await service.delete(state);
    if (response.is204) {
      return state;
    }
    throw AffiliationServiceException(
      'Failed to delete Affiliation ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Iterable<Affiliation>> onReset({Iterable<Affiliation> previous}) => _fetch(
        (previous ?? values).map((a) => a.uuid).toList(),
        replace: true,
      );

  @override
  Future<StorageState<Affiliation>> onResolve(StorageState<Affiliation> state, ServiceResponse response) {
    return MergeAffiliationStrategy(this)(
      state,
      response.conflict,
    );
  }
}

class MergeAffiliationStrategy extends StatefulMergeStrategy<String, Affiliation, AffiliationService> {
  MergeAffiliationStrategy(AffiliationRepository repository) : super(repository);

  @override
  AffiliationRepository get repository => super.repository;
  PersonRepository get persons => repository.persons;

  @override
  Future<StorageState<Affiliation>> onExists(ConflictModel conflict, StorageState<Affiliation> state) async {
    switch (conflict.code) {
      case 'duplicate_user_id':
      case 'duplicate_affiliations':
        var value = state.value;

        if (conflict.mine.isNotEmpty) {
          // Duplicates was found, reuse first duplicate
          value = AffiliationModel.fromJson(
            conflict.mine.first,
          );

          // Delete duplicate
          repository.remove(state.value);

          // Patch with existing state
          repository.patch(
            value,
            isRemote: true,
          );
        }

        if (conflict.isCode('duplicate_user_id')) {
          // Replace duplicate person with existing person
          repository.apply(
            state.value.copyWith(
              person: PersonModel.fromJson(conflict.base),
            ),
          );
          // Delete duplicate person
          persons.remove(
            state.value.person,
          );
        }

        return repository.getState(
          repository.toKey(value),
        );
    }
    return super.onExists(conflict, state);
  }
}
