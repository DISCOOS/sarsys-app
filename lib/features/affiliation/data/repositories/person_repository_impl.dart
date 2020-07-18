import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/services/service.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/core/repository.dart';

class PersonRepositoryImpl extends ConnectionAwareRepository<String, Person, PersonService>
    implements PersonRepository {
  PersonRepositoryImpl(
    PersonService service, {
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Person> state) {
    return state?.value?.uuid;
  }

  /// Find Person with given userId
  Person findUser(String userId) =>
      userId == null ? null : find(where: (person) => person.userId == userId).firstOrNull;

  @override
  Iterable<Person> find({bool where(Person person)}) => isReady ? values.where(where) : [];

  @override
  Future<int> init({List<Person> persons}) async {
    await prepare(
      force: true,
    );
    (persons ?? []).forEach((element) {
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
  Future<Iterable<Person>> fetch({
    Iterable<String> uuids,
    bool force = true,
  }) async {
    await prepare(
      force: force ?? false,
    );
    return _fetch(uuids);
  }

  @override
  Future<Person> create(Person person) async {
    await prepare();
    return apply(
      StorageState.created(person),
    );
  }

  @override
  Future<Person> update(Person person) async {
    await prepare();
    return apply(
      StorageState.updated(person),
    );
  }

  @override
  Future<Person> delete(String uuid) async {
    await prepare();
    return apply(
      StorageState.deleted(get(uuid)),
    );
  }

  Future<List<Person>> _fetch(Iterable<String> uuids) async {
    if (connectivity.isOnline) {
      try {
        final values = <Person>[];
        final errors = <ServiceResponse>[];
        for (var uuid in uuids ?? []) {
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
          retainKeys: values.map((person) => person.uuid),
        );
        if (errors.isNotEmpty) {
          throw PersonServiceException(
            'Failed to load persons',
            response: ServiceResponse<List<Person>>(
              body: values,
              error: errors,
              reasonPhrase: 'Partial failure',
              statusCode: values.isNotEmpty ? HttpStatus.partialContent : errors.first.statusCode,
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
  Future<Iterable<Person>> onReset() async => await _fetch(values.map((a) => a.uuid).toList());

  @override
  Future<Person> onCreate(StorageState<Person> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
    } else if (response.is409) {
      return MergePersonStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw PersonServiceException(
      'Failed to create Person ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Person> onUpdate(StorageState<Person> state) async {
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
    throw PersonServiceException(
      'Failed to update Person ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<Person> onDelete(StorageState<Person> state) async {
    var response = await service.delete(state.value.uuid);
    if (response.is204) {
      return state.value;
    } else if (response.is409) {
      return MergeStrategy(this)(
        state,
        response.error as ConflictModel,
      );
    }
    throw PersonServiceException(
      'Failed to delete Person ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}

class MergePersonStrategy extends MergeStrategy<String, Person, PersonService> {
  MergePersonStrategy(PersonRepository repository) : super(repository);

  @override
  Future<Person> onExists(ConflictModel conflict, StorageState<Person> state) async {
    if (state.isCreated && conflict.isCode(PersonConflictCode.duplicate_user_id)) {
      // Notify change listeners
      // that given person exists
      final next = state.failed(conflict);
      repository.put(next);
      return next.value;
    }
    return super.onExists(conflict, state);
  }
}
