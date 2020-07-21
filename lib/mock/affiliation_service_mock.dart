import 'dart:convert';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/repositories/affiliation_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/services/service.dart';

class AffiliationBuilder {
  static Affiliation create({
    String uuid,
    String puuid,
    String orguuid,
    String divuuid,
    String depuuid,
    bool active = true,
    AffiliationType type,
    AffiliationStandbyStatus status,
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
  AffiliationServiceMock(this.states);
  final Map<String, Affiliation> affiliationRepo = {};
  final Box<StorageState<Affiliation>> states;

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
          remote: true,
        ),
      );
    }
    affiliationRepo[affiliation.uuid] = affiliation;
    return affiliation;
  }

  Affiliation remove(String uuid) {
    return affiliationRepo.remove(uuid);
  }

  static Future<AffiliationService> build() async {
    final box = await Hive.openBox<StorageState<Affiliation>>(
      ConnectionAwareRepository.toBoxName<AffiliationRepositoryImpl>(),
    );
    final AffiliationServiceMock mock = AffiliationServiceMock(box);
    final affiliationRepo = mock.affiliationRepo;

    when(mock.get(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      if (affiliationRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: affiliationRepo[uuid],
        );
      }
      await _doThrottle();
      return ServiceResponse.notFound(
        message: "Affiliation not found: $uuid",
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      final affiliation = _.positionalArguments[0] as Affiliation;
      affiliationRepo[affiliation.uuid] = affiliation;
      await _doThrottle();
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      final Affiliation affiliation = _.positionalArguments[0];
      if (affiliationRepo.containsKey(affiliation.uuid)) {
        affiliationRepo[affiliation.uuid] = affiliation;
        return ServiceResponse.ok(
          body: affiliation,
        );
      }
      await _doThrottle();
      return ServiceResponse.notFound(
        message: "Affiliation not found: ${affiliation.uuid}",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final String uuid = _.positionalArguments[0];
      if (affiliationRepo.containsKey(uuid)) {
        affiliationRepo.remove(uuid);
        return ServiceResponse.noContent();
      }
      await _doThrottle();
      return ServiceResponse.notFound(
        message: "Affiliation not found: $uuid",
      );
    });
    return mock;
  }

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
