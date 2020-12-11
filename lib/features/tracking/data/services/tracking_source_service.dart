import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/tracking/data/models/tracking_source_model.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingSource.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'tracking_source_service.chopper.dart';

/// Service for consuming the Sources endpoint
///
/// Delegates to a ChopperService implementation
class TrackingSourceService extends StatefulServiceDelegate<TrackingSource, TrackingSourceModel>
    with StatefulCreateWithId, StatefulUpdateWithIds, StatefulDeleteWithIds, StatefulGetFromId, StatefulGetListFromId {
  TrackingSourceService() : delegate = TrackingSourceServiceImpl.newInstance();
  final TrackingSourceServiceImpl delegate;
}

@ChopperApi()
abstract class TrackingSourceServiceImpl extends StatefulService<TrackingSource, TrackingSourceModel> {
  TrackingSourceServiceImpl()
      : super(
          decoder: (json) => TrackingSourceModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<TrackingSourceModel>(value),
        );
  static TrackingSourceServiceImpl newInstance([ChopperClient client]) => _$TrackingSourceServiceImpl(client);

  @override
  Future<Response<String>> onCreateWithId(String id, StorageState<TrackingSource> state) => create(
        id,
        state.value,
      );

  @Post(path: '/trackings/{tuuid}/sources')
  Future<Response<String>> create(
    @Path() tuuid,
    @Body() TrackingSource body,
  );

  @override
  Future<Response<StorageState<TrackingSource>>> onDeleteWithIds(List<String> ids, _) => delete(ids[0], ids[1]);

  @Delete(path: '/trackings/{tuuid}/sources/{suuid}')
  Future<Response<void>> delete(
    @Path('uuid') String tuuid,
    @Path('uuid') String suuid,
  );

  Future<Response<StorageState<TrackingSource>>> onGetFromIds(
    List<String> ids, {
    List<String> options = const [],
  }) =>
      get(ids[0], ids[1]);

  @Get(path: '/trackings/{tuuid}/sources/{suuid}')
  Future<Response<StorageState<TrackingSource>>> get(
    @Path() tuuid,
    @Path() suuid,
  );

  @override
  Future<Response<PagedList<StorageState<TrackingSource>>>> onGetPageFromId(
    String id,
    int offset,
    int limit,
    List<String> options,
  ) =>
      getAll(id, offset, limit);

  @Get(path: '/trackings/{tuuid}/sources')
  Future<Response<PagedList<StorageState<TrackingSource>>>> getAll(
    @Path() tuuid,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('expand') List<String> expand = const [],
  });
}
