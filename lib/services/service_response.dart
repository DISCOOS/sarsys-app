import 'package:equatable/equatable.dart';

class ServiceResponse<T> extends Equatable {
  final int code;
  final String message;
  final T body;

  ServiceResponse({this.code, this.message, this.body}) : super([code, message, body]);

  static ServiceResponse<T> ok<T>({T body}) {
    return ServiceResponse<T>(
      code: 200,
      message: 'OK',
      body: body,
    );
  }

  static ServiceResponse<void> noContent() {
    return ServiceResponse<void>(
      code: 204,
      message: 'No content',
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

  static ServiceResponse<T> error<T>({message: 'Error', Object error}) {
    return ServiceResponse<T>(code: 500, message: message, body: error);
  }

  bool get is200 => code == 200;
  bool get is204 => code == 204;
  bool get is401 => code == 401;
  bool get is403 => code == 403;
  bool get is500 => code == 500;
}
