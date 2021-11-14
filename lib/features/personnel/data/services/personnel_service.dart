

import 'dart:async';

import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/core/data/services/service.dart';

import 'package:collection/collection.dart' show IterableExtension;
part 'personnel_service.chopper.dart';

/// Service for consuming the personnels endpoint
///
/// Delegates to a ChopperService implementation
class PersonnelService extends StatefulServiceDelegate<Personnel, PersonnelModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetListFromId {
  final PersonnelServiceImpl delegate;
  PersonnelService(
    this.channel,
  ) : delegate = PersonnelServiceImpl.newInstance() {
    // Listen for Device messages
    PersonnelMessageType.values.forEach(
      (type) => channel.subscribe(enumName(type), _onMessage),
    );
  }

  final MessageChannel channel;

  /// Get stream of personnel messages
  Stream<PersonnelMessage> get messages => _controller.stream;
  final StreamController<PersonnelMessage> _controller = StreamController.broadcast();

  void publish(PersonnelMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      PersonnelMessage(data),
    );
  }

  void dispose() {
    _controller.close();
    PersonnelMessageType.values.forEach(
      (type) => channel.unsubscribe(enumName(type), _onMessage as void Function(dynamic)),
    );
  }
}

enum PersonnelMessageType {
  PersonnelMobilized,
  PersonnelDeployed,
  PersonnelRetired,
  PersonnelDeleted,
  PersonnelInformationUpdated,
  PersonnelMessageAdded,
  PersonnelMessageUpdated,
  PersonnelMessageRemoved,
}

class PersonnelMessage extends MessageModel {
  PersonnelMessage(Map<String, dynamic> data) : super(data);

  PersonnelMessageType? get type {
    final type = data.elementAt('type');
    return PersonnelMessageType.values.singleWhereOrNull((e) => enumName(e) == type);
  }
}

@ChopperApi()
abstract class PersonnelServiceImpl extends StatefulService<Personnel, PersonnelModel> {
  PersonnelServiceImpl()
      : super(
          decoder: (json) => PersonnelModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<PersonnelModel?>(value, remove: const [
            'unit',
            'operation',
          ]),
        );
  static PersonnelServiceImpl newInstance([ChopperClient? client]) => _$PersonnelServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Personnel> state) => create(
        state.value.operation!.uuid,
        state.value,
      );

  @Post(path: '/operations/{ouuid}/personnels')
  Future<Response<String>> create(
    @Path('ouuid') ouuid,
    @Body() Personnel body,
  );

  @override
  Future<Response<StorageState<Personnel>>> onUpdate(StorageState<Personnel> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: 'personnels/{uuid}')
  Future<Response<StorageState<Personnel>>> update(
    @Path('uuid') String? uuid,
    @Body() Personnel personnel,
  );

  @override
  Future<Response<StorageState<Personnel>>> onDelete(StorageState<Personnel> state) => delete(
        state.value.uuid,
      ).then((value) => value as Response<StorageState<Personnel>>);

  @Delete(path: 'personnels/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String? uuid,
  );

  @override
  Future<Response<PagedList<StorageState<Personnel>>>> onGetPageFromId(
    String? id,
    int? offset,
    int? limit,
    List<String> options,
  ) =>
      fetch(
        id,
        offset,
        limit,
        expand: 'person',
      );

  @Get(path: '/operations/{ouuid}/personnels')
  Future<Response<PagedList<StorageState<Personnel>>>> fetch(
    @Path('ouuid') ouuid,
    @Query('offset') int? offset,
    @Query('limit') int? limit, {
    @Query('expand') String? expand,
  });
}
