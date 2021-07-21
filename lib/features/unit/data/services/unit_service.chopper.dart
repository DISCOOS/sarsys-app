// @dart=2.11

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
  Future<Response<String>> create(dynamic ouuid, Unit body) {
    final $url = '/operations/$ouuid/units';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<StorageState<Unit>>> update(String uuid, Unit personnel) {
    final $url = 'units/$uuid';
    final $body = personnel;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<Unit>, Unit>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = 'units/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Unit>>>> onGetPageFromId(
      String id, int offset, int limit, List<String> options) {
    final $url = '/operations/$id/units';
    final $params = <String, dynamic>{'offset': offset, 'limit': limit};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<StorageState<Unit>>, Unit>($request);
  }
}
