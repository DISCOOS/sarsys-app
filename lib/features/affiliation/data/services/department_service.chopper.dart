// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'department_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$DepartmentServiceImpl extends DepartmentServiceImpl {
  _$DepartmentServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = DepartmentServiceImpl;

  @override
  Future<Response<String>> create(String uuid, Department body) {
    final $url = '/divisions/$uuid/departments';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<StorageState<Department>>> update(
      String uuid, Department body) {
    final $url = '/departments/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<Department>, Department>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/departments/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Department>>>> getAll(
      int offset, int limit) {
    final $url = '/departments';
    final $params = <String, dynamic>{'offset': offset, 'limit': limit};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client
        .send<PagedList<StorageState<Department>>, Department>($request);
  }
}
