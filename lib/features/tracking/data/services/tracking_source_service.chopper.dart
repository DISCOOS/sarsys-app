// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_source_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$TrackingSourceServiceImpl extends TrackingSourceServiceImpl {
  _$TrackingSourceServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = TrackingSourceServiceImpl;

  @override
  Future<Response<TrackingSource>> get(dynamic tuuid, dynamic suuid) {
    final $url = '/trackings/$tuuid/sources/$suuid';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<TrackingSource, TrackingSource>($request);
  }

  @override
  Future<Response<PagedList<TrackingSource>>> fetchAll(
      dynamic tuuid, int offset, int limit,
      {List<String> expand = const []}) {
    final $url = '/trackings/$tuuid/sources';
    final $params = <String, dynamic>{
      'offset': offset,
      'limit': limit,
      'expand': expand
    };
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<TrackingSource>, TrackingSource>($request);
  }

  @override
  Future<Response<String>> create(dynamic tuuid, TrackingSource body) {
    final $url = '/trackings/$tuuid/sources';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<void>> delete(String tuuid, String suuid) {
    final $url = '/trackings/{tuuid}/sources/{suuid}';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }
}
