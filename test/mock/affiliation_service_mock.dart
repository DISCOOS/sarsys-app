// @dart=2.11

import 'dart:async';
import 'dart:convert';

import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/data/models/conflict_model.dart';
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
    String userId,
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
        userId: userId,
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
    String userId,
    String orguuid,
    String divuuid,
    String depuuid,
    bool active = true,
  }) {
    return json.decode('{'
        '"uuid": "$uuid",'
        '"person": {"uuid": "$puuid"${userId == null ? '' : ', "userId": "$userId"'}},'
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
  final Map<String, StorageState<Affiliation>> affiliationRepo = {};

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

    final state = StorageState.created(
      affiliation,
      StateVersion.first,
      isRemote: true,
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
        state,
      );
    }
    affiliationRepo[affiliation.uuid] = state;
    return affiliation;
  }

  StorageState<Affiliation> remove(String uuid) {
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
    final StreamController<AffiliationMessage> controller = StreamController.broadcast();

    when(mock.getListFromIds(any)).thenAnswer((_) async {
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

    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.create(any)).thenAnswer((_) async {
      await _doThrottle();
      final state = _.positionalArguments[0] as StorageState<Affiliation>;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final affiliation = _toAffiliation(state);
      final puuid = affiliation.person.uuid;
      // Onboard person?
      if (affiliation.isAffiliate) {
        if (persons.personRepo.containsKey(puuid)) {
          await persons.update(
            persons.personRepo[puuid].apply(
              affiliation.person,
              replace: true,
              isRemote: false,
            ),
          );
        }
        final existing = _findDuplicateUsers(persons, affiliation.person);
        final duplicates = _findDuplicateAffiliations(persons, affiliationRepo.values, affiliation, puuid);
        if (existing.isNotEmpty) {
          return ServiceResponse.asConflict(
            conflict: ConflictModel(
              type: ConflictType.exists,
              base: existing.first.value.toJson(),
              mine: duplicates,
              yours: [affiliation.toJson()],
              code: enumName(PersonConflictCode.duplicate_user_id),
              error: 'Person ${affiliation.person.uuid} have duplicate userId',
            ),
          );
        }
        if (duplicates.isNotEmpty) {
          return ServiceResponse.asConflict(
            conflict: ConflictModel(
              type: ConflictType.exists,
              mine: duplicates,
              yours: [affiliation.toJson()],
              code: enumName(AffiliationConflictCode.duplicate_affiliations),
              error: 'Person ${affiliation.person.uuid} have duplicate affiliations',
            ),
          );
        }
        await persons.create(StorageState<Person>.created(
          affiliation.person,
          StateVersion.first,
        ));
      }
      affiliationRepo[affiliation.uuid] = state.remote(
        affiliation,
        version: state.version,
      );
      return ServiceResponse.ok(
        body: affiliationRepo[affiliation.uuid],
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      await _doThrottle();
      final next = _.positionalArguments[0] as StorageState<Affiliation>;
      final affiliation = _toAffiliation(next);
      final uuid = affiliation.uuid;
      if (affiliationRepo.containsKey(uuid)) {
        final state = affiliationRepo[uuid];
        final delta = next.version.value - state.version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        affiliationRepo[uuid] = state.apply(
          affiliation,
          replace: false,
          isRemote: true,
        );
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
      final state = _.positionalArguments[0] as StorageState<Affiliation>;
      final uuid = state.value.uuid;
      if (affiliationRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: affiliationRepo.remove(uuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Affiliation not found: $uuid",
      );
    });
    return mock;
  }

  static List<StorageState<Person>> _findDuplicateUsers(PersonServiceMock persons, Person person) {
    return persons.personRepo.values
        .where((s) => person.uuid != s.value.uuid && person.userId != null && person.userId == s.value.userId)
        .toList();
  }

  static List<Map<String, dynamic>> _findDuplicateAffiliations(
    PersonServiceMock persons,
    Iterable<StorageState<Affiliation>> affiliations,
    Affiliation affiliation,
    String puuid,
  ) {
    // Ensure we are updated with remote streams
    final auuid = affiliation.uuid;

    // Ensure person
    final person = persons.personRepo[puuid];
    final userId = person?.value?.userId ?? affiliation.person.userId;
    final orguuid = affiliation.org?.uuid;
    final divuuid = affiliation.div?.uuid;
    final depuuid = affiliation.dep?.uuid;

    // Look for duplicate affiliation, checking for
    // 1. Volunteer affiliations without any organisations
    // 2. Identical affiliation with org, div and dep
    return affiliations
        .where((s) => !s.isDeleted)
        .where((s) {
          final a = s.value;
          // Different affiliation and same person?
          if (a.uuid != auuid) {
            final existing = persons.personRepo[a.person.uuid];
            if (existing != null) {
              if (isSamePerson(existing.value, puuid, userId)) {
                final testOrg = a.org?.uuid;
                final testDiv = a.div?.uuid;
                final testDep = a.dep?.uuid;

                // Is unorganized?
                if (testOrg == null && testDiv == null && testDep == null) {
                  return true;
                }

                // Already affiliated?
                return testOrg == orguuid && testDiv == divuuid && testDep == depuuid;
              }
            }
          }
          return false;
        })
        .map((a) => a.value.toJson())
        .toList();
  }

  static bool isSamePerson(Person person, String puuid, String userId) =>
      puuid != null && person.uuid == puuid || userId != null && person.userId == userId;

  static StorageState<Affiliation> _withPerson(
      Map<String, StorageState<Affiliation>> affiliationRepo, uuid, PersonServiceMock persons) {
    final state = affiliationRepo[uuid];
    final affiliation = state.value;
    final next = affiliation.person?.uuid == null ? null : persons.personRepo[affiliation.person.uuid];
    return state.replace(affiliation.copyWith(person: next?.value));
  }

  static Affiliation _toAffiliation(StorageState<Affiliation> state) {
    final affiliation = state.value;
    final json = affiliation.toJson();
    assert(
      json.hasPath('person/uuid'),
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
