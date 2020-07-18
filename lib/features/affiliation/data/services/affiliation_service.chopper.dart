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
  Future<Response<Affiliation>> get({String uuid}) {
    final $url = '/affiliations/$uuid';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<Affiliation, Affiliation>($request);
  }

  @override
  Future<Response<PagedList<Affiliation>>> fetch(String filter,
      {int offset = 0, int limit = 20}) {
    final $url = '/affiliations';
    final $params = <String, dynamic>{
      'filter': filter,
      'offset': offset,
      'limit': limit
    };
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<Affiliation>, Affiliation>($request);
  }

  @override
  Future<Response<String>> create(Affiliation body) {
    final $url = '/affiliations';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<Affiliation>> update(String uuid, Affiliation body) {
    final $url = '/affiliations/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<Affiliation, Affiliation>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/affiliations/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }
}
