

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/repositories/person_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/core/data/services/service.dart';

class PersonBuilder {
  static Person create({
    required String fname,
    required String lname,
    required String phone,
    required String email,
    required String? userId,
    String? uuid,
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
        temporary: temporary,
      ),
    );
  }

  static createAsJson({
    required String uuid,
    required String fname,
    required String lname,
    required String phone,
    required String email,
    required String? userId,
    bool temporary = false,
  }) {
    return json.decode('{'
        '"uuid": "$uuid",'
        '"fname": "$fname",'
        '"lname": "$lname",'
        '"phone": "$phone",'
        '"email": "$email",'
        '${userId == null ? '' : '"userId": "$userId",'}'
        '"temporary": $temporary'
        '}');
  }
}

class PersonServiceMock extends Mock implements PersonService {
  PersonServiceMock(this.states);
  final Box<StorageState<Person>> states;
  final Map<String?, StorageState<Person>> personRepo = {};

  Future<Person> add({
    String? uuid,
    String? fname,
    String? lname,
    String? phone,
    String? email,
    String? userId,
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
    final state = StorageState.created(
      person,
      StateVersion.first,
      isRemote: true,
    );
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
        state,
      );
    }
    personRepo[person.uuid] = state;
    return person;
  }

  StorageState<Person>? remove(String uuid) {
    return personRepo.remove(uuid);
  }

  Future<void> dispose() {
    return states.close();
  }

  static Future<PersonService> build() async {
    final box = await Hive.openBox<StorageState<Person>>(
      StatefulRepository.toBoxName<PersonRepositoryImpl>(),
      encryptionCipher: await Storage.hiveCipher<Person>(),
    );
    final PersonServiceMock mock = PersonServiceMock(box);
    final personRepo = mock.personRepo;
    final StreamController<PersonMessage> controller = StreamController.broadcast();

    when(mock.getFromId(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      await _doThrottle();
      if (personRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: personRepo[uuid] as StorageState<Person>?,
        );
      }
      return ServiceResponse.notFound(
        message: "Person not found: $uuid",
      );
    } as Future<ServiceResponse<StorageState<Person>>> Function(Invocation));

    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.create(any)).thenAnswer((_) async {
      await _doThrottle();
      final state = _.positionalArguments[0] as StorageState<Person>;
      if (!state.version!.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final person = state.value;
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
      final uuid = person.uuid;
      personRepo[uuid] = state.remote(
        state.value,
        version: state.version,
      );
      return existing == null
          ? ServiceResponse.created()
          : ServiceResponse.ok(
              body: personRepo[uuid],
            );
    });

    when(mock.update(any)).thenAnswer((_) async {
      await _doThrottle();
      final next = _.positionalArguments[0] as StorageState<Person>;
      final uuid = next.value.uuid;
      if (personRepo.containsKey(uuid)) {
        final state = personRepo[uuid]!;
        final delta = next.version!.value! - state.version!.value!;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version! + 1}, actual was ${next.version}",
          );
        }
        personRepo[uuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: personRepo[uuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Person not found: $uuid",
      );
    });

    when(mock.delete(any)).thenAnswer((_) async {
      await _doThrottle();
      final state = _.positionalArguments[0] as StorageState<Person>;
      final uuid = state.value.uuid;
      if (personRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: personRepo.remove(uuid) as StorageState<Person>?,
        );
      }
      return ServiceResponse.notFound(
        message: "Person not found: $uuid",
      );
    } as Future<ServiceResponse<StorageState<Person>>> Function(Invocation));
    return mock;
  }

  static Person? findExistingUser(Person person, Map<String?, StorageState<Person>> personRepo) => person.userId != null
      ? personRepo.values.map((s) => s.value).where((p) => p.userId == person.userId).firstOrNull
      : null;

  static Future _doThrottle() async {
    if (_throttle != null) {
      return Future.delayed(_throttle!);
    }
    Future.value();
  }

  static Duration? _throttle;
  Duration? throttle(Duration duration) {
    final previous = _throttle;
    _throttle = duration;
    return previous;
  }
}
