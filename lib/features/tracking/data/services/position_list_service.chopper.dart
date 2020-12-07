// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'position_list_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$PositionListServiceImpl extends PositionListServiceImpl {
  _$PositionListServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = PositionListServiceImpl;

  @override
  Future<Response<PagedList<Position>>> getPositions(dynamic uuid, dynamic id, int offset, int limit,
      {List<String> options = const ['truncate:-20:m']}) {
    final $url = '/trackings/$uuid/tracks/$id';
    final $params = <String, dynamic>{'offset': offset, 'limit': limit, 'option': options};
    final $request = Request('GET', $url, client.baseUrl, parameters: $params);
    return client.send<PagedList<Position>, Position>($request);
  }
}
