import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/tracking/data/services/tracking_source_service.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';

part 'tracking_service.chopper.dart';

/// Service for consuming the trackings endpoint
///
/// Delegates to a ChopperService implementation
class TrackingService with ServiceGetListFromId<Tracking> implements ServiceDelegate<TrackingServiceImpl> {
  TrackingService(
    this.sources,
  ) : delegate = TrackingServiceImpl.newInstance();

  final TrackingServiceImpl delegate;
  final TrackingSourceService sources;

  final StreamController<TrackingMessage> _controller = StreamController.broadcast();

  /// Get stream of tracking messages
  Stream<TrackingMessage> get messages => _controller.stream;

  Future<ServiceResponse<List<Tracking>>> getSubListFromId(String uuid, int offset, int limit) async {
    return Api.from<PagedList<Tracking>, List<Tracking>>(
      await delegate.fetchAll(
        uuid,
        offset,
        limit,
      ),
    );
  }

  /// PATCH ../tracking/{uuid}
  Future<ServiceResponse<Tracking>> update(Tracking tracking) async {
    return Api.from<Tracking, Tracking>(
      await delegate.update(
        tracking.uuid,
        tracking,
      ),
      // Created 201 returns uri to created tracking in body
      body: tracking,
    );
  }

  void dispose() {
    _controller.close();
  }
}

@ChopperApi()
abstract class TrackingServiceImpl extends JsonService<Tracking, TrackingModel> {
  TrackingServiceImpl()
      : super(
          decoder: (json) => TrackingModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<TrackingModel>(value, retain: const [
            'uuid',
            'status',
          ]),
        );
  static TrackingServiceImpl newInstance([ChopperClient client]) => _$TrackingServiceImpl(client);

  @Get(path: '/operations/{ouuid}/trackings')
  Future<Response<PagedList<Tracking>>> fetchAll(
    @Path() ouuid,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('expand') List<String> expand = const [],
  });

  @Patch(path: '/trackings/{uuid}')
  Future<Response<Tracking>> update(
    @Path('uuid') String uuid,
    @Body() Tracking body,
  );
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
