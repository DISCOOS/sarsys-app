import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'personnel_service.chopper.dart';

/// Service for consuming the personnels endpoint
///
/// Delegates to a ChopperService implementation
class PersonnelService {
  final PersonnelServiceImpl delegate;

  PersonnelService() : delegate = PersonnelServiceImpl.newInstance();

  final StreamController<PersonnelMessage> _controller = StreamController.broadcast();

  /// Get stream of personnel messages
  Stream<PersonnelMessage> get messages => _controller.stream;

  /// GET ../personnel
  Future<ServiceResponse<List<Personnel>>> fetch(String ouuid) async {
    return Api.from<List<Personnel>, List<Personnel>>(
      await delegate.fetch(),
    );
  }

  /// POST ../personnel
  Future<ServiceResponse<Personnel>> create(String ouuid, Personnel personnel) async {
    return Api.from<String, Personnel>(
      await delegate.create(
        personnel,
      ),
      // Created 201 returns uri to created personnel in body
      body: personnel,
    );
  }

  /// PUT ../personnel/{PersonnelId}
  Future<ServiceResponse<Personnel>> update(Personnel personnel) async {
    return Api.from<Personnel, Personnel>(
      await delegate.update(
        personnel.uuid,
        personnel,
      ),
      body: personnel,
    );
  }

  /// DELETE ../personnel/{PersonnelId}
  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Personnel, Personnel>(await delegate.delete(
      uuid,
    ));
  }

  void dispose() {
    _controller.close();
  }
}

enum PersonnelMessageType { PersonnelChanged }

class PersonnelMessage {
  final String uuid;
  final PersonnelMessageType type;
  final Map<String, dynamic> json;
  PersonnelMessage(this.uuid, this.type, this.json);
}

@ChopperApi(baseUrl: '/personnels')
abstract class PersonnelServiceImpl extends ChopperService {
  static PersonnelServiceImpl newInstance([ChopperClient client]) => _$PersonnelServiceImpl(client);

  /// Initializes configuration to default values for given version.
  ///
  /// POST /personnels/{version}
  @Post()
  Future<Response<String>> create(
    @Body() Personnel config,
  );

  /// GET /personnels
  @Get()
  Future<Response<List<Personnel>>> fetch();

  /// PATCH ../personnels/{uuid}
  @Patch(path: "{uuid}")
  Future<Response<Personnel>> update(
    @Path('uuid') String uuid,
    @Body() Personnel personnel,
  );

  /// DELETE ../personnels/{uuid}
  @Delete(path: "{uuid}")
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
