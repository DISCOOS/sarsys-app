import 'dart:convert';

import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/services/department_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/services/service.dart';

class DepartmentBuilder {
  static Department create(
    String divuuid, {
    @required String name,
    @required String suffix,
    String depuuid,
    bool active,
  }) {
    return DepartmentModel.fromJson(
      createAsJson(
        divuuid,
        depuuid: depuuid ?? Uuid().v4(),
        name: name,
        suffix: suffix,
        active: active ?? true,
      ),
    );
  }

  static createAsJson(
    String divuuid, {
    String depuuid,
    String name,
    bool active,
    String suffix,
  }) {
    return json.decode('{'
        '"uuid": "$depuuid",'
        '"name": "$name",'
        '"suffix": $active,'
        '"suffix": "$suffix",'
        '"division": {"uuid": "$divuuid"}'
        '}');
  }
}

class DepartmentServiceMock extends Mock implements DepartmentService {
  final Map<String, Department> depRepo = {};

  Department add(
    String divuuid, {
    String depuuid,
    String name,
    String suffix,
    bool active,
  }) {
    final dep = DepartmentBuilder.create(
      divuuid,
      depuuid: depuuid,
      name: name ?? 'Dep ${depRepo.length + 1}',
      suffix: suffix ?? '${depRepo.length + 1}',
      active: active ?? true,
    );
    depRepo[dep.uuid] = dep;
    return dep;
  }

  Department remove(String uuid) {
    return depRepo.remove(uuid);
  }

  static DepartmentService build({List<String> orguuids = const [], int divs = 1, int deps = 1}) {
    final DepartmentServiceMock mock = DepartmentServiceMock();
    final depRepo = mock.depRepo;

    orguuids.forEach((orguuid) {
      if (orguuid.startsWith('a:')) {
        for (int i = 1; i < divs; i++) {
          for (int j = 1; i < deps; j++) {
            final depuuid = '$orguuid:div:$i:dep:$j';
            final dep = DepartmentBuilder.create(
              orguuid,
              depuuid: depuuid,
              name: "Dep $j",
              suffix: "$j",
            );
            depRepo[depuuid] = dep;
          }
        }
      }
    });

    when(mock.getList()).thenAnswer((_) async {
      return ServiceResponse.ok(
        body: depRepo.values.toList(),
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      final uuid = _.positionalArguments[0];
      depRepo[uuid] = _.positionalArguments[1];
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      final Department org = _.positionalArguments[0];
      if (depRepo.containsKey(org.uuid)) {
        depRepo[org.uuid] = org;
        return ServiceResponse.ok(
          body: org,
        );
      }
      return ServiceResponse.notFound(
        message: "Department not found: ${org.uuid}",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final String uuid = _.positionalArguments[0];
      if (depRepo.containsKey(uuid)) {
        depRepo.remove(uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(
        message: "Department not found: $uuid",
      );
    });
    return mock;
  }
}
