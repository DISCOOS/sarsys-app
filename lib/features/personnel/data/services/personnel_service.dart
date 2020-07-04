import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/core/service.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'personnel_service.chopper.dart';

/// Service for consuming the personnels endpoint
///
/// Delegates to a ChopperService implementation
class PersonnelService with ServiceFetchDescendants<Personnel> implements ServiceDelegate<PersonnelServiceImpl> {
  final PersonnelServiceImpl delegate;

  PersonnelService() : delegate = PersonnelServiceImpl.newInstance();

  final StreamController<PersonnelMessage> _controller = StreamController.broadcast();

  /// Get stream of personnel messages
  Stream<PersonnelMessage> get messages => _controller.stream;

  Future<ServiceResponse<List<Personnel>>> fetch(String ouuid, int offset, int limit) async {
    return Api.from<PagedList<Personnel>, List<Personnel>>(
      await delegate.getAll(
        ouuid,
        offset,
        limit,
        expand: ['person'],
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
abstract class PersonnelServiceImpl extends ChopperService {
  static PersonnelServiceImpl newInstance([ChopperClient client]) => _$PersonnelServiceImpl(client);

  @Post(path: '/operations/{ouuid}/personnels')
  Future<Response<String>> create(
    @Path() ouuid,
    @Body() Personnel body,
  );

  @Get(path: '/operations/{ouuid}/personnels')
  Future<Response<PagedList<Personnel>>> getAll(
    @Path() ouuid,
    @Query('offset') int offset,
    @Query('limit') int limit, {
    @Query('expand') List<String> expand = const [],
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
