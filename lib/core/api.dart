import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/settings/data/models/app_config_model.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/services/service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';

class Api {
  Api({
    @required this.users,
    @required this.httpClient,
    @required this.baseRestUrl,
    @required Iterable<ChopperService> services,
  }) : chopperClient = ChopperClient(
          services: services,
          baseUrl: baseRestUrl,
          converter: JsonSerializableConverter(
            reducers: {
              Tracking: (value) => JsonUtils.toJson<Tracking>(value),
              UnitModel: (value) => JsonUtils.toJson<Unit>(value),
              IncidentModel: (value) => JsonUtils.toJson<Incident>(value),
              OperationModel: (value) => JsonUtils.toJson<Operation>(value),
              PersonnelModel: (value) => JsonUtils.toJson<Personnel>(value),
              AppConfigModel: (value) => JsonUtils.toJson<AppConfig>(value),
              DeviceModel: (value) => JsonUtils.toJson<Device>(value, exclude: const [
                    'uuid',
                    'alias',
                    'number',
                    'allocatedTo',
                  ]),
            },
            decoders: {
              typeOf<List<Unit>>(): _toUnitList,
              typeOf<List<Device>>(): _toDeviceList,
              typeOf<List<Incident>>(): _toIncidentList,
              typeOf<List<Operation>>(): _toOperationList,
              typeOf<List<Personnel>>(): _toPersonnelList,
              Unit: (json) => json['data'] == null ? null : UnitModel.fromJson(json['data']),
              Device: (json) => json['data'] == null ? null : DeviceModel.fromJson(json['data']),
              Incident: (json) => json['data'] == null ? null : IncidentModel.fromJson(json['data']),
              Tracking: (json) => json['data'] == null ? null : Tracking.fromJson(json['data']),
              Operation: (json) => json['data'] == null ? null : OperationModel.fromJson(json['data']),
              Personnel: (json) => json['data'] == null ? null : PersonnelModel.fromJson(json['data']),
              AppConfig: (json) => json['data'] == null ? null : AppConfigModel.fromJson(json['data']),
            },
          ),
          interceptors: [
            BearerTokenInterceptor(users),
            if (kDebugMode) HttpLoggingInterceptor(),
          ],
        );

  static List<Unit> _toUnitList(Map<String, dynamic> json) => _toList<Unit>(
        json,
        (entity) => UnitModel.fromJson(entity['data']),
      );

  static List<Device> _toDeviceList(Map<String, dynamic> json) => _toList<Device>(
        json,
        (entity) => DeviceModel.fromJson(entity['data']),
      );

  static List<Incident> _toIncidentList(Map<String, dynamic> json) => _toList<Incident>(
        json,
        (entity) => IncidentModel.fromJson(entity['data']),
      );

  static List<Personnel> _toPersonnelList(Map<String, dynamic> json) => _toList<Personnel>(
        json,
        (entity) => PersonnelModel.fromJson(entity['data']),
      );

  static List<Operation> _toOperationList(Map<String, dynamic> json) => _toList<Operation>(
        json,
        (entity) => OperationModel.fromJson(entity['data']),
      );

  static List<T> _toList<T>(Map<String, dynamic> json, JsonDecoder<T> factory) => json['entries'] == null
      ? <T>[]
      : List.from(json['entries'])
          .map(
            (json) => factory(json),
          )
          .toList();

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

typedef T JsonDecoder<T>(Map<String, dynamic> json);
typedef Map<String, dynamic> JsonReducer<T>(T value);

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
