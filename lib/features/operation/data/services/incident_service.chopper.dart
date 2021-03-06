// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$IncidentServiceImpl extends IncidentServiceImpl {
  _$IncidentServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = IncidentServiceImpl;

  @override
  Future<Response<String>> create(String uuid, Incident body) {
    final $url = '/incidents';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<StorageState<Incident>>> update(String uuid, Incident body) {
    final $url = '/incidents/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<Incident>, Incident>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/incidents/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Incident>>>> fetch(
      int offset, int limit) {
    final $url = '/incidents';
    final $params = <String, dynamic>{'offset': offset, 'limit': limit};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<StorageState<Incident>>, Incident>($request);
  }
}
