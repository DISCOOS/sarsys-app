import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:faker/faker.dart';
import 'package:uuid/uuid.dart';

class PersonnelBuilder {
  static Personnel create({
    String uuid,
    String userId,
    String tuuid,
    PersonnelStatus status = PersonnelStatus.mobilized,
  }) {
    return PersonnelModel.fromJson(
      createAsJson(
        uuid: uuid ?? Uuid().v4(),
        userId: userId,
        status: status ?? PersonnelStatus.mobilized,
        tuuid: tuuid,
      ),
    );
  }

  static Map<String, dynamic> createAsJson({
    @required String uuid,
    @required PersonnelStatus status,
    String userId,
    String tuuid,
  }) =>
      json.decode('{'
          '"uuid": "$uuid",'
          '"userId": "$userId",'
          '"fname": "${faker.person.firstName()}",'
          '"lname": "${faker.person.lastName()}",'
          '"status": "${enumName(status)}",'
          '"affiliation": ${json.encode(createAffiliation())},'
          '"function": "${enumName(OperationalFunction.Personnel)}",'
          '"tracking": {"uuid": "${tuuid ?? Uuid().v4()}", "type": "Personnel"}'
          '}');

  static Map<String, dynamic> createAffiliation() => Affiliation(
        org: AggregateRef.fromType<Organisation>(Defaults.orgId),
        div: AggregateRef.fromType<Division>(Defaults.divId),
        dep: AggregateRef.fromType<Department>(Defaults.depId),
      ).toJson();
}

class PersonnelServiceMock extends Mock implements PersonnelService {
  PersonnelServiceMock();
  final Map<String, Map<String, Personnel>> personnelsRepo = {};

  Personnel add(
    String ouuid, {
    String uuid,
    String tracking,
    PersonnelStatus status = PersonnelStatus.mobilized,
  }) {
    final personnel = PersonnelBuilder.create(
      uuid: uuid,
      status: status,
      tuuid: tracking,
    );
    if (personnelsRepo.containsKey(ouuid)) {
      personnelsRepo[ouuid].putIfAbsent(personnel.uuid, () => personnel);
    } else {
      personnelsRepo[ouuid] = {personnel.uuid: personnel};
    }
    return personnel;
  }

  List<Personnel> remove(String uuid) {
    final iuuids = personnelsRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return iuuids
        .map((ouuid) => personnelsRepo[ouuid].remove(uuid))
        .where(
          (personnel) => personnel != null,
        )
        .toList();
  }

  factory PersonnelServiceMock.build(final int count, {List<String> ouuids = const []}) {
    final PersonnelServiceMock mock = PersonnelServiceMock();
    final personnelsRepo = mock.personnelsRepo;

    // Only generate units for automatically generated operations
    ouuids.forEach((ouuid) {
      if (ouuid.startsWith('a:')) {
        final personnels = personnelsRepo.putIfAbsent(ouuid, () => {});
        personnels.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
              "$ouuid:p:$i",
              PersonnelModel.fromJson(
                PersonnelBuilder.createAsJson(
                  uuid: "$ouuid:p:$i",
                  userId: "p:$i",
                  status: PersonnelStatus.mobilized,
                  tuuid: "$ouuid:t:p:$i",
                ),
              ),
            ),
        ]);
      }
    });

    // ignore: close_sinks
    final StreamController<PersonnelMessage> controller = StreamController.broadcast();

    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.fetchAll(any)).thenAnswer((_) async {
      final String ouuid = _.positionalArguments[0];
      var personnel = personnelsRepo[ouuid];
      if (personnel == null) {
        personnel = personnelsRepo.putIfAbsent(ouuid, () => {});
      }
      return ServiceResponse.ok(
        body: personnel.values.toList(growable: false),
      );
    });

    when(mock.create(any, any)).thenAnswer((_) async {
      final ouuid = _.positionalArguments[0];
      final Personnel personnel = _.positionalArguments[1];
      final personnels = personnelsRepo.putIfAbsent(ouuid, () => {});
      final String puuid = personnel.uuid;
      personnels.putIfAbsent(puuid, () => personnel.copyWith(uuid: puuid));
      return ServiceResponse.created();
    });

    when(mock.update(any)).thenAnswer((_) async {
      final Personnel personnel = _.positionalArguments[0];
      var personnels = personnelsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(personnel.uuid),
        orElse: () => null,
      );
      if (personnels != null) {
        return ServiceResponse.ok(
          body: personnels.value.update(personnel.uuid, (_) => personnel, ifAbsent: () => personnel),
        );
      }
      return ServiceResponse.notFound(
        message: "Not found. Personnel ${personnel.uuid}",
      );
    });

    when(mock.delete(any)).thenAnswer((_) async {
      final puuid = _.positionalArguments[0] as String;
      var incident = personnelsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(puuid),
        orElse: () => null,
      );
      if (incident != null) {
        incident.value.remove(puuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Personnel not found: $puuid",
      );
    });

    return mock;
  }
}
