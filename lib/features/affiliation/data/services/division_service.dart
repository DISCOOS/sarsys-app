import 'dart:async';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:chopper/chopper.dart';

import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'division_service.chopper.dart';

/// Service for consuming the organisations endpoint
///
/// Delegates to a ChopperService implementation
class DivisionService extends StatefulServiceDelegate<Division, DivisionModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetList, StatefulGetFromId {
  DivisionService() : delegate = DivisionServiceImpl.newInstance();
  final DivisionServiceImpl delegate;
}

@ChopperApi()
abstract class DivisionServiceImpl extends StatefulService<Division, DivisionModel> {
  DivisionServiceImpl()
      : super(
          decoder: (json) => DivisionModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<DivisionModel>(value, remove: const [
            'organisation',
          ]),
        );

  static DivisionServiceImpl newInstance([ChopperClient client]) => _$DivisionServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Division> state) => create(
        state.value.organisation.uuid,
        state.value,
      );

  @Post(path: '/organisations/{uuid}/divisions')
  Future<Response<String>> create(
    @Path() String uuid,
    @Body() Division body,
  );

  @override
  Future<Response<StorageState<Division>>> onUpdate(StorageState<Division> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '/divisions/{uuid}')
  Future<Response<StorageState<Division>>> update(
    @Path('uuid') String uuid,
    @Body() Division body,
  );

  @override
  Future<Response<StorageState<Division>>> onDelete(StorageState<Division> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '/divisions/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  @override
  Future<Response<PagedList<StorageState<Division>>>> onGetPage(int offset, int limit, List<String> options) => getAll(
        offset,
        limit,
      );

  @Get(path: '/divisions')
  Future<Response<PagedList<StorageState<Division>>>> getAll(
    @Query('offset') int offset,
    @Query('limit') int limit,
  );
}
