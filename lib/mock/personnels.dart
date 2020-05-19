import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/personnel_service.dart';
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
    PersonnelStatus status = PersonnelStatus.Mobilized,
  }) {
    return Personnel.fromJson(
      createAsJson(
        uuid: uuid ?? Uuid().v4(),
        userId: userId,
        status: status ?? PersonnelStatus.Mobilized,
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
        orgId: Defaults.orgId,
        divId: Defaults.divId,
        depId: Defaults.depId,
      ).toJson();
}

class PersonnelServiceMock extends Mock implements PersonnelService {
  PersonnelServiceMock();
  final Map<String, Map<String, Personnel>> personnelsRepo = {};

  Personnel add(
    String iuuid, {
    String uuid,
    String tracking,
    PersonnelStatus status = PersonnelStatus.Mobilized,
  }) {
    final personnel = PersonnelBuilder.create(
      uuid: uuid,
      status: status,
      tuuid: tracking,
    );
    if (personnelsRepo.containsKey(iuuid)) {
      personnelsRepo[iuuid].putIfAbsent(personnel.uuid, () => personnel);
    } else {
      personnelsRepo[iuuid] = {personnel.uuid: personnel};
    }
    return personnel;
  }

  List<Personnel> remove(String uuid) {
    final iuuids = personnelsRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return iuuids
        .map((iuuid) => personnelsRepo[iuuid].remove(uuid))
        .where(
          (personnel) => personnel != null,
        )
        .toList();
  }

  factory PersonnelServiceMock.build(final int count, {List<String> iuuids = const []}) {
    final PersonnelServiceMock mock = PersonnelServiceMock();
    final personnelsRepo = mock.personnelsRepo;

    // Only generate units for automatically generated iuuids
    iuuids.forEach((iuuid) {
      if (iuuid.startsWith('a:')) {
        final personnels = personnelsRepo.putIfAbsent(iuuid, () => {});
        personnels.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
              "$iuuid:p:$i",
              Personnel.fromJson(
                PersonnelBuilder.createAsJson(
                  uuid: "$iuuid:p:$i",
                  userId: "p:$i",
                  status: PersonnelStatus.Mobilized,
                  tuuid: "$iuuid:t:p:$i",
                ),
              ),
            ),
        ]);
      }
    });

    // ignore: close_sinks
    final StreamController<PersonnelMessage> controller = StreamController.broadcast();

    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.fetch(any)).thenAnswer((_) async {
      final String iuuid = _.positionalArguments[0];
      var personnel = personnelsRepo[iuuid];
      if (personnel == null) {
        personnel = personnelsRepo.putIfAbsent(iuuid, () => {});
      }
      return ServiceResponse.ok(
        body: personnel.values.toList(growable: false),
      );
    });

    when(mock.create(any, any)).thenAnswer((_) async {
      final iuuid = _.positionalArguments[0];
      final Personnel personnel = _.positionalArguments[1];
      final personnels = personnelsRepo.putIfAbsent(iuuid, () => {});
      final String puuid = personnel.uuid;
      return ServiceResponse.ok(
        body: personnels.putIfAbsent(puuid, () => personnel.cloneWith(uuid: puuid)),
      );
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
      final Personnel personnel = _.positionalArguments[0];
      var incident = personnelsRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(personnel.uuid),
        orElse: () => null,
      );
      if (incident != null) {
        incident.value.remove(personnel.uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Personnel not found: ${personnel.uuid}",
      );
    });

    return mock;
  }
}
