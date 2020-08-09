import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/settings/data/models/app_config_model.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:http/io_client.dart';

class Api {
  Api({
    @required this.users,
    @required this.httpClient,
    @required this.baseRestUrl,
    @required Iterable<ChopperService> services,
  }) : chopperClient = ChopperClient(
          services: services,
          baseUrl: baseRestUrl,
          client: IOClient(
            HttpClient()
              ..connectionTimeout = const Duration(seconds: 30)
              ..idleTimeout,
          ),
          converter: JsonSerializableConverter(
            reducers: {
              Tracking: (value) => JsonUtils.toJson<Tracking>(value),
              UnitModel: (value) => JsonUtils.toJson<Unit>(value),
              PersonModel: (value) => JsonUtils.toJson<PersonModel>(value),
              AppConfigModel: (value) => JsonUtils.toJson<AppConfig>(value),
              OrganisationModel: (value) => JsonUtils.toJson<Organisation>(value),
              AffiliationModel: (value) => JsonUtils.toJson<AffiliationModel>(value),
              PersonnelModel: (value) => JsonUtils.toJson<Personnel>(value, remove: const [
                    'person',
                  ]),
              DivisionModel: (value) => JsonUtils.toJson<Division>(value, remove: const [
                    'organisation',
                  ]),
              DepartmentModel: (value) => JsonUtils.toJson<Department>(value, remove: const [
                    'division',
                  ]),
              IncidentModel: (value) => JsonUtils.toJson<Incident>(value, remove: const [
                    'clues',
                    'subjects',
                    'messages',
                    'operations',
                    'transitions',
                  ]),
              OperationModel: (value) => JsonUtils.toJson<Operation>(value, remove: const [
                    'units',
                    'incident',
                    'messages',
                    'missions',
                    'personnels',
                    'objectives',
                    "transitions",
                  ]),
              DeviceModel: (value) => JsonUtils.toJson<Device>(value, remove: const [
                    'type',
                    'manual',
                    'position',
                    'messages',
                    'transitions',
                  ]),
            },
            decoders: {
              typeOf<PagedList<Unit>>(): _toUnitList,
              typeOf<PagedList<Person>>(): _toPersonList,
              typeOf<PagedList<Device>>(): _toDeviceList,
              typeOf<PagedList<Incident>>(): _toIncidentList,
              typeOf<PagedList<Division>>(): _toDivisionList,
              typeOf<PagedList<Operation>>(): _toOperationList,
              typeOf<PagedList<Personnel>>(): _toPersonnelList,
              typeOf<PagedList<Department>>(): _toDepartmentList,
              typeOf<PagedList<Affiliation>>(): _toAffiliationList,
              typeOf<PagedList<Organisation>>(): _toOrganisationList,
              Unit: (json) => json['data'] == null ? null : UnitModel.fromJson(json['data']),
              Tracking: (json) => json['data'] == null ? null : Tracking.fromJson(json['data']),
              Person: (json) => json['data'] == null ? null : PersonModel.fromJson(json['data']),
              Device: (json) => json['data'] == null ? null : DeviceModel.fromJson(json['data']),
              Incident: (json) => json['data'] == null ? null : IncidentModel.fromJson(json['data']),
              Division: (json) => json['data'] == null ? null : DivisionModel.fromJson(json['data']),
              Operation: (json) => json['data'] == null ? null : OperationModel.fromJson(json['data']),
              Personnel: (json) => json['data'] == null ? null : PersonnelModel.fromJson(json['data']),
              AppConfig: (json) => json['data'] == null ? null : AppConfigModel.fromJson(json['data']),
              Department: (json) => json['data'] == null ? null : DepartmentModel.fromJson(json['data']),
              Affiliation: (json) => json['data'] == null ? null : AffiliationModel.fromJson(json['data']),
              Organisation: (json) => json['data'] == null ? null : OrganisationModel.fromJson(json['data']),
            },
          ),
          interceptors: [
            BearerTokenInterceptor(users),
            if (kDebugMode) HttpLoggingInterceptor(),
          ],
        );

  static PagedList<Unit> _toUnitList(Map<String, dynamic> json) => _toPagedList<Unit>(
        json,
        (entity) => UnitModel.fromJson(entity['data']),
      );

  static PagedList<Person> _toPersonList(Map<String, dynamic> json) => _toPagedList<Person>(
        json,
        (entity) => PersonModel.fromJson(entity['data']),
      );

  static PagedList<Device> _toDeviceList(Map<String, dynamic> json) => _toPagedList<Device>(
        json,
        (entity) => DeviceModel.fromJson(entity['data']),
      );

  static PagedList<Incident> _toIncidentList(Map<String, dynamic> json) => _toPagedList<Incident>(
        json,
        (entity) => IncidentModel.fromJson(entity['data']),
      );

  static PagedList<Personnel> _toPersonnelList(Map<String, dynamic> json) => _toPagedList<Personnel>(
        json,
        (entity) => PersonnelModel.fromJson(entity['data']),
      );

  static PagedList<Operation> _toOperationList(Map<String, dynamic> json) => _toPagedList<Operation>(
        json,
        (entity) => OperationModel.fromJson(entity['data']),
      );

  static PagedList<Affiliation> _toAffiliationList(Map<String, dynamic> json) => _toPagedList<Affiliation>(
        json,
        (entity) => AffiliationModel.fromJson(entity['data']),
      );

  static PagedList<Organisation> _toOrganisationList(Map<String, dynamic> json) => _toPagedList<Organisation>(
        json,
        (entity) => OrganisationModel.fromJson(entity['data']),
      );

  static PagedList<Division> _toDivisionList(Map<String, dynamic> json) => _toPagedList<Division>(
        json,
        (entity) => DivisionModel.fromJson(entity['data']),
      );

  static PagedList<Department> _toDepartmentList(Map<String, dynamic> json) => _toPagedList<Department>(
        json,
        (entity) => DepartmentModel.fromJson(entity['data']),
      );

  static List<T> _toList<T>(Map<String, dynamic> json, JsonDecoder<T> factory) => json['entries'] == null
      ? <T>[]
      : List.from(json['entries'])
          .map(
            (json) => factory(json),
          )
          .toList();

  static PagedList<T> _toPagedList<T>(Map<String, dynamic> json, JsonDecoder<T> factory) => PagedList<T>(
        _toList(json, factory),
        PageResult.from(json),
      );

  final String baseRestUrl;
  final UserRepository users;
  final http.Client httpClient;
  final ChopperClient chopperClient;

  static ServiceResponse<T> from<S, T>(
    Response<S> response, {
    T body,
    ConflictModel conflict,
    StackTrace stackTrace,
  }) {
    final resolved = body ?? response.body;
    return ServiceResponse<T>(
      conflict: conflict,
      stackTrace: stackTrace,
      statusCode: response.statusCode,
      reasonPhrase: '${response.base.reasonPhrase}',
      page: resolved is PagedList ? resolved.page : null,
      body: resolved is PagedList ? resolved.items : resolved,
      error: response.statusCode == HttpStatus.conflict
          ? ConflictModel.fromJson(jsonDecode(response.error))
          : response.error,
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
        applyHeader(
          request,
          'Content-Encoding',
          'gzip',
        ),
        'Authorization',
        'Bearer ${users.token.accessToken}',
      );
    }
    return request;
  }
}
