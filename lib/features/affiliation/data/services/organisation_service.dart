import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'organisation_service.chopper.dart';

/// Service for consuming the organisations endpoint
///
/// Delegates to a ChopperService implementation
class OrganisationService with ServiceGetList<Organisation> implements ServiceDelegate<OrganisationServiceImpl> {
  final OrganisationServiceImpl delegate;

  OrganisationService() : delegate = OrganisationServiceImpl.newInstance();

  /// GET ../organisations
  Future<ServiceResponse<List<Organisation>>> getSubList(int offset, int limit) async {
    return Api.from<PagedList<Organisation>, List<Organisation>>(
      await delegate.fetch(offset: offset, limit: limit),
    );
  }

  /// POST ../organisations
  Future<ServiceResponse<Organisation>> create(Organisation organisation) async {
    return Api.from<String, Organisation>(
      await delegate.create(
        organisation,
      ),
      // Created 201 returns uri to created organisation in body
      body: organisation,
    );
  }

  /// PUT ../organisations/{ouuid}
  Future<ServiceResponse<Organisation>> update(Organisation organisation) async {
    return Api.from<Organisation, Organisation>(
      await delegate.update(
        organisation.uuid,
        organisation,
      ),
      // Created 201 returns uri to created organisation in body
      body: organisation,
    );
  }

  /// DELETE ../organisations/{ouuid}
  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Organisation, Organisation>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi(baseUrl: '/organisations')
abstract class OrganisationServiceImpl extends JsonService<Organisation, OrganisationModel> {
  OrganisationServiceImpl()
      : super(
          decoder: (json) => OrganisationModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<OrganisationModel>(value),
        );

  static OrganisationServiceImpl newInstance([ChopperClient client]) => _$OrganisationServiceImpl(client);

  /// Initializes configuration to default values for given version.
  ///
  /// POST /organisations/{version}
  @Post()
  Future<Response<String>> create(
    @Body() Organisation body,
  );

  /// GET /organisations
  @Get()
  Future<Response<PagedList<Organisation>>> fetch({
    @Query('offset') int offset = 0,
    @Query('limit') int limit = 20,
  });

  /// PATCH ../organisations/{uuid}
  @Patch(path: "{uuid}")
  Future<Response<Organisation>> update(
    @Path('uuid') String uuid,
    @Body() Organisation body,
  );

  /// DELETE ../organisations/{uuid}
  @Delete(path: "{uuid}")
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
