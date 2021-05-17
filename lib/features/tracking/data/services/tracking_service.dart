import 'dart:async';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';

part 'tracking_service.chopper.dart';

/// Service for consuming the trackings endpoint
///
/// Delegates to a ChopperService implementation
class TrackingService extends StatefulServiceDelegate<Tracking, TrackingModel>
    with StatefulUpdate, StatefulGetFromId, StatefulGetListFromId {
  TrackingService() : delegate = TrackingServiceImpl.newInstance();

  final TrackingServiceImpl delegate;

  final StreamController<TrackingMessage> _controller = StreamController.broadcast();

  /// Get stream of tracking messages
  Stream<TrackingMessage> get messages => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

@ChopperApi()
abstract class TrackingServiceImpl extends StatefulService<Tracking, TrackingModel> {
  TrackingServiceImpl()
      : super(
          decoder: (json) => TrackingModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<TrackingModel>(value, retain: const [
            'uuid',
            'sources',
          ]),
        );
  static TrackingServiceImpl newInstance([ChopperClient client]) => _$TrackingServiceImpl(client);

  @override
  Future<Response<StorageState<Tracking>>> onUpdate(StorageState<Tracking> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '/trackings/{uuid}')
  Future<Response<StorageState<Tracking>>> update(
    @Path('uuid') String uuid,
    @Body() Tracking body,
  );

  @override
  Future<Response<StorageState<Tracking>>> onGetFromId(
    String id, {
    List<String> options = const [],
  }) =>
      get(id, expand: options);

  @Get(path: '/trackings/{uuid}')
  Future<Response<StorageState<Tracking>>> get(
    @Path() uuid, {
    @Query('expand') List<String> expand = const [],
  });

  @override
  Future<Response<PagedList<StorageState<Tracking>>>> onGetPageFromId(
          String id, int offset, int limit, List<String> options) =>
      getAll(id, offset, limit);

  @Get(path: '/operations/{ouuid}/trackings')
  Future<Response<PagedList<StorageState<Tracking>>>> getAll(
    @Path('ouuid') ouuid,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('expand') List<String> expand = const [],
  });
}

enum TrackingMessageType { created, updated, deleted }

class TrackingMessage {
  final String uuid;
  final TrackingMessageType type;
  final Map<String, dynamic> json;
  TrackingMessage(this.uuid, this.type, this.json);

  factory TrackingMessage.from(
    Tracking tracking, {
    @required TrackingMessageType type,
  }) =>
      TrackingMessage(
        tracking.uuid,
        type,
        tracking.toJson(),
      );

  factory TrackingMessage.created(Tracking tracking) => TrackingMessage(
        tracking.uuid,
        TrackingMessageType.created,
        tracking.toJson(),
      );

  factory TrackingMessage.updated(Tracking tracking) => TrackingMessage(
        tracking.uuid,
        TrackingMessageType.updated,
        tracking.toJson(),
      );
  factory TrackingMessage.deleted(Tracking tracking) => TrackingMessage(
        tracking.uuid,
        TrackingMessageType.deleted,
        tracking.toJson(),
      );
}
