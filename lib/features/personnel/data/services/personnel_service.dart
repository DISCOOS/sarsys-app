import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'personnel_service.chopper.dart';

/// Service for consuming the personnels endpoint
///
/// Delegates to a ChopperService implementation
class PersonnelService with ServiceGetListFromId<Personnel> implements ServiceDelegate<PersonnelServiceImpl> {
  final PersonnelServiceImpl delegate;

  PersonnelService() : delegate = PersonnelServiceImpl.newInstance();

  final StreamController<PersonnelMessage> _controller = StreamController.broadcast();

  /// Get stream of personnel messages
  Stream<PersonnelMessage> get messages => _controller.stream;

  Future<ServiceResponse<List<Personnel>>> getSubListFromId(String ouuid, int offset, int limit) async {
    return Api.from<PagedList<Personnel>, List<Personnel>>(
      await delegate.fetchAll(
        ouuid,
        offset,
        limit,
        expand: 'person',
      ),
    );
  }

  Future<ServiceResponse<Personnel>> create(String ouuid, Personnel personnel) async {
    return Api.from<String, Personnel>(
      await delegate.create(
        ouuid,
        personnel,
      ),
      // Created 201 returns uri to created personnel in body
      body: personnel,
    );
  }

  Future<ServiceResponse<Personnel>> update(Personnel personnel) async {
    return Api.from<Personnel, Personnel>(
      await delegate.update(
        personnel.uuid,
        personnel,
      ),
      body: personnel,
    );
  }

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

@ChopperApi()
abstract class PersonnelServiceImpl extends JsonService<Personnel, PersonnelModel> {
  PersonnelServiceImpl()
      : super(
          decoder: (json) => PersonnelModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<PersonnelModel>(value, remove: const [
            'person',
          ]),
        );
  static PersonnelServiceImpl newInstance([ChopperClient client]) => _$PersonnelServiceImpl(client);

  @Post(path: '/operations/{ouuid}/personnels')
  Future<Response<String>> create(
    @Path() ouuid,
    @Body() Personnel body,
  );

  @Get(path: '/operations/{ouuid}/personnels')
  Future<Response<PagedList<Personnel>>> fetchAll(
    @Path() ouuid,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('expand') String expand,
  });

  @Patch(path: 'personnels/{uuid}')
  Future<Response<Personnel>> update(
    @Path('uuid') String uuid,
    @Body() Personnel personnel,
  );

  @Delete(path: 'personnels/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
