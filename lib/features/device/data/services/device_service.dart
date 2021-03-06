import 'dart:async';

import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'device_service.chopper.dart';

/// Service for consuming the devices endpoint
///
/// Delegates to a ChopperService implementation
class DeviceService extends StatefulServiceDelegate<Device, DeviceModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetList {
  DeviceService(
    this.channel,
  ) : delegate = DeviceServiceImpl.newInstance() {
    // Listen for Device messages
    DeviceMessageType.values.forEach(
      (type) => channel.subscribe(enumName(type), _onMessage),
    );
  }

  final MessageChannel channel;
  final DeviceServiceImpl delegate;

  /// Get stream of device messages
  Stream<DeviceMessage> get messages => _controller.stream;
  final StreamController<DeviceMessage> _controller = StreamController.broadcast();

  void publish(DeviceMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      DeviceMessage(data),
    );
  }

  void dispose() {
    _controller.close();
    DeviceMessageType.values.forEach(
      (type) => channel.unsubscribe(enumName(type), _onMessage),
    );
  }
}

enum DeviceMessageType {
  DeviceCreated,
  DeviceDeleted,
  DevicePositionChanged,
  DeviceInformationUpdated,
  DeviceMessageAdded,
  DeviceMessageUpdated,
  DeviceMessageRemoved,
}

class DeviceMessage extends MessageModel {
  DeviceMessage(Map<String, dynamic> data) : super(data);

  factory DeviceMessage.positionChanged(String uuid, List<Map<String, dynamic>> patches) => DeviceMessage({
        'type': enumName(DeviceMessageType.DevicePositionChanged),
        'data': {
          'uuid': uuid,
          'patches': patches,
        }
      });

  DeviceMessageType get type {
    final type = data.elementAt('type');
    return DeviceMessageType.values.singleWhere((e) => enumName(e) == type, orElse: () => null);
  }
}

@ChopperApi(baseUrl: '/devices')
abstract class DeviceServiceImpl extends StatefulService<Device, DeviceModel> {
  DeviceServiceImpl()
      : super(
          decoder: (json) => DeviceModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<DeviceModel>(value, remove: const [
            'position',
            'messages',
            'transitions',
          ]),
        );
  static DeviceServiceImpl newInstance([ChopperClient client]) => _$DeviceServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Device> state) => create(
        state.value.uuid,
        state.value,
      );

  @Post()
  Future<Response<String>> create(
    @Path() String uuid,
    @Body() Device body,
  );

  @override
  Future<Response<StorageState<Device>>> onUpdate(StorageState<Device> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '{uuid}')
  Future<Response<StorageState<Device>>> update(
    @Path('uuid') String uuid,
    @Body() Device body,
  );

  @override
  Future<Response<StorageState<Device>>> onDelete(StorageState<Device> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  Future<Response<PagedList<StorageState<Device>>>> onGetPage(int offset, int limit, List<String> options) => fetch();

  @Get()
  Future<Response<PagedList<StorageState<Device>>>> fetch();
}
