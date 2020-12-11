import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'department_service.chopper.dart';

/// Service for consuming the departments endpoint
///
/// Delegates to a ChopperService implementation
class DepartmentService extends StatefulServiceDelegate<Department, DepartmentModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetList, StatefulGetFromId {
  DepartmentService() : delegate = DepartmentServiceImpl.newInstance();
  final DepartmentServiceImpl delegate;
}

@ChopperApi()
abstract class DepartmentServiceImpl extends StatefulService<Department, DepartmentModel> {
  DepartmentServiceImpl()
      : super(
          decoder: (json) => DepartmentModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<DepartmentModel>(value, remove: const [
            'division',
          ]),
        );

  static DepartmentServiceImpl newInstance([ChopperClient client]) => _$DepartmentServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Department> state) => create(
        state.value.division.uuid,
        state.value,
      );

  @Post(path: '/divisions/{uuid}/departments')
  Future<Response<String>> create(
    @Path() String uuid,
    @Body() Department body,
  );

  @override
  Future<Response<StorageState<Department>>> onUpdate(StorageState<Department> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '/departments/{uuid}')
  Future<Response<StorageState<Department>>> update(
    @Path('uuid') String uuid,
    @Body() Department body,
  );

  @override
  Future<Response<StorageState<Department>>> onDelete(StorageState<Department> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '/departments/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  @override
  Future<Response<PagedList<StorageState<Department>>>> onGetPage(int offset, int limit, List<String> options) =>
      getAll(
        offset,
        limit,
      );

  @Get(path: '/departments')
  Future<Response<PagedList<StorageState<Department>>>> getAll(
    @Query('offset') int offset,
    @Query('limit') int limit,
  );
}
