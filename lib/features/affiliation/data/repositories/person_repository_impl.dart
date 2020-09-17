import 'dart:async';
import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/repository.dart';

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

  /// Create [Person] from json
  Person fromJson(Map<String, dynamic> json) => PersonModel.fromJson(json);

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
          isRemote: true,
        ),
      );
    });
    return length;
  }

  @override
  Future<Iterable<Person>> fetch({
    bool replace = false,
    Iterable<String> uuids,
    Completer<Iterable<Person>> onRemote,
  }) async {
    await prepare();
    return _fetch(
      uuids,
      replace: replace,
      onRemote: onRemote,
    );
  }

  Future<List<Person>> _fetch(
    Iterable<String> uuids, {
    bool replace = false,
    Completer<Iterable<Person>> onRemote,
  }) async {
    scheduleLoad(
      () async {
        final values = <Person>[];
        final errors = <ServiceResponse>[];
        for (var uuid in uuids) {
          // Do not attempt to load local values
          final state = getState(uuid);
          if (state == null || state?.shouldLoad == true) {
            final response = await service.get(uuid);
            if (response != null) {
              if (response.is200) {
                values.add(response.body);
              } else {
                errors.add(response);
              }
            }
          } else {
            values.add(state.value);
          }
        }
        if (errors.isNotEmpty) {
          return ServiceResponse<List<Person>>(
            body: values,
            error: errors,
            statusCode: values.isNotEmpty ? HttpStatus.partialContent : errors.first.statusCode,
            reasonPhrase: values.isNotEmpty ? 'Partial fetch failure' : 'Fetch failed',
          );
        }
        return ServiceResponse.ok<List<Person>>(
          body: values,
        );
      },
      onResult: onRemote,
      shouldEvict: replace,
    );
    return values;
  }

  @override
  Future<Iterable<Person>> onReset({Iterable<Person> previous = const []}) async => await _fetch(
        previous.map((a) => a.uuid).toList(),
        replace: true,
      );

  @override
  Future<Person> onCreate(StorageState<Person> state) async {
    var response = await service.create(state.value);
    if (response.is201) {
      return state.value;
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
    }
    throw PersonServiceException(
      'Failed to delete Person ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Person>> onResolve(StorageState<Person> state, ServiceResponse response) {
    return MergePersonStrategy(this)(
      state,
      response.conflict,
    );
  }
}

class MergePersonStrategy extends MergeStrategy<String, Person, PersonService> {
  MergePersonStrategy(PersonRepository repository) : super(repository);

  @override
  Future<StorageState<Person>> onExists(ConflictModel conflict, StorageState<Person> state) async {
    if (state.isCreated && conflict.isCode(PersonConflictCode.duplicate_user_id)) {
      // Notify change listeners that given person already exists
      return state.failed(conflict);
    }
    return super.onExists(conflict, state);
  }
}
