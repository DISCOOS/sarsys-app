import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/repositories/person_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/core/data/services/service.dart';

class PersonBuilder {
  static Person create({
    @required String fname,
    @required String lname,
    @required String phone,
    @required String email,
    @required String userId,
    String uuid,
    bool temporary = false,
  }) {
    return PersonModel.fromJson(
      createAsJson(
        uuid: uuid ?? Uuid().v4(),
        fname: fname,
        lname: lname,
        phone: phone,
        email: email,
        userId: userId,
        temporary: temporary ?? false,
      ),
    );
  }

  static createAsJson({
    @required String uuid,
    @required String fname,
    @required String lname,
    @required String phone,
    @required String email,
    @required String userId,
    bool temporary = false,
  }) {
    return json.decode('{'
        '"uuid": "$uuid",'
        '"fname": "$fname",'
        '"lname": "$lname",'
        '"phone": "$phone",'
        '"email": "$email",'
        '"userId": "$userId",'
        '"temporary": $temporary'
        '}');
  }
}

class PersonServiceMock extends Mock implements PersonService {
  PersonServiceMock(this.states);
  final Box<StorageState<Person>> states;
  final Map<String, Person> personRepo = {};

  Future<Person> add({
    String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    bool storage = true,
    bool temporary = false,
  }) async {
    return put(
      PersonBuilder.create(
        uuid: uuid,
        fname: fname ?? 'F${personRepo.length + 1}',
        lname: lname ?? 'L${personRepo.length + 1}',
        phone: phone ?? 'P${personRepo.length + 1}',
        email: email ?? 'E${personRepo.length + 1}',
        userId: userId,
        temporary: temporary,
      ),
      storage: storage,
    );
  }

  Future<Person> put(
    Person person, {
    bool storage = true,
  }) async {
    // Persons are only loaded
    // from server with affiliation command.
    // Therefore, we need to add them to
    // local storage to simulate initialisation
    // from previous states. IMPORTANT: wait
    // for write to complete, or else
    // subsequent close and reopen will
    // will loose any states pending write
    if (storage) {
      await states.put(
        person.uuid,
        StorageState.created(
          person,
          isRemote: true,
        ),
      );
    }
    personRepo[person.uuid] = person;
    return person;
  }

  Person remove(String uuid) {
    return personRepo.remove(uuid);
  }

  Future<void> dispose() {
    return states.close();
  }

  static Future<PersonService> build() async {
    final box = await Hive.openBox<StorageState<Person>>(
      ConnectionAwareRepository.toBoxName<PersonRepositoryImpl>(),
    );
    final PersonServiceMock mock = PersonServiceMock(box);
    final personRepo = mock.personRepo;

    when(mock.get(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      await _doThrottle();
      if (personRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: personRepo[uuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Person not found: $uuid",
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      await _doThrottle();
      final person = _.positionalArguments[0] as Person;
      final existing = findExistingUser(person, personRepo);
      if (existing != null) {
        return ServiceResponse.asConflict(
          conflict: ConflictModel(
            base: existing.toJson(),
            type: ConflictType.exists,
            error: "Person with user_id ${existing.userId} exists",
            code: enumName(PersonConflictCode.duplicate_user_id),
          ),
        );
      }
      personRepo[person.uuid] = person;
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      await _doThrottle();
      final person = _.positionalArguments[0] as Person;
      if (personRepo.containsKey(person.uuid)) {
        personRepo[person.uuid] = person;
        return ServiceResponse.ok(
          body: person,
        );
      }
      return ServiceResponse.notFound(
        message: "Person not found: ${person.uuid}",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      await _doThrottle();
      final String uuid = _.positionalArguments[0];
      if (personRepo.containsKey(uuid)) {
        personRepo.remove(uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Person not found: $uuid",
      );
    });
    return mock;
  }

  static Person findExistingUser(Person person, Map<String, Person> personRepo) =>
      person.userId != null ? personRepo.values.where((p) => p.userId == person.userId).firstOrNull : null;

  static Future _doThrottle() async {
    if (_throttle != null) {
      return Future.delayed(_throttle);
    }
    Future.value();
  }

  static Duration _throttle;
  Duration throttle(Duration duration) {
    final previous = _throttle;
    _throttle = duration;
    return previous;
  }
}
