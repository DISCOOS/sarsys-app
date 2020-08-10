import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/domain/models/core.dart';

abstract class Service {}

abstract class ServiceDelegate<S> implements Service {
  S get delegate;
}

mixin ServiceGet<T extends Aggregate> {
  Future<ServiceResponse<T>> get(String uuid) async {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin ServiceFetchAll<T extends Aggregate> {
  Future<ServiceResponse<List<T>>> fetchAll({int offset = 0, int limit = 20}) async {
    final body = <T>[];
    var response = await fetch(offset, limit);
    while (response.is200) {
      body.addAll(response.body);
      if (response.page.hasNext) {
        response = await fetch(
          response.page.next,
          response.page.limit,
        );
      } else {
        return ServiceResponse.ok(body: body);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<T>>> fetch(int offset, int limit) {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin ServiceFetchDescendants<T extends Aggregate> {
  Future<ServiceResponse<List<T>>> fetchAll(
    String uuid, {
    int offset = 0,
    int limit = 20,
  }) async {
    final divisions = <T>[];
    var response = await fetch(uuid, offset, limit);
    while (response.is200) {
      divisions.addAll(response.body);
      if (response.page.hasNext) {
        response = await fetch(
          uuid,
          response.page.next,
          response.page.limit,
        );
      } else {
        return ServiceResponse.ok(body: divisions);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<T>>> fetch(String uuid, int offset, int limit) {
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
          statusCode,
          reasonPhrase,
          body,
          conflict,
          error,
          stackTrace,
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

  static ServiceResponse<T> unauthorized<T>({message: 'Unauthorized'}) {
    return ServiceResponse<T>(
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
    message: 'Internal server error',
    Object error,
    StackTrace stackTrace,
  }) {
    return ServiceResponse<T>(
      statusCode: 500,
      reasonPhrase: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  bool get is200 => statusCode == HttpStatus.ok;
  bool get is201 => statusCode == HttpStatus.created;
  bool get is202 => statusCode == HttpStatus.accepted;
  bool get is204 => statusCode == HttpStatus.noContent;
  bool get is400 => statusCode == HttpStatus.badRequest;
  bool get is401 => statusCode == HttpStatus.unauthorized;
  bool get is403 => statusCode == HttpStatus.forbidden;
  bool get is404 => statusCode == HttpStatus.notFound;
  bool get is406 => statusCode == HttpStatus.partialContent;
  bool get is409 => statusCode == HttpStatus.conflict;
  bool get is500 => statusCode == HttpStatus.internalServerError;
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
