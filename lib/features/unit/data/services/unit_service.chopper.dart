// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$UnitServiceImpl extends UnitServiceImpl {
  _$UnitServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = UnitServiceImpl;

  @override
  Future<Response<String>> create(Unit unit) {
    final $url = '/units';
    final $body = unit;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<List<Unit>>> fetch() {
    final $url = '/units';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<List<Unit>, Unit>($request);
  }

  @override
  Future<Response<Unit>> update(String uuid, Unit config) {
    final $url = '/units/$uuid';
    final $body = config;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<Unit, Unit>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/units/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }
}
