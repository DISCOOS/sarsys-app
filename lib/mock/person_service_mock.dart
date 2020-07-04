import 'dart:convert';

import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/services/service.dart';

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
  final Map<String, Person> personRepo = {};

  Person add({
    String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    bool temporary = false,
  }) {
    final person = PersonBuilder.create(
      uuid: uuid,
      fname: fname ?? 'F${personRepo.length + 1}',
      lname: lname ?? 'L${personRepo.length + 1}',
      phone: phone ?? 'P${personRepo.length + 1}',
      email: email ?? 'E${personRepo.length + 1}',
      userId: userId,
      temporary: temporary,
    );
    personRepo[person.uuid] = person;
    return person;
  }

  Person remove(String uuid) {
    return personRepo.remove(uuid);
  }

  static PersonService build() {
    final PersonServiceMock mock = PersonServiceMock();
    final personRepo = mock.personRepo;

    when(mock.get(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
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
      final person = _.positionalArguments[0] as Person;
      personRepo[person.uuid] = person;
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
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
}
