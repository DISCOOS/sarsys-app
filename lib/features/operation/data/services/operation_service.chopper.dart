// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$OperationServiceImpl extends OperationServiceImpl {
  _$OperationServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = OperationServiceImpl;

  @override
  Future<Response<String>> create(String iuuid, Operation body) {
    final $url = '/incidents/$iuuid/operations';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<StorageState<Operation>>> update(
      String uuid, Operation body) {
    final $url = '/operations/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<Operation>, Operation>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/operations/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Operation>>>> fetch(
      int offset, int limit) {
    final $url = '/operations';
    final $params = <String, dynamic>{'offset': offset, 'limit': limit};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<StorageState<Operation>>, Operation>($request);
  }
}
