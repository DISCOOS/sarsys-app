import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/repositories/affiliation_repository.dart';
import 'package:SarSys/services/service.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/core/repository.dart';

class AffiliationRepositoryImpl extends ConnectionAwareRepository<String, Affiliation, AffiliationService>
    implements AffiliationRepository {
  AffiliationRepositoryImpl(
    AffiliationService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

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
  Future<List<Affiliation>> fetch(List<String> uuids, {bool force = true}) async {
    await prepare(
      force: force ?? false,
    );
    return _fetch(uuids);
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

  Future<List<Affiliation>> _fetch(List<String> uuids) async {
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
        evict(
          retainKeys: values.map((affiliation) => affiliation.uuid),
        );
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

  @override
  Future<Iterable<Affiliation>> onReset() async => await _fetch(values.map((a) => a.uuid).toList());

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
