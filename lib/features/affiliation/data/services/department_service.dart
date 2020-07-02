import 'dart:async';

import 'package:SarSys/core/service.dart';
import 'package:chopper/chopper.dart';

import 'package:SarSys/core/api.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/services/service.dart';

part 'department_service.chopper.dart';

/// Service for consuming the departments endpoint
///
/// Delegates to a ChopperService implementation
class DepartmentService with ServiceFetchAll<Department> implements ServiceDelegate<DepartmentServiceImpl> {
  final DepartmentServiceImpl delegate;

  DepartmentService() : delegate = DepartmentServiceImpl.newInstance();

  Future<ServiceResponse<List<Department>>> fetch(int offset, int limit) async {
    return Api.from<PagedList<Department>, List<Department>>(
      await delegate.fetch(offset: offset, limit: limit),
    );
  }

  Future<ServiceResponse<Department>> create(Department department) async {
    return Api.from<String, Department>(
      await delegate.create(
        department.division.uuid,
        department,
      ),
      // Created 201 returns uri to created department in body
      body: department,
    );
  }

  Future<ServiceResponse<Department>> update(Department department) async {
    return Api.from<Department, Department>(
      await delegate.update(
        department.uuid,
        department,
      ),
      // Created 201 returns uri to created department in body
      body: department,
    );
  }

  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Department, Department>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi()
abstract class DepartmentServiceImpl extends ChopperService {
  static DepartmentServiceImpl newInstance([ChopperClient client]) => _$DepartmentServiceImpl(client);

  @Post(path: '/divisions/{duuid}/departments')
  Future<Response<String>> create(
    @Path() String duuid,
    @Body() Department body,
  );

  @Get(path: '/departments')
  Future<Response<PagedList<Department>>> fetch({
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 20,
  });

  @Patch(path: '/departments/{uuid}')
  Future<Response<Department>> update(
    @Path('uuid') String uuid,
    @Body() Department body,
  );

  @Delete(path: '/departments/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
