

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
    required this.decoder,
    required this.reducer,
    this.isPaged = true,
    this.dataField = 'data',
    this.entriesField = 'entries',
  });
  final String dataField;
  final bool isPaged;
  final String entriesField;
  final JsonReducer reducer;
  final JsonDecoder<D>? decoder;
  Type get decodedType => typeOf<D>();
  Type get reducedType => typeOf<R>();
  Map<Type, JsonDecoder> get decoders => {
        decodedType: (json) => json[dataField] == null ? null : decoder!(json[dataField]),
        (isPaged ? typeOf<PagedList<D>>() : typeOf<List<D>>()): (json) => JsonUtils.toPagedList(
              json,
              decoder,
              dataField: dataField,
              entriesField: entriesField,
            ),
      };
}

abstract class ServiceDelegate<S extends Service> implements Service {
  S get delegate;
}

abstract class JsonServiceDelegate<S extends JsonService<D, R>, D, R> implements Service {
  S get delegate;
}

mixin JsonServiceGetFromId<S extends JsonService<D, R>, D extends JsonObject, R> on JsonServiceDelegate<S, D, R> {
  Future<ServiceResponse<D>> getFromId(String id) async {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin JsonServiceGetList<S extends JsonService<D, R>, D extends JsonObject, R> on JsonServiceDelegate<S, D, R> {
  Future<ServiceResponse<List<D>>> getList({
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final body = <D>[];
    var response = await getSubList(
      offset,
      limit,
      options,
    );
    while (response.is200) {
      body.addAll(response.body!);
      if (response.page!.hasNext) {
        response = await getSubList(
          response.page!.next,
          response.page!.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: body);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<D>>> getSubList(
    int? offset,
    int? limit,
    List<String> options,
  ) {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin JsonServiceGetListFromId<S extends JsonService<D, R>, D extends JsonObject, R> on JsonServiceDelegate<S, D, R> {
  Future<ServiceResponse<List<D>>> getListFromId(
    String id, {
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final items = <D>[];
    var response = await getSubListFromId(
      id,
      offset,
      limit,
      options,
    );
    while (response.is200) {
      items.addAll(response.body!);
      if (response.page!.hasNext) {
        response = await getSubListFromId(
          id,
          response.page!.next,
          response.page!.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: items);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<D>>> getSubListFromId(
    String id,
    int? offset,
    int? limit,
    List<String> options,
  ) {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin JsonServiceGetFromIds<S extends JsonService<D, R>, D extends JsonObject, R> on JsonServiceDelegate<S, D, R> {
  Future<ServiceResponse<D>> getFromIds(String id1, String id2) async {
    throw UnimplementedError("get not implemented");
  }
}

mixin JsonServiceGetListFromIds<S extends JsonService<D, R>, D extends JsonObject, R> on JsonServiceDelegate<S, D, R> {
  Future<ServiceResponse<List<D>>> getListFromIds(
    String id1,
    String id2, {
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final items = <D>[];
    var response = await getSubListFromIds(
      id1,
      id2,
      offset,
      limit,
      options,
    );
    while (response.is200) {
      items.addAll(response.body!);
      if (response.page!.hasNext) {
        response = await getSubListFromIds(
          id1,
          id2,
          response.page!.next,
          response.page!.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: items);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<D>>> getSubListFromIds(
    String id1,
    String id2,
    int? offset,
    int? limit,
    List<String> options,
  ) {
    throw UnimplementedError("fetch not implemented");
  }
}

class ServiceResponse<D> extends Equatable {
  final D? body;
  final Object? error;
  final int? statusCode;
  final PageResult? page;
  final ConflictModel? conflict;
  final String? reasonPhrase;
  final StackTrace? stackTrace;

  ServiceResponse({
    this.body,
    this.page,
    this.error,
    this.conflict,
    this.stackTrace,
    this.statusCode,
    this.reasonPhrase,
  });

  @override
  List<Object?> get props => [
        body,
        page,
        error,
        conflict,
        stackTrace,
        statusCode,
        reasonPhrase,
      ];

  ServiceResponse<D> copyWith<D>({
    D? body,
    Object? error,
    int? statusCode,
    String? reasonPhrase,
    ConflictModel? conflict,
  }) {
    return ServiceResponse<D>(
      page: page,
      stackTrace: stackTrace,
      body: body ?? this.body as D?,
      error: error ?? this.error,
      conflict: conflict ?? this.conflict,
      statusCode: statusCode ?? statusCode,
      reasonPhrase: reasonPhrase ?? reasonPhrase,
    );
  }

  static ServiceResponse<D> ok<D>({D? body}) {
    return ServiceResponse<D>(
      statusCode: 200,
      reasonPhrase: 'OK',
      body: body,
    );
  }

  static ServiceResponse<D> created<D>() {
    return ServiceResponse<D>(
      statusCode: 201,
      reasonPhrase: 'Created',
    );
  }

  static ServiceResponse<D> noContent<D>({String message = 'No content'}) {
    return ServiceResponse<D>(
      statusCode: 204,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<D> badRequest<D>({message: 'Bad request'}) {
    return ServiceResponse<D>(
      statusCode: 400,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<D> unauthorized<D>({message: 'Unauthorized', Object? error}) {
    return ServiceResponse<D>(
      error: error,
      statusCode: 401,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<D> forbidden<D>({message: 'Forbidden'}) {
    return ServiceResponse<D>(
      statusCode: 403,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<D> notFound<D>({message: 'Not found'}) {
    return ServiceResponse<D>(
      statusCode: 404,
      reasonPhrase: message,
    );
  }

  static ServiceResponse<D> asConflict<D>({required ConflictModel conflict, message: 'Conflict'}) {
    return ServiceResponse<D>(
      statusCode: 409,
      reasonPhrase: message,
      conflict: conflict,
    );
  }

  static ServiceResponse<D> internalServerError<D>({
    Object? error,
    StackTrace? stackTrace,
    message: 'Internal server error',
  }) {
    return ServiceResponse<D>(
      error: error,
      statusCode: 500,
      reasonPhrase: message,
      stackTrace: stackTrace,
    );
  }

  static ServiceResponse<D> badGateway<D>({
    Object? error,
    StackTrace? stackTrace,
    message: 'Bad gateway',
  }) {
    return ServiceResponse<D>(
      error: error,
      statusCode: 502,
      reasonPhrase: message,
      stackTrace: stackTrace,
    );
  }

  static ServiceResponse<D> gatewayTimeout<D>({
    Object? error,
    StackTrace? stackTrace,
    message: 'Gateway timeout',
  }) {
    return ServiceResponse<D>(
      error: error,
      statusCode: 504,
      reasonPhrase: message,
      stackTrace: stackTrace,
    );
  }

  bool get isErrorCode => (statusCode ?? 0) >= 400;
  bool get isOK => is200 || is201 || is202 || is204;
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
    return '$runtimeType{\n'
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
  final StackTrace? stackTrace;
  final ServiceResponse? response;

  bool get is200 => response!.is200;
  bool get is201 => response!.is201;
  bool get is202 => response!.is202;
  bool get is204 => response!.is204;
  bool get is206 => response!.is206;
  bool get is400 => response!.is400;
  bool get is401 => response!.is401;
  bool get is403 => response!.is403;
  bool get is404 => response!.is404;
  bool get is409 => response!.is409;
  bool get is500 => response!.is500;
  bool get is502 => response!.is500;
  bool get is503 => response!.is503;
  bool get is504 => response!.is500;

  ConflictModel? get conflict => response!.conflict;

  @override
  String toString() {
    return '$runtimeType: $error, response: $response, stackTrace: $stackTrace';
  }

  Map<String, dynamic> toJson() => {
        'error': error,
        'stackTrace': stackTrace.toString(),
        'response': {
          'reasonText': response!.error,
          'statusCode': response!.statusCode,
          if (response!.conflict != null) 'conflict': response!.conflict!.toJson(),
          if (response!.stackTrace != null) 'stackTrace': response!.stackTrace.toString(),
        }
      };
}

class PagedList<D> {
  PagedList(this.items, this.page);
  final List<D> items;
  final PageResult page;
}

class PageResult {
  PageResult({
    this.next,
    this.total,
    this.limit,
    this.offset,
  });
  final int? next;
  final int? total;
  final int? limit;
  final int? offset;

  bool get hasNext => next != null && next! < total!;

  factory PageResult.from(Map<String, dynamic> body) => PageResult(
        next: body['next'],
        total: body['total'],
        limit: body['limit'],
        offset: body['offset'],
      );
}
