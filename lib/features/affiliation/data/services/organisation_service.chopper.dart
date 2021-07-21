// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organisation_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$OrganisationServiceImpl extends OrganisationServiceImpl {
  _$OrganisationServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = OrganisationServiceImpl;

  @override
  Future<Response<String>> create(String uuid, Organisation body) {
    final $url = '/organisations';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<StorageState<Organisation>>> update(
      String uuid, Organisation body) {
    final $url = '/organisations/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<Organisation>, Organisation>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/organisations/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Organisation>>>> getAll(
      int offset, int limit) {
    final $url = '/organisations';
    final $params = <String, dynamic>{'offset': offset, 'limit': limit};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client
        .send<PagedList<StorageState<Organisation>>, Organisation>($request);
  }
}
