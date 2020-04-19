import 'package:SarSys/core/storage.dart';
import 'package:hive/hive.dart';
import 'package:json_patch/json_patch.dart';

import 'package:SarSys/models/Device.dart';
import 'package:SarSys/services/device_service.dart';

class DeviceRepository {
  DeviceRepository(this.service, {this.compactWhen = 10});
  final DeviceService service;
  final int compactWhen;

  Device operator [](String uuid) => _box.get(uuid);

  Map<String, Device> get map => Map.unmodifiable(_box.toMap());
  Iterable<String> get keys => List.unmodifiable(_box.keys);
  Iterable<Device> get values => List.unmodifiable(_box.values);

  bool containsKey(String uuid) => _box.keys.contains(uuid);
  bool containsValue(Device device) => _box.values.contains(device);

  String _iuuid;
  String get iuuid => _iuuid;

  Box<Device> _box;
  bool get isReady => _box?.isOpen == true && _box.containsKey(iuuid);
  void _assert() {
    if (!isReady) {
      throw '$DeviceRepository is not ready';
    }
  }

  Future<Box<Device>> _open(String iuuid) async {
    await _box?.compact();
    await _box?.close();
    _iuuid = iuuid;
    return Hive.openBox(
      '${DeviceRepository}_$iuuid',
      encryptionKey: await Storage.hiveKey<Device>(),
      compactionStrategy: (_, deleted) => compactWhen < deleted,
    );
  }

  /// GET ../devices
  Future<List<Device>> load(String iuuid) async {
    var response = await service.load(iuuid);
    if (response.is200) {
      _box = await _open(iuuid);
      await _box.putAll(
        Map.fromEntries(response.body.map(
          (device) => MapEntry(device.id, device),
        )),
      );
      return response.body;
    }
    throw response;
  }

  /// POST ../devices
  Future<Device> create(String iuuid, Device device) async {
    _assert();
    var response = await service.create(iuuid, device);
    if (response.is200) {
      return _put(
        device,
      );
    }
    throw response;
  }

  /// PATCH ../devices/{deviceId}
  Future<Device> update(Device device) async {
    _assert();
    var response = await service.update(device);
    if (response.is204) {
      return _put(
        device,
      );
    }
    throw response;
  }

  /// PUT ../devices/{deviceId}
  Future<Device> patch(Device device) async {
    _assert();
    final old = this[device.id];
    final oldJson = old?.toJson() ?? {};
    final patches = JsonPatch.diff(oldJson, device.toJson());
    final newJson = JsonPatch.apply(old, patches, strict: false);
    var response = await service.update(Device.fromJson(newJson));
    if (response.is204) {
      return _put(
        device,
      );
    }
    throw response;
  }

  /// DELETE ../devices/{deviceId}
  Future<Device> delete(Device device) async {
    _assert();
    var response = await service.delete(device);
    if (response.is204) {
      // Any tracking is removed by listening to this event in TrackingBloc
      _box.delete(device.id);
      return device;
    }
    throw response;
  }

  Future<List<Device>> unload() async {
    _assert();
    final devices = values.toList();
    _box.delete(iuuid);
    return devices;
  }

  Device _put(Device device) {
    _box.put(device.id, device);
    return device;
  }
}
