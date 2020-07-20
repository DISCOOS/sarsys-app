import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/core/repository.dart';

abstract class PersonRepository implements ConnectionAwareRepository<String, Person, PersonService> {
  /// Get [Operation.uuid] from [state]
  @override
  String toKey(StorageState<Person> state) {
    return state?.value?.uuid;
  }

  /// Find Person with given userId
  Person findUser(String userId);

  /// Find persons matching given query
  Iterable<Person> find({bool where(Person person)});

  /// Load given persons
  Future<Iterable<Person>> fetch({
    Iterable<String> uuids,
    bool replace = false,
  });

  /// Init from local storage, overwrite states
  /// with given persons if given. Returns
  /// number of states after initialisation
  Future<int> init({List<Person> persons});

  /// Update [Person]
  Future<Person> create(Person person);

  /// Update [Person]
  Future<Person> update(Person person);

  /// Delete [Person] with given [uuid]
  Future<Person> delete(String uuid);

  /// Check if state transitioned into a
  /// [PersonConflictCode.duplicate_user_id]
  /// conflict
  static bool isDuplicateUser(StorageTransition<Person> event) =>
      event.isConflict &&
      event.conflict.isCode(
        PersonConflictCode.duplicate_user_id,
      );
}

class PersonServiceException implements Exception {
  PersonServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return '$runtimeType: $error, response: $response, stackTrace: $stackTrace';
  }
}
