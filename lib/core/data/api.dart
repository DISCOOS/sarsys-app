import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/data/services/navigation_service.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:random_string/random_string.dart';

class Api {
  Api({
    @required this.users,
    @required this.manager,
    @required this.httpClient,
    @required this.baseRestUrl,
    @required Iterable<JsonService> services,
  }) : chopperClient = ChopperClient(
          services: services,
          baseUrl: baseRestUrl,
          client: IOClient(
            HttpClient()..connectionTimeout = const Duration(seconds: 30),
          ),
          converter: JsonSerializableConverter(
            reducers: Map.fromEntries(
              services.map((s) => MapEntry(s.reducedType, s.reducer)),
            ),
            decoders: Map.from(
              services.fold(
                <Type, JsonDecoder>{},
                (decoders, s) => decoders..addAll(s.decoders),
              ),
            ),
          ),
          interceptors: [
            GzipInterceptor(),
            BearerTokenInterceptor(users),
            SpeedAnalyserRequestInterceptor(),
            TransactionRequestInterceptor(manager),
            TransactionResponseInterceptor(manager),
            if (kDebugMode && Defaults.debugPrintHttp) HttpLoggingInterceptor(),
          ],
        );

  final String baseRestUrl;
  final UserRepository users;
  final http.Client httpClient;
  final TransactionManager manager;
  final ChopperClient chopperClient;

  static ServiceResponse<T> from<S, T>(
    Response<S> response, {
    T body,
    ConflictModel conflict,
    StackTrace stackTrace,
  }) {
    final resolved = body ?? response.body;
    final conflict = response.statusCode == HttpStatus.conflict
        // Chopper will return body with conflict json in response.error
        ? ConflictModel.fromJson(jsonDecode(response.error))
        : null;
    return ServiceResponse<T>(
      conflict: conflict,
      stackTrace: stackTrace,
      statusCode: response.statusCode,
      reasonPhrase: '${response.base.reasonPhrase}',
      page: resolved is PagedList ? resolved.page : null,
      body: resolved is PagedList ? resolved.items : resolved,
      error: response.statusCode == HttpStatus.conflict ? conflict.error : response.error,
    );
  }
}

typedef JsonDecoder<T> = T Function(dynamic json);
typedef JsonReducer<T> = dynamic Function(T value);

class JsonSerializableConverter extends JsonConverter {
  final Map<Type, JsonDecoder> decoders;
  final Map<Type, JsonReducer> reducers;

  JsonSerializableConverter({this.decoders, this.reducers});

  @override
  Request encodeJson(Request request) {
    var contentType = request.headers[contentTypeKey];
    if (contentType != null && contentType.contains(jsonHeaders)) {
      return _reduce(request);
    }
    return request;
  }

  Request _reduce(Request request) {
    final value = request.body;

    /// Get reducer factory from runtime type
    final encoder = reducers[value.runtimeType];
    if (encoder == null || encoder is! JsonReducer) {
      return request.copyWith(body: json.encode(value));
    }
    return request.copyWith(body: json.encode(encoder(value)));
  }

  @override
  Response<ResultType> convertResponse<ResultType, Model>(Response response) {
    if (emptyAsNull(response.body) != null) {
      final jsonRes = super.convertResponse(response);
      final jsonBody = emptyAsNull(jsonRes.body) ?? <String, dynamic>{};
      return Response<ResultType>(
        response.base,
        _decode<ResultType>(jsonBody),
        error: response.error,
      );
    }
    return Response<ResultType>(
      response.base,
      null,
      error: response.error,
    );
  }

  T _decodeMap<T>(Map<String, dynamic> values) {
    /// Get json decoder factory using Type parameters
    /// if not found or invalid, throw error or return null
    final decoder = decoders[T];
    if (decoder == null || decoder is! JsonDecoder<T>) {
      /// throw serializer not found error
      throw StateError('JsonDecoder factory not found for type $T');
    }

    return decoder(values);
  }

  List<T> _decodeList<T>(List values) => values.where((v) => v != null).map<T>((v) => _decode<T>(v)).toList();

