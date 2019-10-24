import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:mockito/mockito.dart';
import 'package:random_string/random_string.dart';
import 'package:faker/faker.dart';

class PersonnelBuilder {
  static Map<String, dynamic> createPersonnelAsJson(String id, String userId, String tracking) => json.decode('{'
      '"id": "$id",'
      '"userId": "$userId",'
      '"fname": "${faker.person.firstName()}",'
      '"lname": "${faker.person.lastName()}",'
      '"status": "${enumName(PersonnelStatus.Mobilized)}",'
      '"affiliation": ${json.encode(createAffiliation())},'
      '"tracking": "${translateOperationalFunction(OperationalFunction.Personnel)}",'
      '"tracking": "$tracking"'
      '}');

  static Map<String, dynamic> createAffiliation() => Affiliation(
        organization: Defaults.organization,
        division: Defaults.division,
        department: Defaults.department,
      ).toJson();
}

class PersonnelServiceMock extends Mock implements PersonnelService {
  PersonnelServiceMock();
  final Map<String, Map<String, Personnel>> personnelRepo = {};

  factory PersonnelServiceMock.build(final int count) {
    final PersonnelServiceMock mock = PersonnelServiceMock();
    final personnelRepo = mock.personnelRepo;

    // ignore: close_sinks
    final StreamController<PersonnelMessage> controller = StreamController.broadcast();

    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.fetch(any)).thenAnswer((_) async {
      final String incidentId = _.positionalArguments[0];
      var personnel = personnelRepo[incidentId];
      if (personnel == null) {
        personnel = personnelRepo.putIfAbsent(incidentId, () => {});
      }
      // Only generate personnel for automatically generated incidents
      if (incidentId.startsWith('a:') && personnel.isEmpty) {
        personnel.addEntries([
          for (var i = 1; i <= count; i++)
            MapEntry(
                "$incidentId:p:$i",
                Personnel.fromJson(
                  PersonnelBuilder.createPersonnelAsJson("$incidentId:p:$i", "p:$i", "$incidentId:t:p:$i"),
                )),
        ]);
      }
      return ServiceResponse.ok(body: personnel.values.toList(growable: false));
    });

    when(mock.create(any, any)).thenAnswer((_) async {
      final incidentId = _.positionalArguments[0];
      final Personnel personnel = _.positionalArguments[1];
      final repo = personnelRepo[incidentId];
      if (repo == null) {
        return ServiceResponse.notFound(message: "Not found. Incident $incidentId");
      }
      final String id = "$incidentId:p:${randomAlphaNumeric(8).toLowerCase()}";
      return ServiceResponse.ok(body: repo.putIfAbsent(id, () => personnel.cloneWith(id: id)));
    });

    when(mock.update(any)).thenAnswer((_) async {
      final Personnel personnel = _.positionalArguments[0];
      var incident = personnelRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(personnel.id),
        orElse: () => null,
      );
      if (incident != null) {
        incident.value.update(personnel.id, (_) => personnel, ifAbsent: () => personnel);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Personnel ${personnel.id}");
    });

    when(mock.delete(any)).thenAnswer((_) async {
      final Personnel personnel = _.positionalArguments[0];
      var incident = personnelRepo.entries.firstWhere(
        (entry) => entry.value.containsKey(personnel.id),
        orElse: () => null,
      );
      if (incident != null) {
        incident.value.remove(personnel.id);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Personnel ${personnel.id}");
    });

    return mock;
  }
}
