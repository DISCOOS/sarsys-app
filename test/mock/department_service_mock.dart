import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/data/storage.dart';
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
  final Map<String, StorageState<Department>> depRepo = {};

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
    final state = StorageState.created(
      dep,
      StateVersion.first,
      isRemote: true,
    );
    depRepo[dep.uuid] = state;
    return dep;
  }

  StorageState<Department> remove(String uuid) {
    return depRepo.remove(uuid);
  }

  static DepartmentService build({List<String> orguuids = const [], int divs = 1, int deps = 1}) {
    final DepartmentServiceMock mock = DepartmentServiceMock();
    final depRepo = mock.depRepo;
    final StreamController<DepartmentMessage> controller = StreamController.broadcast();

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
            depRepo[depuuid] = StorageState.created(
              dep,
              StateVersion.first,
              isRemote: true,
            );
          }
        }
      }
    });

    when(mock.getList()).thenAnswer((_) async {
      return ServiceResponse.ok(
        body: depRepo.values.toList(),
      );
    });

    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.create(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Department>;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final uuid = state.value.uuid;
      depRepo[uuid] = state.remote(
        state.value,
        version: state.version,
      );
      return ServiceResponse.ok(
        body: depRepo[uuid],
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Department>;
      final uuid = next.value.uuid;
      if (depRepo.containsKey(uuid)) {
        final state = depRepo[uuid];
        final delta = next.version.value - state.version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        depRepo[uuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: depRepo[uuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Department not found: $uuid",
      );
    });

    when(mock.delete(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Department>;
      final uuid = state.value.uuid;
      if (depRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: depRepo.remove(uuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Department not found: $uuid",
      );
    });
    return mock;
  }
}