  dynamic _decode<T>(entity) {
    if (entity is Iterable) {
      return _decodeList<T>(entity);
    } else if (entity is Map) {
      return _decodeMap<T>(entity);
    }
    return entity;
  }

// TODO: Implement common api error object
//  Response convertError<ResultType, Data>(Response response) {
//    // Use [JsonConverter] to decode json
//    final jsonRes = super.convertError(response);
//
//    return jsonRes.copyWith<ResourceError>(
//      body: ResourceError.fromJsonFactory(jsonRes.body),
//    );
//  }
}

class BearerTokenInterceptor implements RequestInterceptor {
  BearerTokenInterceptor(this.users);
  final UserRepository users;

  @override
  FutureOr<Request> onRequest(Request request) async {
    if (users.isAuthenticated) {
      if (users.isTokenExpired) {
        try {
          await users.refresh();
        } on Exception catch (e) {
          debugPrint('Failed to refresh token: $e');
          return request;
        }
      }
      return applyHeader(
        request,
        'Authorization',
        'Bearer ${users.token.accessToken}',
      );
    }
    return request;
  }
}

class GzipInterceptor implements RequestInterceptor {
  GzipInterceptor();

  @override
  FutureOr<Request> onRequest(Request request) async {
    return applyHeader(
      request,
      'Content-Encoding',
      'gzip',
    );
  }
}

const String X_POD_NAME = 'x-pod-name';
const String X_CORRELATION_ID = 'x-correlation-id';
const String X_TRANSACTION_ID = 'x-transaction-id';

class TransactionManager {
  String id;
  String instance;
  String begin() {
    return id ??= randomAlphaNumeric(8);
  }

  Response complete(Response response) {
    if (instance != response.headers[X_POD_NAME]) {
      instance = response.headers[X_POD_NAME];
      debugPrint('Transaction instance changed to $instance');
    }
    if (id != response.headers[X_TRANSACTION_ID]) {
      final id = response.headers[X_TRANSACTION_ID];
      debugPrint('Transaction id changed to $id');
    }
    return response;
  }
}

class TransactionRequestInterceptor implements RequestInterceptor {
  TransactionRequestInterceptor(this.manager);
  final TransactionManager manager;

  @override
  FutureOr<Request> onRequest(Request request) async {
    return applyHeader(
      request,
      'Cookie',
      '$X_TRANSACTION_ID=${manager.begin()}',
      override: true,
    );
  }
}

class SpeedAnalyserRequestInterceptor implements RequestInterceptor, ResponseInterceptor {
  SpeedAnalyserRequestInterceptor();

  static const _methods = const <String>['get', 'post', 'patch', 'put'];

  final _requests = <String, DateTime>{};

  String toKeyFromRequest(Request request) => '${request.method} '
      '${buildUri(request.baseUrl, request.url, request.parameters)}';

  String toKeyFromResponse(Response response) => '${response.base.request.method} ${response.base.request.url}';

  @override
  FutureOr<Request> onRequest(Request request) async {
    if (_methods.contains(request.method.toLowerCase())) {
      _requests[toKeyFromRequest(request)] = DateTime.now();
    }
    return request;
  }

  @override
  FutureOr<Response> onResponse(Response response) {
    final tic = _requests.remove(toKeyFromResponse(response));
    if (tic != null) {
      final request = response.base.request;
      final method = request.method.toLowerCase();
      final duration = DateTime.now().difference(tic);
      final both = method == 'get';
      final size = (both ? request.contentLength : 0) + response.base.contentLength;
      final speed = size / duration.inMilliseconds * (both ? 2 : 1);
      ConnectivityService().onSpeedResult(
        SpeedResult(
          size,
          (speed * 1000).toInt(),
          method,
          duration,
        ),
      );
    }
    return response;
  }
}

class TransactionResponseInterceptor implements ResponseInterceptor {
  TransactionResponseInterceptor(this.manager);
  final TransactionManager manager;

  @override
  FutureOr<Response> onResponse(Response response) {
    if (response.statusCode == 401) {
      // Prompt user to login
      NavigationService().pushReplacementNamed(
        LoginScreen.ROUTE,
      );
    }
    return manager.complete(response);
  }
}
