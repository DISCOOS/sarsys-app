import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/data/models/tracking_source_model.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingSource.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'tracking_source_service.chopper.dart';

/// Service for consuming the Sources endpoint
///
/// Delegates to a ChopperService implementation
class TrackingSourceService
    with ServiceGetFromIds<TrackingSource>, ServiceGetListFromId<TrackingSource>
    implements ServiceDelegate<TrackingSourceServiceImpl> {
  TrackingSourceService() : delegate = TrackingSourceServiceImpl.newInstance();
  final TrackingSourceServiceImpl delegate;

  /// Fetch [TrackingSource]s for given [Tracking] uuid.
  Future<ServiceResponse<List<TrackingSource>>> getSubListFromId(
    String tuuid,
    int offset,
    int limit,
    List<String> options,
  ) async {
    return Api.from<PagedList<TrackingSource>, List<TrackingSource>>(
      await delegate.fetchAll(
        tuuid,
        offset,
        limit,
      ),
    );
  }

  @override
  Future<ServiceResponse<TrackingSource>> getFromIds(String tuuid, String suuid) async {
    return Api.from<TrackingSource, TrackingSource>(await delegate.get(
      tuuid,
      suuid,
    ));
  }

  Future<ServiceResponse<TrackingSource>> create(String tuuid, TrackingSource source) async {
    return Api.from<String, TrackingSource>(
      await delegate.create(
        tuuid,
        source,
      ),
      // Created 201 returns uri to created source in body
      body: source,
    );
  }

  Future<ServiceResponse<void>> delete(String tuuid, String suuid) async {
    return Api.from<TrackingSource, TrackingSource>(await delegate.delete(
      tuuid,
      suuid,
    ));
  }
}

@ChopperApi()
abstract class TrackingSourceServiceImpl extends JsonService<TrackingSource, TrackingSourceModel> {
  TrackingSourceServiceImpl()
      : super(
          decoder: (json) => TrackingSourceModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<TrackingSourceModel>(value),
        );
  static TrackingSourceServiceImpl newInstance([ChopperClient client]) => _$TrackingSourceServiceImpl(client);

  @Get(path: '/trackings/{tuuid}/sources/{suuid}')
  Future<Response<TrackingSource>> get(
    @Path() tuuid,
    @Path() suuid,
  );

  @Get(path: '/trackings/{tuuid}/sources')
  Future<Response<PagedList<TrackingSource>>> fetchAll(
    @Path() tuuid,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('expand') List<String> expand = const [],
  });

  @Post(path: '/trackings/{tuuid}/sources')
  Future<Response<String>> create(
    @Path() tuuid,
    @Body() TrackingSource body,
  );

  @Delete(path: '/trackings/{tuuid}/sources/{suuid}')
  Future<Response<void>> delete(
    @Path('uuid') String tuuid,
    @Path('uuid') String suuid,
  );
}
