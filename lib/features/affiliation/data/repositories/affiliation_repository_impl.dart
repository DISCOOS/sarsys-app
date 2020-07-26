import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/repositories/affiliation_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/department_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/division_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/organisation_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/repository.dart';

class AffiliationRepositoryImpl extends ConnectionAwareRepository<String, Affiliation, AffiliationService>
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

  @override
  Future<int> init({List<Affiliation> affiliations}) async {
    await prepare();
    (affiliations ?? []).forEach((element) {
      put(
        StorageState.created(
          element,
          remote: true,
        ),
      );
    });
    return length;
  }

  @override
  Future<List<Affiliation>> fetch(
    List<String> uuids, {
    bool replace = false,
  }) async {
    await prepare();
    return _fetch(
      uuids,
      replace: replace,
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

  @override
  Future<Affiliation> create(Affiliation affiliation) async {
    await prepare();
    return apply(
      StorageState.created(affiliation),
    );
  }

  @override
  Future<Affiliation> update(Affiliation affiliation) async {
    await prepare();
    return apply(
      StorageState.updated(affiliation),
    );
  }

  @override
  Future<Affiliation> delete(String uuid) async {
    await prepare();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  Future<List<Affiliation>> _fetch(
    List<String> uuids, {
    bool replace = false,
  }) async {
    if (connectivity.isOnline) {
      try {
        final values = <Affiliation>[];
        final errors = <ServiceResponse>[];
        for (var uuid in uuids) {
          // Do not attempt to load local values
          final state = getState(uuid);
          if (state == null || state?.shouldLoad == true) {
            final response = await service.get(uuid);
            if (response.is200) {
              put(
                StorageState.created(
                  response.body,
                  remote: true,
                ),
              );
              values.add(response.body);
            } else {
              errors.add(response);
            }
          } else {
            values.add(state.value);
          }
        }
        if (replace) {
          evict(
            retainKeys: values.map((affiliation) => affiliation.uuid),
          );
        }
        if (errors.isNotEmpty) {
          throw AffiliationServiceException(
            'Failed to load affiliations',
            response: ServiceResponse<List<Affiliation>>(
              body: values,
              error: errors,
              statusCode: values.isNotEmpty ? HttpStatus.partialContent : errors.first.statusCode,
              reasonPhrase: values.isNotEmpty ? 'Partial fetch failure' : 'Fetch failed',
            ),
            stackTrace: StackTrace.current,
          );
        }
        return values;
      } on SocketException {
        // Assume offline
      }
    }
    return values;
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
          response.body.forEach((element) {
            put(
              StorageState.created(
                element,
                remote: true,
              ),
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

  @override
  Future<Iterable<Affiliation>> onReset() async => await _fetch(
        values.map((a) => a.uuid).toList(),
        replace: true,
      );

  @override
  Future<Affiliation> onCreate(StorageState<Affiliation> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
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