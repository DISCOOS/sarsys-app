import 'dart:convert';

import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/services/division_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/services/service.dart';

class DivisionBuilder {
  static Division create(
    String orguuid, {
    @required String name,
    @required String suffix,
    String divuuid,
    bool active,
    List<String> departments,
  }) {
    return DivisionModel.fromJson(
      createAsJson(
        orguuid,
        divuuid: divuuid ?? Uuid().v4(),
        name: name,
        suffix: suffix,
        active: active ?? true,
        departments: departments ?? [],
      ),
    );
  }

  static createAsJson(
    String orguuid, {
    String divuuid,
    String name,
    bool active,
    String suffix,
    List<String> departments,
  }) {
    return json.decode('{'
        '"uuid": "$divuuid",'
        '"name": "$name",'
        '"suffix": $active,'
        '"suffix": "$suffix",'
        '"organisation": {"uuid": "$orguuid"},'
        '"departments": [${departments != null ? departments.join(',') : ''}]'
        '}');
  }
}

class DivisionServiceMock extends Mock implements DivisionService {
  final Map<String, Division> divRepo = {};

  Division add(
    String orguuid, {
    String name,
    String suffix,
    List<String> departments,
    String divuuid,
    bool active,
  }) {
    final div = DivisionBuilder.create(
      orguuid,
      divuuid: divuuid,
      name: name ?? 'Div ${divRepo.length + 1}',
      suffix: suffix ?? '${divRepo.length + 1}',
      departments: departments,
      active: active,
    );
    divRepo[div.uuid] = div;
    return div;
  }

  Division remove(String uuid) {
    return divRepo.remove(uuid);
  }

  static DivisionService build({List<String> orguuids = const [], int divs = 1, int deps = 1}) {
    final DivisionServiceMock mock = DivisionServiceMock();
    final divRepo = mock.divRepo;

    orguuids.forEach((orguuid) {
      if (orguuid.startsWith('a:')) {
        for (int i = 1; i < divs; i++) {
          final divuuid = '$orguuid:div:$i';
          final div = DivisionBuilder.create(
            orguuid,
            divuuid: divuuid,
            name: "Div $i",
            suffix: "$i",
            departments: List.generate(deps, (j) => '$orguuid:div:$i:dep:$j'),
          );
          divRepo[divuuid] = div;
        }
      }
    });

    when(mock.fetchAll()).thenAnswer((_) async {
      return ServiceResponse.ok(
        body: divRepo.values.toList(),
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      divRepo[uuid] = _.positionalArguments[1];
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      final Division org = _.positionalArguments[0];
      if (divRepo.containsKey(org.uuid)) {
        divRepo[org.uuid] = org;
        return ServiceResponse.ok(
          body: org,
        );
      }
      return ServiceResponse.notFound(
        message: "Division not found: ${org.uuid}",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final String uuid = _.positionalArguments[0];
      if (divRepo.containsKey(uuid)) {
        divRepo.remove(uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Division not found: $uuid",
      );
    });
    return mock;
  }
}
