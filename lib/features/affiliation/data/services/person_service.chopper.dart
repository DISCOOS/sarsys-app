// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$PersonServiceImpl extends PersonServiceImpl {
  _$PersonServiceImpl([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = PersonServiceImpl;

  @override
  Future<Response<String>> create(Person body) {
    final $url = '/persons';
    final $body = body;
    final $request = Request('POST', $url, client.baseUrl, body: $body);
    return client.send<String, String>($request);
  }

  @override
  Future<Response<Person>> get({String uuid}) {
    final $url = '/persons/$uuid';
    final $request = Request('GET', $url, client.baseUrl);
    return client.send<Person, Person>($request);
  }

  @override
  Future<Response<Person>> update(String uuid, Person body) {
    final $url = '/persons/$uuid';
    final $body = body;
    final $request = Request('PATCH', $url, client.baseUrl, body: $body);
    return client.send<Person, Person>($request);
  }

  @override
  Future<Response<void>> delete(String uuid) {
    final $url = '/persons/$uuid';
    final $request = Request('DELETE', $url, client.baseUrl);
    return client.send<void, void>($request);
  }
}
