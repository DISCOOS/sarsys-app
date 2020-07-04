import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/core/service.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'affiliation_service.chopper.dart';

/// Service for consuming the affiliations endpoint
///
/// Delegates to a ChopperService implementation
class AffiliationService with ServiceGet<Affiliation> implements ServiceDelegate<AffiliationServiceImpl> {
  final AffiliationServiceImpl delegate;

  AffiliationService() : delegate = AffiliationServiceImpl.newInstance();

  /// GET ../affiliations
  Future<ServiceResponse<Affiliation>> get(String uuid) async {
    return Api.from<Affiliation, Affiliation>(
      await delegate.get(uuid: uuid),
    );
  }

  /// POST ../affiliations
  Future<ServiceResponse<Affiliation>> create(Affiliation affiliation) async {
    return Api.from<String, Affiliation>(
      await delegate.create(
        affiliation,
      ),
      // Created 201 returns uri to created affiliation in body
      body: affiliation,
    );
  }

  /// PUT ../affiliations/{ouuid}
  Future<ServiceResponse<Affiliation>> update(Affiliation affiliation) async {
    return Api.from<Affiliation, Affiliation>(
      await delegate.update(
        affiliation.uuid,
        affiliation,
      ),
      // Created 201 returns uri to created affiliation in body
      body: affiliation,
    );
  }

  /// DELETE ../affiliations/{ouuid}
  Future<ServiceResponse<Affiliation>> delete(String uuid) async {
    return Api.from<Affiliation, Affiliation>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi(baseUrl: '/affiliations')
abstract class AffiliationServiceImpl extends ChopperService {
  static AffiliationServiceImpl newInstance([ChopperClient client]) => _$AffiliationServiceImpl(client);

  @Post()
  Future<Response<String>> create(
    @Body() Affiliation body,
  );

  @Get(path: '{uuid}')
  Future<Response<Affiliation>> get({
    @Path('uuid') String uuid,
  });

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
