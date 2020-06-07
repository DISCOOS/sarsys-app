import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/app_config/data/models/app_config_model.dart';
import 'package:SarSys/features/incident/data/models/incident_model.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:SarSys/features/app_config/domain/entities/AppConfig.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/repositories/user_repository.dart';

class Api {
  Api({
    @required this.users,
    @required this.httpClient,
    @required this.baseRestUrl,
    @required Iterable<ChopperService> services,
  }) : chopperClient = ChopperClient(
          services: services,
          baseUrl: baseRestUrl,
          converter: JsonSerializableConverter({
            Unit: (json) => json['data'] == null ? null : Unit.fromJson(json['data']),
            Device: (json) => json['data'] == null ? null : Device.fromJson(json['data']),
            Incident: (json) => json['data'] == null ? null : IncidentModel.fromJson(json['data']),
            typeOf<List<Incident>>(): _toIncidentList,
            Tracking: (json) => json['data'] == null ? null : Tracking.fromJson(json['data']),
            Personnel: (json) => json['data'] == null ? null : Personnel.fromJson(json['data']),
            AppConfig: (json) => json['data'] == null ? null : AppConfigModel.fromJson(json['data']),
          }),
          interceptors: [
            BearerTokenInterceptor(users),
            if (kDebugMode) HttpLoggingInterceptor(),
          ],
        );

  static List<Incident> _toIncidentList(Map<String, dynamic> json) {
    return json['entries'] == null
        ? <Incident>[]
        : List.from(json['entries'])
            .map(
              (json) => IncidentModel.fromJson(json['data']),
            )
            .toList();
  }

  final String baseRestUrl;
  final UserRepository users;
  final http.Client httpClient;
  final ChopperClient chopperClient;

  static ServiceResponse<T> from<S, T>(
    Response<S> response, {
    T body,
    Conflict conflict,
    StackTrace stackTrace,
  }) {
    return ServiceResponse<T>(
      statusCode: response.statusCode,
      reasonPhrase: '${response.base.reasonPhrase}',
      body: body ?? response.body,
      error: response.statusCode == HttpStatus.conflict
          ? ConflictModel.fromJson(jsonDecode(response.error))
          : response.error,
      stackTrace: stackTrace,
      conflict: conflict,
    );
  }
}

typedef T JsonFactory<T>(Map<String, dynamic> json);

class JsonSerializableConverter extends JsonConverter {
  final Map<Type, JsonFactory> factories;

  JsonSerializableConverter(this.factories);

  T _decodeMap<T>(Map<String, dynamic> values) {
    /// Get jsonFactory using Type parameters
    /// if not found or invalid, throw error or return null
    final jsonFactory = factories[T];
    if (jsonFactory == null || jsonFactory is! JsonFactory<T>) {
      /// throw serializer not found error;
      return null;
    }

    return jsonFactory(values);
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

  @override
  Response<ResultType> convertResponse<ResultType, Model>(Response response) {
    // Use [JsonConverter] to decode json?
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
    final token = users.token;
    if (token != null) {
      if (token.isExpired) {
        await users.refresh();
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
