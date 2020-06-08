import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'operation_service.chopper.dart';

/// Service for consuming the operations endpoint
///
/// Delegates to a ChopperService implementation
class OperationService {
  final OperationServiceImpl delegate;

  OperationService() : delegate = OperationServiceImpl.newInstance();

  /// GET ../operations
  Future<ServiceResponse<List<Operation>>> fetch() async {
    return Api.from<List<Operation>, List<Operation>>(
      await delegate.fetch(),
    );
  }

  /// POST ../operations
  Future<ServiceResponse<Operation>> create(Operation operation) async {
    return Api.from<String, Operation>(
      await delegate.create(
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

@ChopperApi(baseUrl: '/operations')
abstract class OperationServiceImpl extends ChopperService {
  static OperationServiceImpl newInstance([ChopperClient client]) => _$OperationServiceImpl(client);

  /// Initializes configuration to default values for given version.
  ///
  /// POST /operations/{version}
  @Post()
  Future<Response<String>> create(
    @Body() Operation config,
  );

  /// GET /operations
  @Get()
  Future<Response<List<Operation>>> fetch();

  /// PATCH ../operations/{uuid}
  @Patch(path: "{uuid}")
  Future<Response<Operation>> update(
    @Path('uuid') String uuid,
    @Body() Operation config,
  );

  /// DELETE ../operations/{uuid}
  @Delete(path: "{uuid}")
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
