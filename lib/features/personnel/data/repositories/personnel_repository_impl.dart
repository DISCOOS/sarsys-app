// @dart=2.11

import 'dart:async';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/stateful_catchup_mixins.dart';
import 'package:SarSys/core/domain/stateful_merge_strategy.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/affiliation/domain/repositories/affiliation_repository.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/features/unit/domain/repositories/unit_repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/utils/data.dart';

class PersonnelRepositoryImpl extends StatefulRepository<String, Personnel, PersonnelService>
    with StatefulCatchup<Personnel, PersonnelService>
    implements PersonnelRepository {
  PersonnelRepositoryImpl(
    PersonnelService service, {
    @required this.units,
    @required this.affiliations,
    @required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
          dependencies: [units, affiliations],
          // Keep person in sync with local copy
          onGet: (StorageState<Personnel> state) {
            if (affiliations.isReady) {
              final value = state.value;
              final auuid = value.affiliation.uuid;
              return state.replace(state.value.copyWith(
                  affiliation: affiliations.get(
                auuid,
              )));
            }
            return state;
          },
          onPut: (StorageState<Personnel> state, bool isDeleted) {
            if (!isDeleted && affiliations.isReady) {
              final affiliation = state.value.affiliation;
              if (affiliation.isAffiliate) {
                affiliations.replace(
                  affiliation,
                  isRemote: state.isRemote,
                );
              }
            }
          },
        ) {
    // Handle messages
    // pushed from backend.
    catchupTo(service.messages);
  }

  /// Get [Operation.uuid]
  String get ouuid => _ouuid;
  String _ouuid;

  /// Get [Unit] repository
  final UnitRepository units;

  /// Get [Affiliation] repository
  final AffiliationRepository affiliations;

  /// Check if repository is operational.
  /// Is true if and only if loaded with
  /// [load] or at least one [Personnel] is
  /// created with [create].
  @override
  bool get isReady => super.isReady && _ouuid != null;

  /// Get [Personnel.uuid] from [value]
  @override
  String toKey(Personnel value) {
    return value?.uuid;
  }

  /// Create [Personnel] from json
  Personnel fromJson(Map<String, dynamic> json) => PersonnelModel.fromJson(json);

  /// Open repository for given [Incident.uuid]
  Future<Iterable<Personnel>> open(String ouuid) async {
    if (isEmptyOrNull(ouuid)) {
      throw ArgumentError('Operation uuid can not be empty or null');
    }
    if (_ouuid != ouuid) {
      await prepare(
        force: true,
        postfix: ouuid,
      );
      _ouuid = ouuid;
    }
    return values;
  }

  /// Get [Personnel] count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  }) =>
      exclude?.isNotEmpty == false
          ? length
          : values
              .where(
                (personnel) => !exclude.contains(personnel.status),
              )
              .length;

  /// Find personnel from user
  Iterable<Personnel> findUser(
    String userId, {
    bool Function(Personnel personnel) where,
    List<PersonnelStatus> exclude: const [PersonnelStatus.retired],
  }) =>
      values
          .where((personnel) => !exclude.contains(personnel.status))
          .where((personnel) => where == null || where(personnel))
          .where((personnel) => personnel.userId == userId);

  /// GET ../personnels
  Future<List<Personnel>> load(
    String ouuid, {
    Completer<Iterable<Personnel>> onRemote,
  }) async {
    await open(ouuid);
    return requestQueue.load(
      () => service.getListFromId(ouuid),
      shouldEvict: true,
      onResult: onRemote,
    );
  }

  /// Unload all devices for given [ouuid]
  Future<List<Personnel>> close() async {
    _ouuid = null;
    return super.close();
  }

  @override
  Future<Iterable<Personnel>> onReset({Iterable<Personnel> previous}) =>
      _ouuid != null ? load(_ouuid) : Future.value(previous);

  @override
  Future<StorageState<Personnel>> onCreate(StorageState<Personnel> state) async {
    assert(state.value.operation.uuid == _ouuid);
    final response = await service.create(state);
    if (response.isOK) {
      return response.body;
    }
    throw PersonnelServiceException(
      'Failed to create Personnel ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Personnel>> onUpdate(StorageState<Personnel> state) async {
    var response = await service.update(state);
    if (response.isOK) {
      return response.body;
    }
    throw PersonnelServiceException(
      'Failed to update Personnel ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Personnel>> onDelete(StorageState<Personnel> state) async {
    var response = await service.delete(state);
    if (response.isOK) {
      return response.body;
    }
    throw PersonnelServiceException(
      'Failed to delete Personnel ${state.value}',
      response: response,
      stackTrace: StackTrace.current,
    );
  }

  @override
  Future<StorageState<Personnel>> onResolve(StorageState<Personnel> state, ServiceResponse response) {
    return MergePersonnelStrategy(this)(
      state,
      response.conflict,
    );
  }
}

class MergePersonnelStrategy extends StatefulMergeStrategy<String, Personnel, PersonnelService> {
  MergePersonnelStrategy(PersonnelRepository repository) : super(repository);

  @override
  PersonnelRepository get repository => super.repository;
  PersonRepository get persons => affiliations.persons;
  AffiliationRepository get affiliations => repository.affiliations;

  @override
  Future<StorageState<Personnel>> onExists(ConflictModel conflict, StorageState<Personnel> state) async {
    switch (conflict.code) {
      case 'duplicate_user_id':
      case 'duplicate_affiliations':
        if (conflict.mine.isNotEmpty) {
          // Duplicates was found, reuse first duplicate
          final existing = AffiliationModel.fromJson(
            conflict.mine.first,
          );

          repository.apply(
            state.value.copyWith(
              affiliation: existing,
            ),
          );

          // Delete duplicate affiliation
          affiliations.remove(
            state.value.affiliation,
          );
        }

        if (conflict.isCode('duplicate_user_id')) {
          // Replace duplicate person with existing person
          repository.apply(
            state.value.withPerson(
              PersonModel.fromJson(conflict.base),
            ),
          );

          // Delete duplicate person
          persons.remove(
            state.value.person,
          );
        }

        return repository.getState(
          repository.toKey(state.value),
        );
    }
    return super.onExists(conflict, state);
  }
}
