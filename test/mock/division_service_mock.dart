import 'dart:convert';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/services/division_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/services/service.dart';

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
        '"departments": [${departments != null ? '"${departments.join("','")}"' : ''}]'
        '}');
  }
}

class DivisionServiceMock extends Mock implements DivisionService {
  final Map<String, StorageState<Division>> divRepo = {};

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
    divRepo[div.uuid] = StorageState.created(
      div,
      StateVersion.first,
      isRemote: true,
    );
    ;
    return div;
  }

  StorageState<Division> remove(String uuid) {
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
          divRepo[divuuid] = StorageState.created(
            div,
            StateVersion.first,
            isRemote: true,
          );
        }
      }
    });

    when(mock.getList()).thenAnswer((_) async {
      return ServiceResponse.ok(
        body: divRepo.values.toList(),
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Division>;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Division has not version 0: $state",
        );
      }
      final uuid = state.value.uuid;
      divRepo[uuid] = state.remote(
        state.value,
        version: state.version,
      );
      return ServiceResponse.ok(
        body: divRepo[uuid],
      );
    });
    when(mock.update(any)).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Division>;
      final uuid = next.value.uuid;
      if (divRepo.containsKey(uuid)) {
        final state = divRepo[uuid];
        final delta = next.version.value - state.version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        divRepo[uuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: divRepo[uuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Division not found: $uuid",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Division>;
      final uuid = state.value.uuid;
      if (divRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: divRepo.remove(uuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Division not found: $uuid",
      );
    });
    return mock;
  }
}
