import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'tracking_track_positions_service.chopper.dart';

/// Service for consuming the Tracks endpoint
///
/// Delegates to a ChopperService implementation
class TrackingTrackPositionsService
    with ServiceGetListFromIds<Position>
    implements ServiceDelegate<TrackingTrackPositionsServiceImpl> {
  final TrackingTrackPositionsServiceImpl delegate;

  TrackingTrackPositionsService() : delegate = TrackingTrackPositionsServiceImpl.newInstance();

  /// Fetch [TrackingTrack]s for given [Tracking] uuid.
  Future<ServiceResponse<List<Position>>> getSubListFromIds(
    String tuuid,
    String suuid,
    int offset,
    int limit, {
    @Query('option') List<String> options = const ['truncate:-20:m'],
  }) async {
    return Api.from<PagedList<Position>, List<Position>>(
      await delegate.getPositions(
        tuuid,
        suuid,
        offset,
        limit,
        options: options,
      ),
    );
  }
}

@ChopperApi()
abstract class TrackingTrackPositionsServiceImpl extends JsonService<Position, Position> {
  TrackingTrackPositionsServiceImpl()
      : super(
          decoder: (json) => Position.fromJson(json),
          reducer: (value) => JsonUtils.toJson<Position>(value),
        );
  static TrackingTrackPositionsServiceImpl newInstance([ChopperClient client]) =>
      _$TrackingTrackPositionsServiceImpl(client);

  @Get(path: '/trackings/{uuid}/tracks/{id}')
  Future<Response<PagedList<Position>>> getPositions(
    @Path() uuid,
    @Path() id,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('option') List<String> options = const ['truncate:-20:m'],
  });
}
