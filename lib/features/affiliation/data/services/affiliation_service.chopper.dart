// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'affiliation_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$AffiliationServiceImpl extends AffiliationServiceImpl {
  _$AffiliationServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = AffiliationServiceImpl;

  @override
  Future<Response<String>> create(Affiliation body) {
    final $url = '/affiliations';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<StorageState<Affiliation>>> update(
      String uuid, Affiliation body) {
    final $url = '/affiliations/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<Affiliation>, Affiliation>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/affiliations/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Affiliation>>>> search(
      String filter, int limit, int offset, String expand) {
    final $url = '/affiliations';
    final $params = <String, dynamic>{
      'filter': filter,
      'limit': limit,
      'offset': offset,
      'expand': expand
    };
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client
        .send<PagedList<StorageState<Affiliation>>, Affiliation>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Affiliation>>>> getAll(String uuids,
      {String expand, int limit = 20, int offset = 0}) {
    final $url = '/affiliations';
    final $params = <String, dynamic>{
      'uuids': uuids,
      'expand': expand,
      'limit': limit,
      'offset': offset
    };
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client
        .send<PagedList<StorageState<Affiliation>>, Affiliation>($request);
  }
}
