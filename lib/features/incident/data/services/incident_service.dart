import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'incident_service.chopper.dart';

/// Service for consuming the incidents endpoint
///
/// Delegates to a ChopperService implementation
class IncidentService {
  final IncidentServiceImpl delegate;

  IncidentService() : delegate = IncidentServiceImpl.newInstance();

  /// POST ../incidents
  Future<ServiceResponse<Incident>> create(Incident incident) async {
    return Api.from<String, Incident>(
      await delegate.create(
        incident,
      ),
      // Created 201 returns uri to created incident in body
      body: incident,
    );
  }

  /// GET ../incidents
  Future<ServiceResponse<List<Incident>>> fetch() async {
    return Api.from<List<Incident>, List<Incident>>(
      await delegate.fetch(),
    );
  }

  /// PUT ../incidents/{iuuid}
  Future<ServiceResponse<Incident>> update(Incident incident) async {
    return Api.from<Incident, Incident>(
      await delegate.update(
        incident.uuid,
        incident,
      ),
      // Created 201 returns uri to created incident in body
      body: incident,
    );
  }

  /// DELETE ../incidents/{iuuid}
  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Incident, Incident>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi(baseUrl: '/incidents')
abstract class IncidentServiceImpl extends ChopperService {
  static IncidentServiceImpl newInstance([ChopperClient client]) => _$IncidentServiceImpl(client);

  /// Initializes configuration to default values for given version.
  ///
  /// POST /incidents/{version}
  @Post()
  Future<Response<String>> create(
    @Body() Incident config,
  );

  /// GET /incidents
  @Get()
  Future<Response<List<Incident>>> fetch();

  /// PATCH ../incidents/{uuid}
  @Patch(path: "{uuid}")
  Future<Response<Incident>> update(
    @Path('uuid') String uuid,
    @Body() Incident config,
  );

  /// DELETE ../incidents/{uuid}
  @Delete(path: "{uuid}")
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
