

import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';

import 'package:collection/collection.dart' show IterableExtension;
part 'person_service.chopper.dart';

/// Service for consuming the persons endpoint
///
/// Delegates to a ChopperService implementation
class PersonService extends StatefulServiceDelegate<Person, PersonModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetFromId {
  PersonService(
    this.channel,
  ) : delegate = PersonServiceImpl.newInstance() {
    // Listen for Person messages
    PersonMessageType.values.forEach(
      (type) => channel.subscribe(enumName(type), _onMessage),
    );
  }

  final MessageChannel channel;
  final PersonServiceImpl delegate;

  /// Get stream of device messages
  Stream<PersonMessage> get messages => _controller.stream;
  final StreamController<PersonMessage> _controller = StreamController.broadcast();

  void publish(PersonMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      PersonMessage(data),
    );
  }

  void dispose() {
    _controller.close();
    PersonMessageType.values.forEach(
      (type) => channel.unsubscribe(enumName(type), _onMessage as void Function(dynamic)),
    );
  }
}

enum PersonMessageType {
  PersonCreated,
  PersonInformationUpdated,
  PersonDeleted,
}

class PersonMessage extends MessageModel {
  PersonMessage(Map<String, dynamic> data) : super(data);

  PersonMessageType? get type {
    final type = data.elementAt('type');
    return PersonMessageType.values.singleWhereOrNull((e) => enumName(e) == type);
  }
}

@ChopperApi(baseUrl: '/persons')
abstract class PersonServiceImpl extends StatefulService<Person, PersonModel> {
  PersonServiceImpl()
      : super(
          decoder: (json) => PersonModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<PersonModel?>(value),
        );

  static PersonServiceImpl newInstance([ChopperClient? client]) => _$PersonServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Person> state) => create(
        state.value.uuid,
        state.value,
      );

  @Post()
  Future<Response<String>> create(
    @Path() String? uuid,
    @Body() Person body,
  );

  @override
  Future<Response<StorageState<Person>>> onUpdate(StorageState<Person> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '{uuid}')
  Future<Response<StorageState<Person>>> update(
    @Path('uuid') String? uuid,
    @Body() Person body,
  );

  @override
  Future<Response<StorageState<Person>>> onDelete(StorageState<Person> state) => delete(
        state.value.uuid,
      ).then((value) => value as Response<StorageState<Person>>);

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String? uuid,
  );

  Future<Response<StorageState<Person>>> onGetFromId(String? id, {List<String> options = const []}) => get(id);

  @Get(path: '{uuid}')
  Future<Response<StorageState<Person>>> get(
    @Path('uuid') String? uuid,
  );
}
