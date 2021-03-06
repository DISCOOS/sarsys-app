import 'dart:async';
import 'dart:io';

import 'package:SarSys/core/domain/stateful_catchup_mixins.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';

class PersonRepositoryImpl extends StatefulRepository<String, Person, PersonService>
    with StatefulCatchup<Person, PersonService>
    implements PersonRepository {
  PersonRepositoryImpl(
    PersonService service, {
    @required ConnectivityService connectivity,
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
  String toKey(Person value) {
    return value?.uuid;
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
    (persons ?? []).forEach((person) => replace(
          person,
          isRemote: true,
        ));
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

  Iterable<Person> _fetch(
    Iterable<String> uuids, {
    bool replace = false,
    Completer<Iterable<Person>> onRemote,
  }) {
    return requestQueue.load(
      () async {
        final values = <StorageState<Person>>[];
        final errors = <ServiceResponse>[];
        for (var uuid in uuids) {
          // Do not attempt to load local values
          final state = getState(uuid);
          if (state == null || state?.shouldLoad == true) {
            final response = await service.getFromId(uuid);
            if (response != null) {
              if (response.is200) {
                values.add(response.body);
              } else {
                errors.add(response);
              }
            }
          } else {
            values.add(state);
          }
        }
        if (errors.isNotEmpty) {
          return ServiceResponse(
            body: values,
            error: errors,
            statusCode: values.isNotEmpty ? HttpStatus.partialContent : errors.first.statusCode,
            reasonPhrase: values.isNotEmpty ? 'Partial fetch failure' : 'Fetch failed',
          );
        }
        return ServiceResponse.ok(
          body: values,
        );
      },
      onResult: onRemote,
      shouldEvict: replace,
    );
  }

  @override
  Future<Iterable<Person>> onReset({Iterable<Person> previous = const []}) => Future.value(_fetch(
        previous.map((a) => a.uuid).toList(),
        replace: true,
      ));

  @override
  Future<StorageState<Person>> onCreate(StorageState<Person> state) async {
    var response = await service.create(state);
    if (response.isOK) {
      return response.body;
    }
    throw PersonServiceException(
      'Failed to create Person ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Person>> onUpdate(StorageState<Person> state) async {
    var response = await service.update(state);
    if (response.isOK) {
      return response.body;
    }
    throw PersonServiceException(
      'Failed to update Person ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Person>> onDelete(StorageState<Person> state) async {
    var response = await service.delete(state);
    if (response.isOK) {
      return response.body;
    }
    throw PersonServiceException(
      'Failed to delete Person ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }
}
