import 'dart:convert';

import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/services/organisation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/services/service.dart';

class OrganisationBuilder {
  static Organisation create({
    @required String name,
    @required String prefix,
    String uuid,
    List<String> divisions,
    bool active,
  }) {
    return OrganisationModel.fromJson(
      createAsJson(
        uuid: uuid ?? Uuid().v4(),
        name: name,
        prefix: prefix,
        active: active ?? true,
        divisions: divisions ?? [],
      ),
    );
  }

  static createAsJson({
    @required String uuid,
    @required String name,
    @required String prefix,
    bool active,
    List<String> divisions,
  }) {
    return json.decode('{'
        '"uuid": "$uuid",'
        '"name": "$name",'
        '"active": $active,'
        '"prefix": "$prefix",'
        '"divisions": [${divisions != null ? '"${divisions.join("','")}"' : ''}]'
        '}');
  }
}

class OrganisationServiceMock extends Mock implements OrganisationService {
  final Map<String, Organisation> orgRepo = {};

  Organisation add({
    String uuid,
    String name,
    bool active,
    String prefix,
    List<String> divisions,
  }) {
    final org = OrganisationBuilder.create(
      uuid: uuid,
      name: name ?? 'Org ${orgRepo.length + 1}',
      prefix: prefix ?? '${orgRepo.length + 1}',
      divisions: divisions,
      active: active,
    );
    orgRepo[org.uuid] = org;
    return org;
  }

  Organisation remove(String uuid) {
    return orgRepo.remove(uuid);
  }

  static OrganisationService build({List<String> uuids = const [], int divs = 1}) {
    final OrganisationServiceMock mock = OrganisationServiceMock();
    final orgRepo = mock.orgRepo;

    int i = 0;
    uuids.forEach((uuid) {
      if (uuid.startsWith('a:')) {
        final org = OrganisationBuilder.create(
          uuid: uuid,
          name: "Org $i",
          prefix: "$i",
          divisions: List.generate(divs, (j) => '$uuid:div:$j'),
        );
        orgRepo[uuid] = org;
      }
    });

    when(mock.fetchAll()).thenAnswer((_) async {
      return ServiceResponse.ok(
        body: orgRepo.values.toList(),
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      orgRepo[uuid] = _.positionalArguments[1];
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      final Organisation org = _.positionalArguments[0];
      if (orgRepo.containsKey(org.uuid)) {
        orgRepo[org.uuid] = org;
        return ServiceResponse.ok(
          body: org,
        );
      }
      return ServiceResponse.notFound(
        message: "Organisation not found: ${org.uuid}",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final String uuid = _.positionalArguments[0];
      if (orgRepo.containsKey(uuid)) {
        orgRepo.remove(uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Organisation not found: $uuid",
      );
    });
    return mock;
  }
}
