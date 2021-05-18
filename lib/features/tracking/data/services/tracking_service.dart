import 'dart:async';
import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'tracking_service.chopper.dart';

/// Service for consuming trackings endpoint
///
/// Delegates to a ChopperService implementation
class TrackingService extends StatefulServiceDelegate<Tracking, TrackingModel>
    with StatefulUpdate, StatefulGetFromId, StatefulGetListFromId {
  TrackingService(
    this.channel,
  ) : delegate = TrackingServiceImpl.newInstance() {
    // Listen for Device messages
    channel.subscribe('TrackingCreated', _onMessage);
    channel.subscribe('TrackingDeleted', _onMessage);
    channel.subscribe('TrackingPositionChanged', _onMessage);
    channel.subscribe('TrackingInformationUpdated', _onMessage);
  }

  final MessageChannel channel;
  final TrackingServiceImpl delegate;

  final StreamController<TrackingMessage> _controller = StreamController.broadcast();

  /// Get stream of tracking messages
  Stream<TrackingMessage> get messages => _controller.stream;

  void publish(TrackingMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      TrackingMessage(data),
    );
  }

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

enum TrackingMessageType {
  TrackingCreated,
  TrackingDeleted,
  TrackingStatusChanged,
  TrackingInformationUpdated,
}

class TrackingMessage extends MessageModel {
  TrackingMessage(Map<String, dynamic> data) : super(data);

  factory TrackingMessage.created(Tracking tracking) => TrackingMessage.fromType(
        tracking,
        TrackingMessageType.TrackingCreated,
      );

  factory TrackingMessage.updated(Tracking tracking) => TrackingMessage.fromType(
        tracking,
        TrackingMessageType.TrackingInformationUpdated,
      );

  factory TrackingMessage.deleted(Tracking tracking) => TrackingMessage.fromType(
        tracking,
        TrackingMessageType.TrackingDeleted,
      );

  factory TrackingMessage.fromType(Tracking tracking, TrackingMessageType type) => TrackingMessage({
        'type': enumName(type),
        'data': {
          'uuid': tracking.uuid,
          'changed': tracking.toJson(),
        },
      });

  TrackingMessageType get type {
    final type = data.elementAt('type');
    return TrackingMessageType.values.singleWhere((e) => enumName(e) == type, orElse: () => null);
  }
}
