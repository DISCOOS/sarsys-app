// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personnel_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$PersonnelServiceImpl extends PersonnelServiceImpl {
  _$PersonnelServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = PersonnelServiceImpl;

  @override
  Future<Response<String>> create(dynamic ouuid, Personnel body) {
    final $url = '/operations/{uuid}/personnels';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<PagedList<Personnel>>> fetch(
      dynamic ouuid, int offset, int limit) {
    final $url = '/operations/$ouuid/personnels';
    final $params = <String, dynamic>{'offset': offset, 'limit': limit};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<Personnel>, Personnel>($request);
  }

  @override
  Future<Response<Personnel>> update(String uuid, Personnel personnel) {
    final $url = 'personnels/$uuid';
    final $body = personnel;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<Personnel, Personnel>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = 'personnels/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }
}
