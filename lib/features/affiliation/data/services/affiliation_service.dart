import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/extensions.dart';

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
        expand: 'person',
      ),
    );
  }

  Future<ServiceResponse<Affiliation>> get(String uuid) async {
    return Api.from<Affiliation, Affiliation>(
      await delegate.get(
        uuid: uuid,
        expand: 'person',
      ),
    );
  }

  Future<ServiceResponse<List<Affiliation>>> _fetch(List<String> uuids, int offset, int limit) async {
    return Api.from<PagedList<Affiliation>, List<Affiliation>>(
      await delegate.getAll(
        // Limit query string length
        uuids?.toPage(offset: offset, limit: limit)?.join(','),
        expand: 'person',
        offset: 0,
        limit: limit,
      ),
    );
  }

  Future<ServiceResponse<List<Affiliation>>> getAll(List<String> uuids) async {
    var offset = 0;
    final limit = 20;
    final body = <Affiliation>[];
    // This method limits the length of each query
    var response = await _fetch(uuids, offset, limit);
    while (response.is200) {
      body.addAll(response.body);
      offset += limit;
      if (offset < uuids.length) {
        response = await _fetch(uuids, offset, limit);
      } else {
        return ServiceResponse.ok(body: body);
      }
    }
    return response;
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
    @Query('expand') String expand,
  });

  @Get()
  Future<Response<PagedList<Affiliation>>> getAll(
    @Query('uuids') String uuids, {
    @Query('expand') String expand,
    @Query('limit') int limit = 20,
    @Query('offset') int offset = 0,
  });

  @Get()
  Future<Response<PagedList<Affiliation>>> search(
    @Query('filter') String filter, {
    @Query('expand') String expand,
    @Query('limit') int limit = 20,
    @Query('offset') int offset = 0,
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
