// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$AppConfigServiceImpl extends AppConfigServiceImpl {
  _$AppConfigServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = AppConfigServiceImpl;

  @override
  Future<Response<String>> create(AppConfig config) {
    final $url = '/app-configs';
    final $body = config;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<AppConfig>> fetch(String uuid) {
    final $url = '/app-configs/$uuid';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<AppConfig, AppConfig>($request);
  }

  @override
  Future<Response<AppConfig>> update(String uuid, AppConfig config) {
    final $url = '/app-configs/$uuid';
    final $body = config;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<AppConfig, AppConfig>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/app-configs/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }
}
