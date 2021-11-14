// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$AppConfigServiceImpl extends AppConfigServiceImpl {
  _$AppConfigServiceImpl([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = AppConfigServiceImpl;

  @override
  Future<Response<String>> create(String? uuid, AppConfig body) {
    final $url = '/app-configs';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<StorageState<AppConfig>>> update(
      String? uuid, AppConfig body) {
    final $url = '/app-configs/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<StorageState<AppConfig>, AppConfig>($request);
  }

  @override
  Future<Response<void>> delete(String? uuid) {
    final $url = '/app-configs/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }

  @override
  Future<Response<StorageState<AppConfig>>> get(dynamic uuid) {
    final $url = '/app-configs/$uuid';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<StorageState<AppConfig>, AppConfig>($request);
  }
}
