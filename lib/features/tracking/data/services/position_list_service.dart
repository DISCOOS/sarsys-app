import 'dart:async';

import 'package:SarSys/features/tracking/data/models/position_list_model.dart';
import 'package:SarSys/features/tracking/domain/entities/PositionList.dart';
import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';

part 'position_list_service.chopper.dart';

/// Service for consuming the Tracks endpoint
///
/// Delegates to a ChopperService implementation
class PositionListService extends StatefulServiceDelegate<PositionList, PositionListModel> with StatefulGetFromIds {
  final PositionListServiceImpl delegate;

  PositionListService() : delegate = PositionListServiceImpl.newInstance();
}

@ChopperApi()
abstract class PositionListServiceImpl extends StatefulService<PositionList, PositionListModel> {
  PositionListServiceImpl()
      : super(
          // Map
          decoder: (json) => PositionListModel.fromJson({
            'features': json['entries'],
          }),
          reducer: (value) => JsonUtils.toJson<Position>(value),
        );
  static PositionListServiceImpl newInstance([ChopperClient client]) => _$PositionListServiceImpl(client);

  @override
  Future<Response<StorageState<PositionList>>> onGetFromIds(
    List<String> ids, {
    List<String> options = const [],
  }) async {
    final suuid = ids[1];
    final response = await getAll(ids[0], suuid, options: options);
    final state = response.body;
    return response.copyWith(
      body: state.replace(
        state.value.cloneWith(id: suuid),
      ),
    );
  }

  @Get(path: '/trackings/{tuuid}/tracks/{suuid}')
  Future<Response<StorageState<PositionList>>> getAll(
    @Path() tuuid,
    @Path() suuid, {
    @Query('offset') int offset,
    @Query('limit') int limit,
    @Query('option') List<String> options = const ['truncate:-20:m'],
  });
}
