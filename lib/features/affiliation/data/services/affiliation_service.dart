import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'affiliation_service.chopper.dart';

/// Service for consuming the affiliations endpoint
///
/// Delegates to a ChopperService implementation
class AffiliationService with ServiceGet<Affiliation> implements ServiceDelegate<AffiliationServiceImpl> {
  final AffiliationServiceImpl delegate;

  AffiliationService() : delegate = AffiliationServiceImpl.newInstance();

  Future<ServiceResponse<List<Affiliation>>> search(String filter, int offset, int limit) async {
    return Api.from<PagedList<Affiliation>, List<Affiliation>>(
      await delegate.search(
        filter,
        offset: offset,
        limit: limit,
        expand: const ['person'],
      ),
    );
  }

  Future<ServiceResponse<Affiliation>> get(String uuid) async {
    return Api.from<Affiliation, Affiliation>(
      await delegate.get(
        uuid: uuid,
        expand: const ['person'],
      ),
    );
  }

  Future<ServiceResponse<Affiliation>> create(Affiliation affiliation) async {
    return Api.from<String, Affiliation>(
      await delegate.create(
        affiliation,
      ),
      // Created 201 returns uri to created affiliation in body
      body: affiliation,
    );
  }

  Future<ServiceResponse<Affiliation>> update(Affiliation affiliation) async {
    return Api.from<Affiliation, Affiliation>(
      await delegate.update(
        affiliation.uuid,
        affiliation,
      ),
      // 204 No content
      body: affiliation,
    );
  }

  Future<ServiceResponse<Affiliation>> delete(String uuid) async {
    return Api.from<Affiliation, Affiliation>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi(baseUrl: '/affiliations')
abstract class AffiliationServiceImpl extends ChopperService {
  static AffiliationServiceImpl newInstance([ChopperClient client]) => _$AffiliationServiceImpl(client);

  @Get(path: '{uuid}')
  Future<Response<Affiliation>> get({
    @Path('uuid') String uuid,
    @Query('expand') List<String> expand = const [],
  });

  @Get()
  Future<Response<PagedList<Affiliation>>> search(
    @Query('filter') String filter, {
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 20,
    @Query('expand') List<String> expand = const [],
  });

  @Post()
  Future<Response<String>> create(
    @Body() Affiliation body,
  );

  @Patch(path: '{uuid}')
  Future<Response<Affiliation>> update(
    @Path('uuid') String uuid,
    @Body() Affiliation body,
  );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
