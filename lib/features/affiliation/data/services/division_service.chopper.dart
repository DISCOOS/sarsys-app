// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'division_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$DivisionServiceImpl extends DivisionServiceImpl {
  _$DivisionServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = DivisionServiceImpl;

  @override
  Future<Response<String>> create(String uuid, Division body) {
    final $url = '/organisations/$uuid/divisions';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<StorageState<Division>>> update(String uuid, Division body) {
    final $url = '/divisions/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<Division>, Division>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/divisions/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Division>>>> getAll(
      int offset, int limit) {
    final $url = '/divisions';
    final $params = <String, dynamic>{'offset': offset, 'limit': limit};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<StorageState<Division>>, Division>($request);
  }
}
