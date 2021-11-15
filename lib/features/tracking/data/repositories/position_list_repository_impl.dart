

import 'dart:async';
import 'dart:io';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/tracking/data/models/position_list_model.dart';
import 'package:SarSys/features/tracking/data/services/position_list_service.dart';
import 'package:SarSys/features/tracking/domain/entities/PositionList.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/features/tracking/domain/repositories/position_list_repository.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';

class PositionListRepositoryImpl extends StatefulRepository<String?, PositionList, PositionListService>
    implements PositionListRepository {
  PositionListRepositoryImpl(
    PositionListService service, {
    required ConnectivityService connectivity,
  }) : super(
          service: service,
          connectivity: connectivity,
        );

  @override
  String? toKey(PositionList? value) {
    return value?.id;
  }

  /// Map for efficient tracking lookup from [Source.uuid]
  final _sources = <String?, Set<String?>>{};

  /// Create [PositionList] from json
  PositionList fromJson(Map<String, dynamic>? json) => PositionListModel.fromJson(json!);

  @override
  Iterable<PositionList> find({bool where(PositionList list)?}) => isReady ? values.where(where!) : [];

  @override
  Future<int> init({Map<String, List<TrackingTrack>>? tracks}) async {
    await prepare(
      force: true,
    );
    (tracks?.entries ?? {}).forEach((tracks) {
      tracks.value.forEach((track) {
        put(
          StorageState.created(
            PositionListModel(
              id: track.source.uuid,
              features: track.positions,
            ),
            StateVersion.first,
            isRemote: true,
          ),
        );
        _sources.clear();
        _sources.update(
          tracks.key,
          (sources) => sources..add(track.source.uuid),
          ifAbsent: () => {track.source.uuid},
        );
      });
    });
    return length;
  }

  @override
  Future<Iterable<PositionList?>> fetch(
    String tuuid, {
    bool replace = false,
    Iterable<String?>? suuids,
    List<String> options = const ['truncate:-20:m'],
    Completer<Iterable<PositionList>>? onRemote,
  }) async {
    await prepare();
    return _fetch(
      tuuid,
      suuids,
      replace: replace,
      options: options,
      onRemote: onRemote,
    );
  }

  Future<List<PositionList?>> _fetch(
    String? tuuid,
    Iterable<String?>? suuids, {
    bool replace = false,
    List<String> options = const ['truncate:-20:m'],
    Completer<Iterable<PositionList>>? onRemote,
  }) async {
    return requestQueue!.load(
      () async {
        final errors = <ServiceResponse>[];
        final List<StorageState<PositionList>?> values = <StorageState<PositionList>?>[];
        if (replace) {
          _sources.clear();
        }
        for (var suuid in suuids!) {
          // Do not attempt to load local values
          final state = getState(suuid);
          if (state == null || state.shouldLoad) {
            final ServiceResponse<StorageState<PositionList>> response = await service.getFromIds(
              [tuuid, suuid],
              options: options,
            );
            if (response != null) {
              if (response.is200) {
                values.add(response.body);
              } else {
                errors.add(response);
              }
            }
          } else {
            values.add(state);
          }
          _sources.update(
            suuid,
            (tuuids) => tuuids..add(suuid),
            ifAbsent: () => {suuid},
          );
        }
        if (errors.isNotEmpty) {
          return ServiceResponse<List<StorageState<PositionList>?>>(
            body: values,
            error: errors,
            statusCode: values.isNotEmpty ? HttpStatus.partialContent : errors.first.statusCode,
            reasonPhrase: values.isNotEmpty ? 'Partial fetch failure' : 'Fetch failed',
          );
        }
        return ServiceResponse.ok(
          body: values,
        );
      },
      onResult: onRemote,
      shouldEvict: replace,
    ) as FutureOr<List<PositionList?>>;
  }

  @override
  Future<Iterable<PositionList>> onReset({Iterable<PositionList>? previous = const []}) async {
    _sources.forEach((tuuid, suuids) async {
      await _fetch(
        tuuid,
        suuids,
        replace: true,
      );
    });
    return values;
  }
}
