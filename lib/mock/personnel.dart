import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:mockito/mockito.dart';
import 'package:random_string/random_string.dart';
import 'package:faker/faker.dart';
import 'package:uuid/uuid.dart';

class PersonnelBuilder {
  static Personnel create({
    String uuid,
    String userId,
    String tracking,
    PersonnelStatus status = PersonnelStatus.Mobilized,
  }) {
    return Personnel.fromJson(
      createPersonnelAsJson(
        uuid ?? Uuid().v4(),
        userId,
        status ?? PersonnelStatus.Mobilized,
        tracking,
      ),
    );
  }

  static Map<String, dynamic> createPersonnelAsJson(
          String uuid, String userId, PersonnelStatus status, String tracking) =>
      json.decode('{'
          '"uuid": "$uuid",'
          '"userId": "$userId",'
          '"fname": "${faker.person.firstName()}",'
          '"lname": "${faker.person.lastName()}",'
          '"status": "${enumName(status)}",'
          '"affiliation": ${json.encode(createAffiliation())},'
          '"function": "${enumName(OperationalFunction.Personnel)}"'
          '${tracking != null ? ',"tracking": {"uuid": "$tracking"}' : ''}'
          '}');

  static Map<String, dynamic> createAffiliation() => Affiliation(
        orgId: Defaults.orgId,
        divId: Defaults.divId,
        depId: Defaults.depId,
      ).toJson();
}

class PersonnelServiceMock extends Mock implements PersonnelService {
  PersonnelServiceMock();
  final Map<String, Map<String, Personnel>> personnelRepo = {};

  Personnel add(
    String iuuid, {
    String uuid,
    String tracking,
    PersonnelStatus status,
  }) {
    final personnel = PersonnelBuilder.create(
      uuid: uuid,
      status: status,
      tracking: tracking,
    );
    if (personnelRepo.containsKey(iuuid)) {
      personnelRepo[iuuid].putIfAbsent(personnel.uuid, () => personnel);
    } else {
      personnelRepo[iuuid] = {personnel.uuid: personnel};
    }
    return personnel;
  }

  List<Personnel> remove(uuid) {
    final iuuids = personnelRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return iuuids
        .map((iuuid) => personnelRepo[iuuid].remove(uuid))
        .where(
          (personnel) => personnel != null,
        )
        .toList();
  }

  factory PersonnelServiceMock.build(final int count) {
    final PersonnelServiceMock mock = PersonnelServiceMock();
    final personnelRepo = mock.personnelRepo;

    // ignore: close_sinks
    final StreamController<PersonnelMessage> controller = StreamController.broadcast();

    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.fetch(any)).thenAnswer((_) async {
      final String iuuid = _.positionalArguments[0];
      var personnel = personnelRepo[iuuid];
      if (personnel == null) {
        personnel = personnelRepo.putIfAbsent(iuuid, () => {});
      }
      // Only generate personnel for automatically generated incidents
      if (iuuid.startsWith('a:') && personnel.isEmpty) {
        personnel.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
              "$iuuid:p:$i",
              Personnel.fromJson(
                PersonnelBuilder.createPersonnelAsJson(
                  "$iuuid:p:$i",
                  "p:$i",
                  PersonnelStatus.Mobilized,
                  "$iuuid:t:p:$i",
                ),
              ),
            ),
        ]);
      }
      return ServiceResponse.ok(
        body: personnel.values.toList(growable: false),
      );
    });

    when(mock.create(any, any)).thenAnswer((_) async {
      final iuuid = _.positionalArguments[0];
      final Personnel personnel = _.positionalArguments[1];
      final repo = personnelRepo[iuuid];
      if (repo == null) {
        return ServiceResponse.notFound(message: "Incident not found: $iuuid");
      }
      final String uuid = iuuid.startsWith('a:') ? "$iuuid:p:${randomAlphaNumeric(8).toLowerCase()}" : personnel.uuid;
      return ServiceResponse.ok(
        body: repo.putIfAbsent(uuid, () => personnel.cloneWith(uuid: uuid)),
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      final Personnel personnel = _.positionalArguments[0];
      var incident = personnelRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(personnel.uuid),
        orElse: () => null,
      );
      if (incident != null) {
        return ServiceResponse.ok(
          body: incident.value.update(personnel.uuid, (_) => personnel, ifAbsent: () => personnel),
        );
      }
      return ServiceResponse.notFound(
        message: "Not found. Personnel ${personnel.uuid}",
      );
    });

    when(mock.delete(any)).thenAnswer((_) async {
      final Personnel personnel = _.positionalArguments[0];
      var incident = personnelRepo.entries.firstWhere(
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
