import 'dart:async';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/services/service.dart';
import 'package:chopper/chopper.dart';

part 'device_service.chopper.dart';

/// Service for consuming the devices endpoint
///
/// Delegates to a ChopperService implementation
class DeviceService {
  final DeviceServiceImpl delegate;

  DeviceService() : delegate = DeviceServiceImpl.newInstance();

  final StreamController<DeviceMessage> _controller = StreamController.broadcast();

  /// Get stream of device messages
  Stream<DeviceMessage> get messages => _controller.stream;

  /// GET ../devices for given [Incident.uuid]
  Future<ServiceResponse<List<Device>>> fetch(String ouuid) async {
    return Api.from<List<Device>, List<Device>>(
      await delegate.fetch(),
    );
  }

  /// POST ../devices
  Future<ServiceResponse<Device>> create(String ouuid, Device device) async {
    return Api.from<String, Device>(
      await delegate.create(
        device,
      ),
      // Created 201 returns uri to created device in body
      body: device,
    );
  }

  /// PUT ../devices/{deviceId}
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

  /// DELETE ../devices/{deviceId}
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

  /// Initializes configuration to default values for given version.
  ///
  /// POST /devices/{version}
  @Post()
  Future<Response<String>> create(
    @Body() Device config,
  );

  /// GET /devices
  @Get()
  Future<Response<List<Device>>> fetch();

  /// PATCH ../devices/{uuid}
  @Patch(path: "{uuid}")
  Future<Response<Device>> update(
    @Path('uuid') String uuid,
    @Body() Device config,
  );

  /// DELETE ../devices/{uuid}
  @Delete(path: "{uuid}")
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
