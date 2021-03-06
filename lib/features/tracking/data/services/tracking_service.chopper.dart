// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$TrackingServiceImpl extends TrackingServiceImpl {
  _$TrackingServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = TrackingServiceImpl;

  @override
  Future<Response<StorageState<Tracking>>> update(String uuid, Tracking body) {
    final $url = '/trackings/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<Tracking>, Tracking>($request);
  }

  @override
  Future<Response<StorageState<Tracking>>> get(dynamic uuid,
      {List<String> expand = const []}) {
    final $url = '/trackings/$uuid';
    final $params = <String, dynamic>{'expand': expand};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<StorageState<Tracking>, Tracking>($request);
  }

  @override
  Future<Response<PagedList<StorageState<Tracking>>>> getAll(
      dynamic ouuid, int offset, int limit,
      {List<String> expand = const []}) {
    final $url = '/operations/$ouuid/trackings';
    final $params = <String, dynamic>{
      'offset': offset,
      'limit': limit,
      'expand': expand
    };
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<StorageState<Tracking>>, Tracking>($request);
  }
}
