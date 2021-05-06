import 'dart:async';
import 'dart:convert';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:faker/faker.dart' as random;
import 'package:uuid/uuid.dart';

import 'affiliation_service_mock.dart';

class PersonnelBuilder {
  static Personnel create({
    String uuid,
    String ouuid,
    String puuid,
    String auuid,
    String tuuid,
    String userId,
    PersonnelStatus status = PersonnelStatus.alerted,
  }) {
    return PersonnelModel.fromJson(
      createAsJson(
        auuid: auuid,
        puuid: puuid,
        tuuid: tuuid,
        userId: userId,
        uuid: uuid ?? Uuid().v4(),
        ouuid: ouuid ?? Uuid().v4(),
        status: status ?? PersonnelStatus.alerted,
      ),
    );
  }

  static Map<String, dynamic> createAsJson({
    @required String uuid,
    @required String ouuid,
    @required PersonnelStatus status,
    String puuid,
    String auuid,
    String tuuid,
    String userId,
  }) =>
      json.decode('{'
          '"uuid": "$uuid",'
          '"status": "${enumName(status)}",'
          '"affiliation": {'
          '"uuid": "${auuid ?? Uuid().v4()}",'
          '"person": {'
          '"uuid": "${puuid ?? Uuid().v4()}", '
          '"fname": "${random.faker.person.firstName()}",'
          '"lname": "${random.faker.person.lastName()}",'
          '"userId": "$userId"'
          '}},'
          '"function": "${enumName(OperationalFunctionType.personnel)}",'
          '"operation": {"uuid": "${ouuid ?? Uuid().v4()}", "type": "Operation"},'
          '"tracking": {"uuid": "${tuuid ?? Uuid().v4()}", "type": "Personnel"}'
          '}');
}

class PersonnelServiceMock extends Mock implements PersonnelService {
  PersonnelServiceMock();
  final Map<String, Map<String, StorageState<Personnel>>> personnelsRepo = {};

  Personnel add(
    String ouuid, {
    String uuid,
    String auuid,
    String tuuid,
    PersonnelStatus status = PersonnelStatus.alerted,
  }) {
    final personnel = PersonnelBuilder.create(
      uuid: uuid,
      ouuid: ouuid,
      auuid: auuid,
      tuuid: tuuid,
      status: status,
    );
    final state = StorageState.created(
      personnel,
      StateVersion.first,
      isRemote: true,
    );
    if (personnelsRepo.containsKey(ouuid)) {
      personnelsRepo[ouuid].putIfAbsent(personnel.uuid, () => state);
    } else {
      personnelsRepo[ouuid] = {personnel.uuid: state};
    }
    return personnel;
  }

  List<StorageState<Personnel>> remove(String uuid) {
    final ouuids = personnelsRepo.entries.where(
      (entry) => entry.value.containsKey(uuid),
    );
    return ouuids
        .map((ouuid) => personnelsRepo[ouuid].remove(uuid))
        .where(
          (personnel) => personnel != null,
        )
        .toList();
  }

  factory PersonnelServiceMock.build(
    final int count,
    AffiliationServiceMock affiliations, {
    List<String> ouuids = const [],
  }) {
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
              StorageState.created(
                PersonnelModel.fromJson(
                  PersonnelBuilder.createAsJson(
                    ouuid: ouuid,
                    uuid: "$ouuid:p:$i",
                    userId: "p:$i",
                    status: PersonnelStatus.alerted,
                    tuuid: "$ouuid:t:p:$i",
                  ),
                ),
                StateVersion.first,
                isRemote: true,
              ),
            ),
        ]);
      }
    });

    // ignore: close_sinks
    final StreamController<PersonnelMessage> controller = StreamController.broadcast();

    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.getListFromId(any)).thenAnswer((_) async {
      final String ouuid = _.positionalArguments[0];
      var personnelRepo = personnelsRepo[ouuid];
      if (personnelRepo == null) {
        personnelRepo = personnelsRepo.putIfAbsent(ouuid, () => {});
      }
      return ServiceResponse.ok(
        body: personnelRepo.values.toList(growable: false),
      );
    });

    when(mock.create(any)).thenAnswer((_) async {
      var state = _.positionalArguments[0] as StorageState<Personnel>;
      final ouuid = state.value.operation.uuid;
      if (!state.version.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final personnel = state.value;
      final affiliation = personnel.affiliation;
      if (affiliation.isAffiliate) {
        final remote = affiliations.affiliationRepo[affiliation.uuid] ??
            StorageState.created(
              affiliation,
              StateVersion.first,
            );
        final response = await affiliations.create(remote.replace(
          affiliation,
        ));
        if (response.statusCode >= 400) {
          return response.copyWith(
            error: response.error,
            conflict: response.conflict,
            statusCode: response.statusCode,
            reasonPhrase: response.reasonPhrase,
          );
        }
        state = state.replace(state.value.copyWith(
          affiliation: remote.value,
        ));
      }
      final personnelRepo = personnelsRepo.putIfAbsent(ouuid, () => {});
      final String puuid = personnel.uuid;
      personnelRepo[puuid] = state.remote(
        personnel.copyWith(
          operation: state.value.operation,
        ),
        version: state.version,
      );
      return ServiceResponse.ok(
        body: personnelRepo[puuid],
      );
    });

    when(mock.update(any)).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Personnel>;
      final personnel = next.value;
      final puuid = personnel.uuid;
      final ouuid = personnel.operation.uuid;
      final personnelRepo = personnelsRepo.putIfAbsent(ouuid, () => {});
      if (personnelRepo.containsKey(puuid)) {
        final state = personnelRepo[puuid];
        final delta = next.version.value - state.version.value;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version + 1}, actual was ${next.version}",
          );
        }
        personnelRepo[puuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: personnelRepo[puuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Personnel not found: $puuid",
      );
    });

    when(mock.delete(any)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Personnel>;
      final personnel = state.value;
      final puuid = personnel.uuid;
      final ouuid = personnel.operation.uuid;
      final personnelRepo = personnelsRepo.putIfAbsent(ouuid, () => {});
      if (personnelRepo.containsKey(puuid)) {
        return ServiceResponse.ok(
          body: personnelRepo.remove(puuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Personnel not found: $puuid",
      );
    });

    return mock;
  }
}
