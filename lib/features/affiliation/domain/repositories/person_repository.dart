import 'dart:async';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';

abstract class PersonRepository implements StatefulRepository<String, Person, PersonService> {
  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Person> state) {
    return state?.value?.uuid;
  }

  /// Find Person with given userId
  Person findUser(String userId);

  /// Find persons matching given query
  Iterable<Person> find({bool where(Person person)});

  /// Init from local storage, overwrite states
  /// with given persons if given. Returns
  /// number of states after initialisation
  Future<int> init({List<Person> persons});

  /// Load given persons
  Future<Iterable<Person>> fetch({
    bool replace = false,
    Iterable<String> uuids,
    Completer<Iterable<Person>> onRemote,
  });

  /// Check if state transitioned into a
  /// [PersonConflictCode.duplicate_user_id]
  /// conflict
  static bool isDuplicateUser(StorageTransition<Person> transition) =>
      transition.isConflict &&
      transition.conflict.isCode(
        PersonConflictCode.duplicate_user_id,
      );
}

class PersonServiceException extends ServiceException {
  PersonServiceException(
    Object error, {
    ServiceResponse response,
    StackTrace stackTrace,
  }) : super(error, response: response, stackTrace: stackTrace);
}
