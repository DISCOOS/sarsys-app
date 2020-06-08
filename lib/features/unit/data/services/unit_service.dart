import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'unit_service.chopper.dart';

/// Service for consuming the units endpoint
///
/// Delegates to a ChopperService implementation
class UnitService {
  final UnitServiceImpl delegate;

  UnitService() : delegate = UnitServiceImpl.newInstance();

  /// GET ../units
  Future<ServiceResponse<List<Unit>>> fetch(String ouuid) async {
    return Api.from<List<Unit>, List<Unit>>(
      await delegate.fetch(),
    );
  }

  /// POST ../units
  Future<ServiceResponse<Unit>> create(String ouuid, Unit unit) async {
    return Api.from<String, Unit>(
      await delegate.create(
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

@ChopperApi(baseUrl: '/units')
abstract class UnitServiceImpl extends ChopperService {
  static UnitServiceImpl newInstance([ChopperClient client]) => _$UnitServiceImpl(client);

  /// Initializes configuration to default values for given version.
  ///
  /// POST /units/{version}
  @Post()
  Future<Response<String>> create(
    @Body() Unit unit,
  );

  /// GET /units
  @Get()
  Future<Response<List<Unit>>> fetch();

  /// PATCH ../units/{uuid}
  @Patch(path: "{uuid}")
  Future<Response<Unit>> update(
    @Path('uuid') String uuid,
    @Body() Unit config,
  );

  /// DELETE ../units/{uuid}
  @Delete(path: "{uuid}")
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
