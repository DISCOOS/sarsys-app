// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RouteModel _$RouteModelFromJson(Map json) {
  return RouteModel(
    json['data'],
    json['name'] as String,
    json['incidentId'] as String,
  );
}

Map<String, dynamic> _$RouteModelToJson(RouteModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'data': instance.data,
      'incidentId': instance.incidentId,
    };
