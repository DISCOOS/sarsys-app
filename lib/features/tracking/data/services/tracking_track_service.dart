import 'dart:async';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/data/models/tracking_track_model.dart';
import 'package:SarSys/features/tracking/data/services/position_list_service.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'tracking_track_service.chopper.dart';

/// Service for consuming the Tracks endpoint
///
/// Delegates to a ChopperService implementation
class TrackingTrackService extends StatefulServiceDelegate<TrackingTrack, TrackingTrackModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetFromId, StatefulGetListFromId {
  TrackingTrackService(
    this.positions,
  ) : delegate = TrackingTrackServiceImpl.newInstance();

  final TrackingTrackServiceImpl delegate;
  final PositionListService positions;
}

@ChopperApi(baseUrl: '/trackings')
abstract class TrackingTrackServiceImpl extends StatefulService<TrackingTrack, TrackingTrackModel> {
  TrackingTrackServiceImpl()
      : super(
          decoder: (json) => TrackingTrackModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<TrackingTrack>(value),
        );
  static TrackingTrackServiceImpl newInstance([ChopperClient client]) => _$TrackingTrackServiceImpl(client);

  @override
  Future<Response<StorageState<TrackingTrack>>> onGetFromIds(List<String> ids, {List<String> options = const []}) =>
      get(ids[0], ids[1]);

  @Get(path: '/{uuid}/tracks/{id}')
  Future<Response<StorageState<TrackingTrack>>> get(
    @Path() uuid,
    @Path() id,
  );

  @override
  Future<Response<PagedList<StorageState<TrackingTrack>>>> onGetPageFromId(
    String id,
    int offset,
    int limit,
    List<String> options,
  ) =>
      getAll(id, offset, limit);

  @Get(path: '/{uuid}/tracks')
  Future<Response<PagedList<StorageState<TrackingTrack>>>> getAll(
    @Path() uuid,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('expand') List<String> expand = const [],
  });
}
