// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_track_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$TrackingTrackServiceImpl extends TrackingTrackServiceImpl {
  _$TrackingTrackServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = TrackingTrackServiceImpl;

  @override
  Future<Response<StorageState<TrackingTrack>>> get(dynamic uuid, dynamic id) {
    final $url = '/trackings/$uuid/tracks/$id';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<StorageState<TrackingTrack>, TrackingTrack>($request);
  }

  @override
  Future<Response<PagedList<StorageState<TrackingTrack>>>> getAll(
      dynamic uuid, int offset, int limit,
      {List<String> expand = const []}) {
    final $url = '/trackings/$uuid/tracks';
    final $params = <String, dynamic>{
      'offset': offset,
      'limit': limit,
      'expand': expand
    };
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client
        .send<PagedList<StorageState<TrackingTrack>>, TrackingTrack>($request);
  }
}
