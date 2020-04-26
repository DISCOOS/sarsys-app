import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class ServiceResponse<T> extends Equatable {
  final int code;
  final String message;
  final T body;
  final Object error;
  final Conflict conflict;
  final StackTrace stackTrace;

  ServiceResponse({this.code, this.message, this.body, this.conflict, this.error, this.stackTrace})
      : super([code, message, body, conflict, error, stackTrace]);

  ServiceResponse<T> copyWith<T>({T body, int code, String message}) {
    return ServiceResponse<T>(
      body: body ?? body,
      code: code ?? code,
      message: message ?? message,
      stackTrace: stackTrace,
      conflict: conflict,
      error: error,
    );
  }

  static ServiceResponse<T> ok<T>({T body}) {
    return ServiceResponse<T>(
      code: 200,
      message: 'OK',
      body: body,
    );
  }

  static ServiceResponse<T> noContent<T>({String message = 'No content'}) {
    return ServiceResponse<T>(
      code: 204,
      message: message,
    );
  }

  static ServiceResponse<T> badRequest<T>({message: 'Bad request'}) {
    return ServiceResponse<T>(
      code: 400,
      message: message,
    );
  }

  static ServiceResponse<T> unauthorized<T>({message: 'Unauthorized'}) {
    return ServiceResponse<T>(
      code: 401,
      message: message,
    );
  }

  static ServiceResponse<T> forbidden<T>({message: 'Forbidden'}) {
    return ServiceResponse<T>(
      code: 403,
      message: message,
    );
  }

  static ServiceResponse<T> notFound<T>({message: 'Not found'}) {
    return ServiceResponse<T>(
      code: 404,
      message: message,
    );
  }

  static ServiceResponse<T> asConflict<T>({@required Conflict conflict, message: 'Conflict'}) {
    return ServiceResponse<T>(
      code: 409,
      message: message,
      conflict: conflict,
    );
  }

  static ServiceResponse<T> internalServerError<T>({
    message: 'Internal server error',
    Object error,
    StackTrace stackTrace,
  }) {
    return ServiceResponse<T>(
      code: 500,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  bool get is200 => code == HttpStatus.ok;
  bool get is201 => code == HttpStatus.created;
  bool get is202 => code == HttpStatus.accepted;
  bool get is204 => code == HttpStatus.noContent;
  bool get is400 => code == HttpStatus.badRequest;
  bool get is401 => code == HttpStatus.unauthorized;
  bool get is403 => code == HttpStatus.forbidden;
  bool get is404 => code == HttpStatus.notFound;
  bool get is500 => code == HttpStatus.internalServerError;
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