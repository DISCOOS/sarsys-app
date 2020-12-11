import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';

import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'affiliation_service.chopper.dart';

/// Service for consuming the affiliations endpoint
///
/// Delegates to a ChopperService implementation
class AffiliationService extends StatefulServiceDelegate<Affiliation, AffiliationModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulSearch, StatefulGetListFromIds {
  AffiliationService() : delegate = AffiliationServiceImpl.newInstance();
  final AffiliationServiceImpl delegate;
}

@ChopperApi(baseUrl: '/affiliations')
abstract class AffiliationServiceImpl extends StatefulService<Affiliation, AffiliationModel> {
  AffiliationServiceImpl()
      : super(
          decoder: (json) => AffiliationModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<AffiliationModel>(value),
        );

  static AffiliationServiceImpl newInstance([ChopperClient client]) => _$AffiliationServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Affiliation> state) => create(
        state.value,
      );

  @Post()
  Future<Response<String>> create(
    @Body() Affiliation body,
  );

  @override
  Future<Response<StorageState<Affiliation>>> onUpdate(StorageState<Affiliation> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '{uuid}')
  Future<Response<StorageState<Affiliation>>> update(
    @Path('uuid') String uuid,
    @Body() Affiliation body,
  );

  @override
  Future<Response<StorageState<Affiliation>>> onDelete(StorageState<Affiliation> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  @override
  Future<Response<PagedList<StorageState<Affiliation>>>> onSearch(
    String filter,
    int offset,
    int limit,
    List<String> options,
  ) =>
      search(filter, limit, offset, 'person');

  @Get()
  Future<Response<PagedList<StorageState<Affiliation>>>> search(
    @Query('filter') String filter,
    @Query('limit') int limit,
    @Query('offset') int offset,
    @Query('expand') String expand,
  );

  Future<Response<PagedList<StorageState<Affiliation>>>> onGetPageFromIds(
    List<String> ids,
    int offset,
    int limit,
    List<String> options,
  ) async {
    return getAll(
      ids?.join(','),
      expand: 'person',
      offset: 0,
      limit: limit,
    );
  }

  @Get()
  Future<Response<PagedList<StorageState<Affiliation>>>> getAll(
    @Query('uuids') String uuids, {
    @Query('expand') String expand,
    @Query('limit') int limit = 20,
    @Query('offset') int offset = 0,
  });
}
