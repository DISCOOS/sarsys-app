

import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/data/services/service.dart';

import 'package:collection/collection.dart' show IterableExtension;
part 'unit_service.chopper.dart';

/// Service for consuming the units endpoint
///
/// Delegates to a ChopperService implementation
class UnitService extends StatefulServiceDelegate<Unit, UnitModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetListFromId {
  UnitService(
    this.channel,
  ) : delegate = UnitServiceImpl.newInstance() {
    // Listen for Unit messages
    UnitMessageType.values.forEach(
      (type) => channel.subscribe(enumName(type), _onMessage),
    );
  }

  final MessageChannel channel;
  final UnitServiceImpl delegate;

  /// Get stream of device messages
  Stream<UnitMessage> get messages => _controller.stream;
  final StreamController<UnitMessage> _controller = StreamController.broadcast();

  void publish(UnitMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      UnitMessage(data),
    );
  }

  void dispose() {
    _controller.close();
    UnitMessageType.values.forEach(
      (type) => channel.unsubscribe(enumName(type), _onMessage as void Function(dynamic)),
    );
  }
}

enum UnitMessageType {
  UnitCreated,
  UnitMobilized,
  UnitDeployed,
  UnitRetired,
  UnitDeleted,
  UnitPositionChanged,
  UnitInformationUpdated,
  PersonnelAddedToUnit,
  PersonnelRemovedFromUnit,
  UnitMessageAdded,
  UnitMessageUpdated,
  UnitMessageRemoved,
}

class UnitMessage extends MessageModel {
  UnitMessage(Map<String, dynamic> data) : super(data);

  factory UnitMessage.created(Unit tracking) => UnitMessage.fromType(
        tracking,
        UnitMessageType.UnitCreated,
      );

  factory UnitMessage.updated(Unit tracking) => UnitMessage.fromType(
        tracking,
        UnitMessageType.UnitInformationUpdated,
      );

  factory UnitMessage.deleted(Unit tracking) => UnitMessage.fromType(
        tracking,
        UnitMessageType.UnitDeleted,
      );

  factory UnitMessage.fromType(Unit tracking, UnitMessageType type) => UnitMessage({
        'type': enumName(type),
        'data': {
          'uuid': tracking.uuid,
          'changed': tracking.toJson(),
        },
      });

  UnitMessageType? get type {
    final type = data.elementAt('type');
    return UnitMessageType.values.singleWhereOrNull((e) => enumName(e) == type);
  }
}

@ChopperApi()
abstract class UnitServiceImpl extends StatefulService<Unit, UnitModel> {
  UnitServiceImpl()
      : super(
          decoder: (json) => UnitModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<UnitModel?>(value, remove: const [
            'operation',
          ]),
        );
  static UnitServiceImpl newInstance([ChopperClient? client]) => _$UnitServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Unit> state) => create(
        state.value.operation!.uuid,
        state.value,
      );

  @Post(path: '/operations/{ouuid}/units')
  Future<Response<String>> create(
    @Path('ouuid') ouuid,
    @Body() Unit body,
  );

  @override
  Future<Response<StorageState<Unit>>> onUpdate(StorageState<Unit> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: 'units/{uuid}')
  Future<Response<StorageState<Unit>>> update(
    @Path('uuid') String? uuid,
    @Body() Unit personnel,
  );

  @override
  Future<Response<StorageState<Unit>>> onDelete(StorageState<Unit> state) => delete(
        state.value.uuid,
      ).then((value) => value as Response<StorageState<Unit>>);

  @Delete(path: 'units/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String? uuid,
  );

  @Get(path: '/operations/{ouuid}/units')
  Future<Response<PagedList<StorageState<Unit>>>> onGetPageFromId(
    @Path('ouuid') String? id,
    @Query('offset') int? offset,
    @Query('limit') int? limit,
    List<String> options,
  );
}
