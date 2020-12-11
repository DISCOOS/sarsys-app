import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'unit_service.chopper.dart';

/// Service for consuming the units endpoint
///
/// Delegates to a ChopperService implementation
class UnitService extends StatefulServiceDelegate<Unit, UnitModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetListFromId {
  final UnitServiceImpl delegate;

  UnitService() : delegate = UnitServiceImpl.newInstance();
}

@ChopperApi()
abstract class UnitServiceImpl extends StatefulService<Unit, UnitModel> {
  UnitServiceImpl()
      : super(
          decoder: (json) => UnitModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<UnitModel>(value),
        );
  static UnitServiceImpl newInstance([ChopperClient client]) => _$UnitServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Unit> state) => create(
        state.value.operation.uuid,
        state.value,
      );

  @Post(path: '/operations/{ouuid}/units')
  Future<Response<String>> create(
    @Path('ouuid') ouuid,
    @Body() Unit body,
  );

  @override
  Future<Response<StorageState<Unit>>> onUpdate(StorageState<Unit> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: 'units/{uuid}')
  Future<Response<StorageState<Unit>>> update(
    @Path('uuid') String uuid,
    @Body() Unit personnel,
  );

  @override
  Future<Response<StorageState<Unit>>> onDelete(StorageState<Unit> state) => delete(
        state.value.uuid,
      );

  @Delete(path: 'units/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  @Get(path: '/operations/{ouuid}/units')
  Future<Response<PagedList<StorageState<Unit>>>> onGetPageFromId(
    @Path('ouuid') String id,
    @Query('offset') int offset,
    @Query('limit') int limit,
    List<String> options,
  );
}
