import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'division_service.chopper.dart';

/// Service for consuming the divisions endpoint
///
/// Delegates to a ChopperService implementation
class DivisionService with ServiceFetchAll<Division> implements ServiceDelegate<DivisionServiceImpl> {
  final DivisionServiceImpl delegate;

  DivisionService() : delegate = DivisionServiceImpl.newInstance();

  Future<ServiceResponse<List<Division>>> fetch(int offset, int limit) async {
    return Api.from<PagedList<Division>, List<Division>>(
      await delegate.fetch(offset: offset, limit: limit),
    );
  }

  Future<ServiceResponse<Division>> create(Division division) async {
    return Api.from<String, Division>(
      await delegate.create(
        division.organisation.uuid,
        division,
      ),
      // Created 201 returns uri to created division in body
      body: division,
    );
  }

  Future<ServiceResponse<Division>> update(Division division) async {
    return Api.from<Division, Division>(
      await delegate.update(
        division.uuid,
        division,
      ),
      // Created 201 returns uri to created division in body
      body: division,
    );
  }

  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Division, Division>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi()
abstract class DivisionServiceImpl extends ChopperService {
  static DivisionServiceImpl newInstance([ChopperClient client]) => _$DivisionServiceImpl(client);

  @Post(path: '/organisations/{ouuid}/divisions')
  Future<Response<String>> create(
    @Path() ouuid,
    @Body() Division body,
  );

  @Get(path: '/divisions')
  Future<Response<PagedList<Division>>> fetch({
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 20,
  });

  @Patch(path: '/divisions/{uuid}')
  Future<Response<Division>> update(
    @Path('uuid') String uuid,
    @Body() Division body,
  );

  @Delete(path: '/divisions/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
