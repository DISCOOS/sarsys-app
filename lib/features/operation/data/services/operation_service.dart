import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'operation_service.chopper.dart';

/// Service for consuming the operations endpoint
///
/// Delegates to a ChopperService implementation
class OperationService extends StatefulServiceDelegate<Operation, OperationModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetList {
  final OperationServiceImpl delegate;

  OperationService() : delegate = OperationServiceImpl.newInstance();
}

@ChopperApi()
abstract class OperationServiceImpl extends StatefulService<Operation, OperationModel> {
  OperationServiceImpl()
      : super(
          decoder: (json) => OperationModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<OperationModel>(value, remove: const [
            'units',
            'incident',
            'messages',
            'missions',
            'personnels',
            'objectives',
            "transitions",
          ]),
        );

  static OperationServiceImpl newInstance([ChopperClient client]) => _$OperationServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Operation> state) => create(
        state.value.incident.uuid,
        state.value,
      );

  @Post(path: '/incidents/{iuuid}/operations')
  Future<Response<String>> create(
    @Path() String iuuid,
    @Body() Operation body,
  );

  @override
  Future<Response<StorageState<Operation>>> onUpdate(StorageState<Operation> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '/operations/{uuid}')
  Future<Response<StorageState<Operation>>> update(
    @Path('uuid') String uuid,
    @Body() Operation body,
  );

  @override
  Future<Response<StorageState<Operation>>> onDelete(StorageState<Operation> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '/operations/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  Future<Response<PagedList<StorageState<Operation>>>> onGetPage(
    int offset,
    int limit,
    List<String> options,
  ) =>
      fetch(offset, limit);

  @Get(path: '/operations')
  Future<Response<PagedList<StorageState<Operation>>>> fetch(
    @Query('offset') int offset,
    @Query('limit') int limit,
  );
}
