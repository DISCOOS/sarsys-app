// @dart=2.11

import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'incident_service.chopper.dart';

/// Service for consuming the incidents endpoint
///
/// Delegates to a ChopperService implementation
class IncidentService extends StatefulServiceDelegate<Incident, IncidentModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetList {
  IncidentService(
    this.channel,
  ) : delegate = IncidentServiceImpl.newInstance() {
    // Listen for Incident messages
    IncidentMessageType.values.forEach(
      (type) => channel.subscribe(enumName(type), _onMessage),
    );
  }

  final MessageChannel channel;
  final IncidentServiceImpl delegate;

  /// Get stream of device messages
  Stream<IncidentMessage> get messages => _controller.stream;
  final StreamController<IncidentMessage> _controller = StreamController.broadcast();

  void publish(IncidentMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      IncidentMessage(data),
    );
  }

  void dispose() {
    _controller.close();
    IncidentMessageType.values.forEach(
      (type) => channel.unsubscribe(enumName(type), _onMessage),
    );
  }
}

enum IncidentMessageType {
  IncidentCreated,
  IncidentDeleted,
  IncidentInformationUpdated,
  OperationAddedToIncident,
  OperationRemovedFromIncident,
  SubjectAddedToIncident,
  SubjectRemovedFromIncident,
  IncidentRespondedTo,
  IncidentCancelled,
  IncidentResolved,
  AddIncidentClue,
  UpdateIncidentClue,
  RemoveIncidentClue,
  AddIncidentMessage,
  UpdateIncidentMessage,
  RemoveIncidentMessage,
}

class IncidentMessage extends MessageModel {
  IncidentMessage(Map<String, dynamic> data) : super(data);

  IncidentMessageType get type {
    final type = data.elementAt('type');
    return IncidentMessageType.values.singleWhere((e) => enumName(e) == type, orElse: () => null);
  }
}

@ChopperApi(baseUrl: '/incidents')
abstract class IncidentServiceImpl extends StatefulService<Incident, IncidentModel> {
  IncidentServiceImpl()
      : super(
          decoder: (json) => IncidentModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<IncidentModel>(value, remove: const [
            'clues',
            'subjects',
            'messages',
            'operations',
            'transitions',
          ]),
        );
  static IncidentServiceImpl newInstance([ChopperClient client]) => _$IncidentServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Incident> state) => create(
        state.value.uuid,
        state.value,
      );

  @Post()
  Future<Response<String>> create(
    @Path() String uuid,
    @Body() Incident body,
  );

  @override
  Future<Response<StorageState<Incident>>> onUpdate(StorageState<Incident> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '{uuid}')
  Future<Response<StorageState<Incident>>> update(
    @Path('uuid') String uuid,
    @Body() Incident body,
  );

  @override
  Future<Response<StorageState<Incident>>> onDelete(StorageState<Incident> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  Future<Response<PagedList<StorageState<Incident>>>> onGetPage(int offset, int limit, List<String> options) =>
      fetch(offset, limit);

  @Get()
  Future<Response<PagedList<StorageState<Incident>>>> fetch(
    @Query('offset') int offset,
    @Query('limit') int limit,
  );
}
