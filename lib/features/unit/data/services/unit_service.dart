import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/core/service.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'unit_service.chopper.dart';

/// Service for consuming the units endpoint
///
/// Delegates to a ChopperService implementation
class UnitService with ServiceFetchDescendants<Unit> implements ServiceDelegate<UnitServiceImpl> {
  final UnitServiceImpl delegate;

  UnitService() : delegate = UnitServiceImpl.newInstance();

  /// GET ../units
  Future<ServiceResponse<List<Unit>>> fetch(String ouuid, int offset, int limit) async {
    return Api.from<PagedList<Unit>, List<Unit>>(
      await delegate.fetch(
        ouuid,
        offset,
        limit,
      ),
    );
  }

  /// POST ../units
  Future<ServiceResponse<Unit>> create(String ouuid, Unit unit) async {
    return Api.from<String, Unit>(
      await delegate.create(
        ouuid,
        unit,
      ),
      // Created 201 returns uri to created personnel in body
      body: unit,
    );
  }

  /// PUT ../units/{unitId}
  Future<ServiceResponse<Unit>> update(Unit unit) async {
    return Api.from<Unit, Unit>(
      await delegate.update(
        unit.uuid,
        unit,
      ),
      body: unit,
    );
  }

  /// DELETE ../units/{unitId}
  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Unit, Unit>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi()
abstract class UnitServiceImpl extends ChopperService {
  static UnitServiceImpl newInstance([ChopperClient client]) => _$UnitServiceImpl(client);

  @Post(path: '/operations/{uuid}/units')
  Future<Response<String>> create(
    @Path() ouuid,
    @Body() Unit body,
  );

  @Get(path: '/operations/{ouuid}/units')
  Future<Response<PagedList<Unit>>> fetch(
    @Path() ouuid,
    @Query('offset') int offset,
    @Query('limit') int limit,
  );

  @Patch(path: 'units/{uuid}')
  Future<Response<Unit>> update(
    @Path('uuid') String uuid,
    @Body() Unit unit,
  );

  @Delete(path: 'units/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
