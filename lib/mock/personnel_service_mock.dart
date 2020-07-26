import 'dart:async';
import 'dart:convert';

import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:faker/faker.dart' as random;
import 'package:uuid/uuid.dart';

class PersonnelBuilder {
  static Personnel create({
    String uuid,
    String tuuid,
    String auuid,
    String userId,
    PersonnelStatus status = PersonnelStatus.alerted,
  }) {
    return PersonnelModel.fromJson(
      createAsJson(
        auuid: auuid,
        tuuid: tuuid,
        userId: userId,
        uuid: uuid ?? Uuid().v4(),
        status: status ?? PersonnelStatus.alerted,
      ),
    );
  }

  static Map<String, dynamic> createAsJson({
    @required String uuid,
    @required PersonnelStatus status,
    String auuid,
    String tuuid,
    String userId,
  }) =>
      json.decode('{'
          '"uuid": "$uuid",'
          '"userId": "$userId",'
          '"fname": "${random.faker.person.firstName()}",'
          '"lname": "${random.faker.person.lastName()}",'
          '"status": "${enumName(status)}",'
          '"affiliation": {"uuid": "${auuid ?? Uuid().v4()}"},'
          '"function": "${enumName(OperationalFunctionType.personnel)}",'
          '"tracking": {"uuid": "${tuuid ?? Uuid().v4()}", "type": "Personnel"}'
          '}');

  static Map<String, dynamic> createAffiliation({
    String uuid,
    String puuid,
    String orguuid,
    String divuuid,
    String depuuid,
    AffiliationType type,
    AffiliationStandbyStatus status,
  }) =>
      AffiliationModel(
        uuid: uuid ?? Uuid().v4(),
        type: type ?? AffiliationType.volunteer,
        status: status ?? AffiliationStandbyStatus.available,
        person: AggregateRef.fromType<Person>(puuid ?? Uuid().v4()),
        div: AggregateRef.fromType<Division>(divuuid ?? Uuid().v4()),
        dep: AggregateRef.fromType<Department>(depuuid ?? Uuid().v4()),
        org: AggregateRef.fromType<Organisation>(orguuid ?? Uuid().v4()),
      ).toJson();
}

class PersonnelServiceMock extends Mock implements PersonnelService {
  PersonnelServiceMock();
  final Map<String, Map<String, Personnel>> personnelsRepo = {};

  Personnel add(
    String ouuid, {
    String uuid,
    String auuid,
    String tuuid,
    PersonnelStatus status = PersonnelStatus.alerted,
  }) {
    final personnel = PersonnelBuilder.create(
      uuid: uuid,
      auuid: auuid,
      tuuid: tuuid,
      status: status,
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
                  status: PersonnelStatus.alerted,
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
