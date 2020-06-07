import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class ServiceResponse<T> extends Equatable {
  final int statusCode;
  final String reasonPhrase;
  final T body;
  final Object error;
  final Conflict conflict;
  final StackTrace stackTrace;

  ServiceResponse({this.statusCode, this.reasonPhrase, this.body, this.conflict, this.error, this.stackTrace})
      : super([statusCode, reasonPhrase, body, conflict, error, stackTrace]);

  ServiceResponse<T> copyWith<T>({T body, int code, String message}) {
    return ServiceResponse<T>(
      body: body ?? body,
      statusCode: code ?? code,
      reasonPhrase: message ?? message,
      stackTrace: stackTrace,
      conflict: conflict,
      error: error,
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

  static ServiceResponse<T> asConflict<T>({@required Conflict conflict, message: 'Conflict'}) {
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
  bool get is409 => statusCode == HttpStatus.conflict;
  bool get is500 => statusCode == HttpStatus.internalServerError;
}

class Conflict {
  Conflict(Map<String, dynamic> mine, Map<String, dynamic> theirs)
      : _mine = Map.unmodifiable(mine),
        _theirs = Map.unmodifiable(theirs);

  final Map<String, dynamic> _mine;
  Map<String, dynamic> get mine => _mine;

  final Map<String, dynamic> _theirs;
  Map<String, dynamic> get theirs => _theirs;
}
