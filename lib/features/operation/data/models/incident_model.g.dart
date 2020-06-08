// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IncidentModel _$IncidentModelFromJson(Map json) {
  return IncidentModel(
    uuid: json['uuid'] as String,
    name: json['name'] as String,
    summary: json['summary'] as String,
    type: _$enumDecodeNullable(_$IncidentTypeEnumMap, json['type']),
    occurred: json['occurred'] == null
        ? null
        : DateTime.parse(json['occurred'] as String),
    status: _$enumDecodeNullable(_$IncidentStatusEnumMap, json['status']),
    resolution:
        _$enumDecodeNullable(_$IncidentResolutionEnumMap, json['resolution']),
    exercise: json['exercise'] as bool,
  );
}

Map<String, dynamic> _$IncidentModelToJson(IncidentModel instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'exercise': instance.exercise,
      'summary': instance.summary,
      'type': _$IncidentTypeEnumMap[instance.type],
      'occurred': instance.occurred?.toIso8601String(),
      'status': _$IncidentStatusEnumMap[instance.status],
      'resolution': _$IncidentResolutionEnumMap[instance.resolution],
    };

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$IncidentTypeEnumMap = {
  IncidentType.lost: 'lost',
  IncidentType.distress: 'distress',
  IncidentType.disaster: 'disaster',
  IncidentType.other: 'other',
};

const _$IncidentStatusEnumMap = {
  IncidentStatus.registered: 'registered',
  IncidentStatus.handling: 'handling',
  IncidentStatus.closed: 'closed',
};

const _$IncidentResolutionEnumMap = {
  IncidentResolution.unresolved: 'unresolved',
  IncidentResolution.cancelled: 'cancelled',
  IncidentResolution.duplicate: 'duplicate',
  IncidentResolution.resolved: 'resolved',
};
