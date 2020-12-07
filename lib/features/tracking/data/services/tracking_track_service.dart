import 'dart:async';
import 'package:SarSys/core/data/api.dart';
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
class TrackingTrackService
    with ServiceGetFromIds<TrackingTrack>, ServiceGetListFromId<TrackingTrack>
    implements ServiceDelegate<TrackingTrackServiceImpl> {
  TrackingTrackService(
    this.positions,
  ) : delegate = TrackingTrackServiceImpl.newInstance();

  final TrackingTrackServiceImpl delegate;
  final PositionListService positions;

  /// Fetch [TrackingTrack]s for given [Tracking] uuid.
  Future<ServiceResponse<List<TrackingTrack>>> getSubListFromId(
    String tuuid,
    int offset,
    int limit,
    List<String> options,
  ) async {
    return Api.from<PagedList<TrackingTrack>, List<TrackingTrack>>(
      await delegate.fetchAll(
        tuuid,
        offset,
        limit,
      ),
    );
  }

  @override
  Future<ServiceResponse<TrackingTrack>> getFromIds(String suuid, String id) async {
    return Api.from<TrackingTrack, TrackingTrack>(await delegate.get(
      suuid,
      id,
    ));
  }
}

@ChopperApi()
abstract class TrackingTrackServiceImpl extends JsonService<TrackingTrack, TrackingTrackModel> {
  TrackingTrackServiceImpl()
      : super(
          decoder: (json) => TrackingTrackModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<TrackingTrack>(value),
        );
  static TrackingTrackServiceImpl newInstance([ChopperClient client]) => _$TrackingTrackServiceImpl(client);

  @Get(path: '/trackings/{uuid}/tracks/{id}')
  Future<Response<TrackingTrack>> get(
    @Path() uuid,
    @Path() id,
  );

  @Get(path: '/trackings/{uuid}/tracks')
  Future<Response<PagedList<TrackingTrack>>> fetchAll(
    @Path() uuid,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('expand') List<String> expand = const [],
  });
}
