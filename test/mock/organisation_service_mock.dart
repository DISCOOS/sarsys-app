import 'dart:convert';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/services/organisation_service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/data/services/service.dart';

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
  final Map<String, StorageState<Organisation>> orgRepo = {};

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
    final state = StorageState.created(
      org,
      StateVersion.first,
      isRemote: true,
    );

    orgRepo[org.uuid] = state;
    return org;
  }

  StorageState<Organisation> remove(String uuid) {
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
        orgRepo[uuid] = StorageState.created(
          org,
          StateVersion.first,
          isRemote: true,
        );
      }
    });

    when(mock.getList()).thenAnswer((_) async {
      return ServiceResponse.ok(
        body: orgRepo.values.toList(),
      );
    });
    when(mock.create(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Organisation>;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final uuid = state.value.uuid;
      orgRepo[uuid] = state.remote(
        state.value,
        version: state.version,
      );
      return ServiceResponse.ok(
        body: orgRepo[uuid],
      );
    });
    when(mock.update(any)).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Organisation>;
      final uuid = next.value.uuid;
      if (orgRepo.containsKey(uuid)) {
        final state = orgRepo[uuid];
        final delta = next.version.value - state.version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        orgRepo[uuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: orgRepo[uuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Organisation not found: $uuid",
      );
    });
    when(mock.delete(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Organisation>;
      final uuid = state.value.uuid;
      if (orgRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: orgRepo.remove(uuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Organisation not found: $uuid",
      );
    });
    return mock;
  }
}
