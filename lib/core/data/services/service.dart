import 'dart:io';

import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:chopper/chopper.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/domain/models/core.dart';

abstract class Service {}

abstract class JsonService<D, R> extends ChopperService implements Service {
  JsonService({
    @required this.decoder,
    @required this.reducer,
    this.isPaged = true,
    this.dataField = 'data',
    this.entriesField = 'entries',
  });
  final String dataField;
  final bool isPaged;
  final String entriesField;
  final JsonReducer reducer;
  final JsonDecoder<D> decoder;
  Type get decodedType => typeOf<D>();
  Type get reducedType => typeOf<R>();
  Map<Type, JsonDecoder> get decoders => {
        decodedType: (json) => json[dataField] == null ? null : decoder(json[dataField]),
        (isPaged ? typeOf<PagedList<D>>() : typeOf<List<D>>()): (json) => JsonUtils.toPagedList(
              json,
              decoder,
              dataField: dataField,
              entriesField: entriesField,
            ),
      };
}

abstract class ServiceDelegate<S> implements Service {
  S get delegate;
}

mixin ServiceGetFromId<T extends JsonObject> {
  Future<ServiceResponse<T>> getFromId(String id) async {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin ServiceGetList<T extends JsonObject> {
  Future<ServiceResponse<List<T>>> getList({
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final body = <T>[];
    var response = await getSubList(
      offset,
      limit,
      options,
    );
    while (response.is200) {
      body.addAll(response.body);
      if (response.page.hasNext) {
        response = await getSubList(
          response.page.next,
          response.page.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: body);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<T>>> getSubList(
    int offset,
    int limit,
    List<String> options,
  ) {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin ServiceGetListFromId<T extends JsonObject> {
  Future<ServiceResponse<List<T>>> getListFromId(
    String id, {
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final items = <T>[];
    var response = await getSubListFromId(
      id,
      offset,
      limit,
      options,
    );
    while (response.is200) {
      items.addAll(response.body);
      if (response.page.hasNext) {
        response = await getSubListFromId(
          id,
          response.page.next,
          response.page.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: items);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<T>>> getSubListFromId(
    String id,
    int offset,
    int limit,
    List<String> options,
  ) {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin ServiceGetFromIds<T extends JsonObject> {
  Future<ServiceResponse<T>> getFromIds(String id1, String id2) async {
    throw UnimplementedError("get not implemented");
  }
}

mixin ServiceGetListFromIds<T extends JsonObject> {
  Future<ServiceResponse<List<T>>> getListFromIds(
    String id1,
    String id2, {
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final items = <T>[];
    var response = await getSubListFromIds(
      id1,
      id2,
      offset,
      limit,
      options,
    );
    while (response.is200) {
      items.addAll(response.body);
      if (response.page.hasNext) {
        response = await getSubListFromIds(
          id1,
          id2,
          response.page.next,
          response.page.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: items);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<T>>> getSubListFromIds(
    String id1,
    String id2,
    int offset,
    int limit,
    List<String> options,
  ) {
    throw UnimplementedError("fetch not implemented");
  }
}

class ServiceResponse<T> extends Equatable {
  final T body;
  final Object error;
  final int statusCode;
  final PageResult page;
  final ConflictModel conflict;
  final String reasonPhrase;
  final StackTrace stackTrace;

  ServiceResponse({
    this.body,
    this.page,
    this.error,
    this.conflict,
    this.stackTrace,
    this.statusCode,
    this.reasonPhrase,
  }) : super([
          body,
          page,
          error,
          conflict,
          stackTrace,
          statusCode,
          reasonPhrase,
        ]);

  ServiceResponse<T> copyWith<T>({T body, int code, String message}) {
    return ServiceResponse<T>(
      page: page,
      error: error,
      body: body ?? body,
      conflict: conflict,
      stackTrace: stackTrace,
      statusCode: code ?? code,
      reasonPhrase: message ?? message,
    );
  }

  static ServiceResponse<T> ok<T>({T body}) {
    return ServiceResponse<T>(
      statusCode: 200,
      reasonPhrase: 'OK',
      body: body,
    );
  }

  static ServiceResponse<T> created<T>() {
    return ServiceResponse<T>(
      statusCode: 201,
      reasonPhrase: 'Created',
    );
  }

  static ServiceResponse<T> noContent<T>({String message = 'No content'}) {
    return ServiceResponse<T>(
      statusCode: 204,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<T> badRequest<T>({message: 'Bad request'}) {
    return ServiceResponse<T>(
      statusCode: 400,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<T> unauthorized<T>({message: 'Unauthorized', Object error}) {
    return ServiceResponse<T>(
      error: error,
      statusCode: 401,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<T> forbidden<T>({message: 'Forbidden'}) {
    return ServiceResponse<T>(
      statusCode: 403,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<T> notFound<T>({message: 'Not found'}) {
    return ServiceResponse<T>(
      statusCode: 404,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<T> asConflict<T>({@required ConflictModel conflict, message: 'Conflict'}) {
    return ServiceResponse<T>(
      statusCode: 409,
      reasonPhrase: message,
      conflict: conflict,
    );
  }

  static ServiceResponse<T> internalServerError<T>({
    Object error,
    StackTrace stackTrace,
    message: 'Internal server error',
  }) {
    return ServiceResponse<T>(
      error: error,
      statusCode: 500,
      reasonPhrase: message,
      stackTrace: stackTrace,
    );
  }

  static ServiceResponse<T> badGateway<T>({
    Object error,
    StackTrace stackTrace,
    message: 'Bad gateway',
  }) {
    return ServiceResponse<T>(
      error: error,
      statusCode: 502,
      reasonPhrase: message,
      stackTrace: stackTrace,
    );
  }

  static ServiceResponse<T> gatewayTimeout<T>({
    Object error,
    StackTrace stackTrace,
    message: 'Gateway timeout',
  }) {
    return ServiceResponse<T>(
      error: error,
      statusCode: 504,
      reasonPhrase: message,
      stackTrace: stackTrace,
    );
  }

  bool get isErrorCode => (statusCode ?? 0) >= 400;
  bool get isErrorTemporary => is429 || is503 || is504;

  bool get is200 => statusCode == HttpStatus.ok;
  bool get is201 => statusCode == HttpStatus.created;
  bool get is202 => statusCode == HttpStatus.accepted;
  bool get is204 => statusCode == HttpStatus.noContent;
  bool get is206 => statusCode == HttpStatus.partialContent;
  bool get is400 => statusCode == HttpStatus.badRequest;
  bool get is401 => statusCode == HttpStatus.unauthorized;
  bool get is403 => statusCode == HttpStatus.forbidden;
  bool get is404 => statusCode == HttpStatus.notFound;
  bool get is409 => statusCode == HttpStatus.conflict;
  bool get is429 => statusCode == HttpStatus.tooManyRequests;
  bool get is500 => statusCode == HttpStatus.internalServerError;
  bool get is502 => statusCode == HttpStatus.badGateway;
  bool get is503 => statusCode == HttpStatus.serviceUnavailable;
  bool get is504 => statusCode == HttpStatus.gatewayTimeout;

  @override
  String toString() {
    return 'ServiceResponse{\n'
        'body: $body, \n'
        'error: $error, \n'
        'statusCode: $statusCode, \n'
        'page: $page, \n'
        'conflict: $conflict, \n'
        'reasonPhrase: $reasonPhrase, \n'
        'stackTrace: $stackTrace\n'
        '}';
  }
}

class ServiceException implements Exception {
  ServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  bool get is200 => response.is200;
  bool get is201 => response.is201;
  bool get is202 => response.is202;
  bool get is204 => response.is204;
  bool get is206 => response.is206;
  bool get is400 => response.is400;
  bool get is401 => response.is401;
  bool get is403 => response.is403;
  bool get is404 => response.is404;
  bool get is409 => response.is409;
  bool get is500 => response.is500;
  bool get is502 => response.is500;
  bool get is503 => response.is503;
  bool get is504 => response.is500;

  ConflictModel get conflict => response.conflict;

  @override
  String toString() {
    return '$runtimeType: $error, response: $response, stackTrace: $stackTrace';
  }
}

class PagedList<T> {
  PagedList(this.items, this.page);
  final List<T> items;
  final PageResult page;
}

class PageResult {
  PageResult({
    this.next,
    this.total,
    this.limit,
    this.offset,
  });
  final int next;
  final int total;
  final int limit;
  final int offset;

  bool get hasNext => next != null && next < total ?? 0;

  factory PageResult.from(Map<String, dynamic> body) => PageResult(
        next: body['next'],
        total: body['total'],
        limit: body['limit'],
        offset: body['offset'],
      );
}
