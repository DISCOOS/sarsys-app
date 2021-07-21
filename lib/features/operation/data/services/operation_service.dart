// @dart=2.11

import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'operation_service.chopper.dart';

/// Service for consuming the operations endpoint
///
/// Delegates to a ChopperService implementation
class OperationService extends StatefulServiceDelegate<Operation, OperationModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetList {
  OperationService(
    this.channel,
  ) : delegate = OperationServiceImpl.newInstance() {
    // Listen for Operation messages
    OperationMessageType.values.forEach(
      (type) => channel.subscribe(enumName(type), _onMessage),
    );
  }

  final MessageChannel channel;
  final OperationServiceImpl delegate;

  /// Get stream of device messages
  Stream<OperationMessage> get messages => _controller.stream;
  final StreamController<OperationMessage> _controller = StreamController.broadcast();

  void publish(OperationMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      OperationMessage(data),
    );
  }

  void dispose() {
    _controller.close();
    OperationMessageType.values.forEach(
      (type) => channel.unsubscribe(enumName(type), _onMessage),
    );
  }
}

enum OperationMessageType {
  OperationCreated,
  OperationDeleted,
  OperationPositionChanged,
  OperationInformationUpdated,
  OperationStarted,
  OperationCancelled,
  OperationFinished,
  PersonnelAddedToOperation,
  PersonnelRemovedFromOperation,
  MissionAddedToOperation,
  MissionRemovedFromOperation,
  UnitAddedToOperation,
  UnitRemovedFromOperation,
  OperationObjectiveAdded,
  OperationObjectiveUpdated,
  OperationObjectiveRemoved,
  OperationTalkGroupAdded,
  OperationTalkGroupUpdated,
  OperationTalkGroupRemoved,
  OperationMessageAdded,
  OperationMessageUpdated,
  OperationMessageRemoved,
}

class OperationMessage extends MessageModel {
  OperationMessage(Map<String, dynamic> data) : super(data);

  factory OperationMessage.positionChanged(String uuid, List<Map<String, dynamic>> patches) => OperationMessage({
        'type': enumName(OperationMessageType.OperationPositionChanged),
        'data': {
          'uuid': uuid,
          'patches': patches,
        }
      });

  OperationMessageType get type {
    final type = data.elementAt('type');
    return OperationMessageType.values.singleWhere((e) => enumName(e) == type, orElse: () => null);
  }
}

@ChopperApi()
abstract class OperationServiceImpl extends StatefulService<Operation, OperationModel> {
  OperationServiceImpl()
      : super(
          decoder: (json) => OperationModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<OperationModel>(value, remove: const [
            'units',
            'incident',
            'messages',
            'missions',
            'personnels',
            'objectives',
            "transitions",
          ]),
        );

  static OperationServiceImpl newInstance([ChopperClient client]) => _$OperationServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Operation> state) => create(
        state.value.incident.uuid,
        state.value,
      );

  @Post(path: '/incidents/{iuuid}/operations')
  Future<Response<String>> create(
    @Path() String iuuid,
    @Body() Operation body,
  );

  @override
  Future<Response<StorageState<Operation>>> onUpdate(StorageState<Operation> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '/operations/{uuid}')
  Future<Response<StorageState<Operation>>> update(
    @Path('uuid') String uuid,
    @Body() Operation body,
  );

  @override
  Future<Response<StorageState<Operation>>> onDelete(StorageState<Operation> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '/operations/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  Future<Response<PagedList<StorageState<Operation>>>> onGetPage(
    int offset,
    int limit,
    List<String> options,
  ) =>
      fetch(offset, limit);

  @Get(path: '/operations')
  Future<Response<PagedList<StorageState<Operation>>>> fetch(
    @Query('offset') int offset,
    @Query('limit') int limit,
  );
}
