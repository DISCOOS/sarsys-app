import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/repositories/affiliation_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/extensions.dart';

import 'package:SarSys/core/data/services/service.dart';

import 'person_service_mock.dart';

class AffiliationBuilder {
  static Affiliation create({
    String uuid,
    String puuid,
    String orguuid,
    String divuuid,
    String depuuid,
    bool active = true,
    AffiliationType type = AffiliationType.volunteer,
    AffiliationStandbyStatus status = AffiliationStandbyStatus.available,
  }) {
    return AffiliationModel.fromJson(
      createAsJson(
        uuid: uuid ?? Uuid().v4(),
        type: type,
        puuid: puuid,
        status: status,
        orguuid: orguuid,
        divuuid: divuuid,
        depuuid: depuuid,
        active: active ?? true,
      ),
    );
  }

  static createAsJson({
    @required String uuid,
    @required AffiliationType type,
    @required AffiliationStandbyStatus status,
    String puuid,
    String orguuid,
    String divuuid,
    String depuuid,
    bool active = true,
  }) {
    return json.decode('{'
        '"uuid": "$uuid",'
        '"person": {"uuid": "$puuid"},'
        '"org": {"uuid": "$orguuid"},'
        '"div": {"uuid": "$divuuid"},'
        '"dep": {"uuid": "$depuuid"},'
        '"type": "${enumName(type)}",'
        '"status": "${enumName(status)}",'
        '"active": $active'
        '}');
  }
}

class AffiliationServiceMock extends Mock implements AffiliationService {
  AffiliationServiceMock(
    this.states,
    this.persons,
  );
  final PersonServiceMock persons;
  final Box<StorageState<Affiliation>> states;
  final Map<String, Affiliation> affiliationRepo = {};

  Future<Affiliation> add({
    String uuid,
    String puuid,
    String orguuid,
    String divuuid,
    String depuuid,
    bool active = true,
    bool storage = true,
    AffiliationType type = AffiliationType.member,
    AffiliationStandbyStatus status = AffiliationStandbyStatus.available,
  }) async {
    final affiliation = AffiliationBuilder.create(
      uuid: uuid,
      type: type,
      puuid: puuid,
      status: status,
      orguuid: orguuid,
      divuuid: divuuid,
      depuuid: depuuid,
      active: active ?? true,
    );
    // Affiliations are only loaded
    // from server by id. Therefore, we
    // need to add them to local storage
    // to simulate initialisation from
    // previous states. IMPORTANT: wait
    // for write to complete, or else
    // subsequent close and reopen will
    // will loose any states pending write
    if (storage) {
      await states.put(
        affiliation.uuid,
        StorageState.created(
          affiliation,
          isRemote: true,
        ),
      );
    }
    affiliationRepo[affiliation.uuid] = affiliation;
    return affiliation;
  }

  Affiliation remove(String uuid) {
    return affiliationRepo.remove(uuid);
  }

  Future<void> dispose() {
    return states.close();
  }

  static Future<AffiliationService> build(PersonServiceMock persons) async {
    final box = await Hive.openBox<StorageState<Affiliation>>(
      StatefulRepository.toBoxName<AffiliationRepositoryImpl>(),
      encryptionCipher: await Storage.hiveCipher<Affiliation>(),
    );
    final AffiliationServiceMock mock = AffiliationServiceMock(box, persons);
    final affiliationRepo = mock.affiliationRepo;

    when(mock.getFromId(any)).thenAnswer((_) async {
      await _doThrottle();
      final uuid = _.positionalArguments[0];
      if (affiliationRepo.containsKey(uuid)) {
        Affiliation affiliation = _withPerson(affiliationRepo, uuid, persons);
        return ServiceResponse.ok(
          body: affiliation,
        );
      }
      return ServiceResponse.notFound(
        message: "Affiliation not found: $uuid",
      );
    });
    when(mock.getAll(any)).thenAnswer((_) async {
      await _doThrottle();
      final uuids = List<String>.from(_.positionalArguments[0]);
      final affiliations = uuids
          .where((uuid) => affiliationRepo.containsKey(uuid))
          .map((uuid) => _withPerson(affiliationRepo, uuid, persons))
          .toList();
      return ServiceResponse.ok(
        body: affiliations,
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      await _doThrottle();
      final affiliation = _toAffiliation(_);
      affiliationRepo[affiliation.uuid] = affiliation;
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      await _doThrottle();
      final Affiliation affiliation = _toAffiliation(_);
      if (affiliationRepo.containsKey(affiliation.uuid)) {
        final uuid = affiliation.uuid;
        affiliationRepo[uuid] = affiliation;
        return ServiceResponse.ok(
          body: _withPerson(affiliationRepo, uuid, persons),
        );
      }
      return ServiceResponse.notFound(
        message: "Affiliation not found: ${affiliation.uuid}",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      await _doThrottle();
      final String uuid = _.positionalArguments[0];
      if (affiliationRepo.containsKey(uuid)) {
        affiliationRepo.remove(uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Affiliation not found: $uuid",
      );
    });
    return mock;
  }

  static Affiliation _withPerson(Map<String, Affiliation> affiliationRepo, uuid, PersonServiceMock persons) {
    final affiliation = affiliationRepo[uuid];
    final person = affiliation.person?.uuid == null ? null : persons.personRepo[affiliation.person.uuid];
    return affiliation.copyWith(person: person);
  }

  static Affiliation _toAffiliation(Invocation method) {
    final affiliation = method.positionalArguments[0] as Affiliation;
    final json = affiliation.toJson();
    assert(
      json.mapAt<String, dynamic>('person').length == 1,
      "Aggregate reference 'person' contains more then one value",
    );
    assert(
      json.mapAt<String, dynamic>('person').keys.first == 'uuid',
      "Aggregate reference 'person' does not contain value 'uuid'",
    );
    return affiliation;
  }

  static Future _doThrottle() async {
    if (_throttle != null) {
      return Future.delayed(_throttle);
    }
    return Future.value();
  }

  static Duration _throttle;
  Duration throttle(Duration duration) {
    final previous = _throttle;
    _throttle = duration;
    return previous;
  }
}
