import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/core/service.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'operation_service.chopper.dart';

/// Service for consuming the operations endpoint
///
/// Delegates to a ChopperService implementation
class OperationService with ServiceFetchAll<Operation> implements ServiceDelegate<OperationServiceImpl> {
  final OperationServiceImpl delegate;

  OperationService() : delegate = OperationServiceImpl.newInstance();

  Future<ServiceResponse<List<Operation>>> fetch(int offset, int limit) async {
    return Api.from<PagedList<Operation>, List<Operation>>(
      await delegate.fetch(
        offset: offset,
        limit: limit,
      ),
    );
  }

  /// POST ../operations
  Future<ServiceResponse<Operation>> create(Operation operation) async {
    return Api.from<String, Operation>(
      await delegate.create(
        operation.incident.uuid,
        operation,
      ),
      // Created 201 returns uri to created operation in body
      body: operation,
    );
  }

  /// PUT ../operations/{ouuid}
  Future<ServiceResponse<Operation>> update(Operation operation) async {
    return Api.from<Operation, Operation>(
      await delegate.update(
        operation.uuid,
        operation,
      ),
      // Created 201 returns uri to created operation in body
      body: operation,
    );
  }

  /// DELETE ../operations/{ouuid}
  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Operation, Operation>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi()
abstract class OperationServiceImpl extends ChopperService {
  static OperationServiceImpl newInstance([ChopperClient client]) => _$OperationServiceImpl(client);

  @Post(path: '/incidents/{iuuid}/operations')
  Future<Response<String>> create(
    @Path() iuuid,
    @Body() Operation body,
  );

  @Get(path: '/operations')
  Future<Response<PagedList<Operation>>> fetch({
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 20,
  });

  @Patch(path: '/operations/{uuid}')
  Future<Response<Operation>> update(
    @Path('uuid') String uuid,
    @Body() Operation body,
  );

  @Delete(path: '/operations/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
