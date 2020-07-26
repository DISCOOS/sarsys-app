import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'device_service.chopper.dart';

/// Service for consuming the devices endpoint
///
/// Delegates to a ChopperService implementation
class DeviceService with ServiceFetchAll<Device> implements ServiceDelegate<DeviceServiceImpl> {
  final DeviceServiceImpl delegate;

  DeviceService() : delegate = DeviceServiceImpl.newInstance();

  final StreamController<DeviceMessage> _controller = StreamController.broadcast();

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
  }
}

enum DeviceMessageType { LocationChanged }

class DeviceMessage {
  final String duuid;
  final DeviceMessageType type;
  final Map<String, dynamic> json;
  DeviceMessage({this.duuid, this.type, this.json});
}

@ChopperApi(baseUrl: '/devices')
abstract class DeviceServiceImpl extends ChopperService {
  static DeviceServiceImpl newInstance([ChopperClient client]) => _$DeviceServiceImpl(client);

  @Post(path: '/devices')
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