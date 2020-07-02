// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$DeviceServiceImpl extends DeviceServiceImpl {
  _$DeviceServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = DeviceServiceImpl;

  @override
  Future<Response<String>> create(Device body) {
    final $url = '/devices/devices';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<PagedList<Device>>> fetch() {
    final $url = '/devices';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<PagedList<Device>, Device>($request);
  }

  @override
  Future<Response<Device>> update(String uuid, Device body) {
    final $url = '/devices/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<Device, Device>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/devices/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }
}
