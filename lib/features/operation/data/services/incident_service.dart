import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'incident_service.chopper.dart';

/// Service for consuming the incidents endpoint
///
/// Delegates to a ChopperService implementation
class IncidentService with ServiceFetchAll<Incident> implements ServiceDelegate<IncidentServiceImpl> {
  final IncidentServiceImpl delegate;

  IncidentService() : delegate = IncidentServiceImpl.newInstance();

  Future<ServiceResponse<List<Incident>>> fetch(int offset, int limit) async {
    return Api.from<PagedList<Incident>, List<Incident>>(
      await delegate.fetch(),
    );
  }

  Future<ServiceResponse<Incident>> create(Incident incident) async {
    return Api.from<String, Incident>(
      await delegate.create(
        incident,
      ),
      // Created 201 returns uri to created incident in body
      body: incident,
    );
  }

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

  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Incident, Incident>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi(baseUrl: '/incidents')
abstract class IncidentServiceImpl extends ChopperService {
  static IncidentServiceImpl newInstance([ChopperClient client]) => _$IncidentServiceImpl(client);

  @Post()
  Future<Response<String>> create(
    @Body() Incident body,
  );

  @Get()
  Future<Response<PagedList<Incident>>> fetch();

  @Patch(path: '{uuid}')
  Future<Response<Incident>> update(
    @Path('uuid') String uuid,
    @Body() Incident body,
  );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
