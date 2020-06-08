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
  Future<Response<String>> create(Operation config) {
    final $url = '/operations';
    final $body = config;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<List<Operation>>> fetch() {
    final $url = '/operations';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<List<Operation>, Operation>($request);
  }

  @override
  Future<Response<Operation>> update(String uuid, Operation config) {
    final $url = '/operations/$uuid';
    final $body = config;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<Operation, Operation>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/operations/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }
}
