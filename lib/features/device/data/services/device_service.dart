import 'dart:async';

import 'package:meta/meta.dart';
import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'device_service.chopper.dart';

/// Service for consuming the devices endpoint
///
/// Delegates to a ChopperService implementation
class DeviceService with ServiceFetchAll<Device> implements ServiceDelegate<DeviceServiceImpl> {
  DeviceService(this.channel) : delegate = DeviceServiceImpl.newInstance() {
    // Listen for Device messages
    channel.subscribe('DeviceCreated', _onMessage);
    channel.subscribe('DeviceDeleted', _onMessage);
    channel.subscribe('DevicePositionChanged', _onMessage);
    channel.subscribe('DeviceInformationUpdated', _onMessage);
  }

  final MessageChannel channel;
  final DeviceServiceImpl delegate;
  final StreamController<DeviceMessage> _controller = StreamController.broadcast();

  void _onMessage(Map<String, dynamic> data) {
    _controller.add(
      DeviceMessage(
        data: data,
      ),
    );
  }

  /// Get stream of device messages
  Stream<DeviceMessage> get messages => _controller.stream;

  Future<ServiceResponse<List<Device>>> fetch(int offset, int limit) async {
    return Api.from<PagedList<Device>, List<Device>>(
      await delegate.fetch(),
    );
  }

  Future<ServiceResponse<Device>> create(Device device) async {
    return Api.from<String, Device>(
      await delegate.create(
        device,
      ),
      // Created 201 returns uri to created device in body
      body: device,
    );
  }

  Future<ServiceResponse<Device>> update(Device device) async {
    return Api.from<Device, Device>(
      await delegate.update(
        device.uuid,
        device,
      ),
      // Created 201 returns uri to created device in body
      body: device,
    );
  }

  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Device, Device>(await delegate.delete(
      uuid,
    ));
  }

  void dispose() {
    _controller.close();
    channel.unsubscribe('DeviceCreated', _onMessage);
    channel.unsubscribe('DeviceDeleted', _onMessage);
    channel.unsubscribe('DevicePositionChanged', _onMessage);
    channel.unsubscribe('DeviceInformationUpdated', _onMessage);
  }
}

class DeviceMessage {
  DeviceMessage({
    @required this.data,
  });
  final Map<String, dynamic> data;
  String get uuid => data.elementAt('data/uuid');
  String get type => data.elementAt('data/type');
  List<Map<String, dynamic>> get patches => data.listAt<Map<String, dynamic>>('data/patches');
}

@ChopperApi(baseUrl: '/devices')
abstract class DeviceServiceImpl extends ChopperService {
  static DeviceServiceImpl newInstance([ChopperClient client]) => _$DeviceServiceImpl(client);

  @Post()
  Future<Response<String>> create(
    @Body() Device body,
  );

  @Get()
  Future<Response<PagedList<Device>>> fetch();

  @Patch(path: "{uuid}")
  Future<Response<Device>> update(
    @Path('uuid') String uuid,
    @Body() Device body,
  );

  @Delete(path: "{uuid}")
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
