// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IncidentModel _$IncidentModelFromJson(Map json) {
  return IncidentModel(
    uuid: json['uuid'] as String?,
    name: json['name'] as String?,
    summary: json['summary'] as String?,
    type: _$enumDecodeNullable(_$IncidentTypeEnumMap, json['type']),
    occurred: json['occurred'] == null
        ? null
        : DateTime.parse(json['occurred'] as String),
    status: _$enumDecodeNullable(_$IncidentStatusEnumMap, json['status']),
    operations: (json['operations'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    resolution:
        _$enumDecodeNullable(_$IncidentResolutionEnumMap, json['resolution']),
    exercise: json['exercise'] as bool?,
  );
}

Map<String, dynamic> _$IncidentModelToJson(IncidentModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('exercise', instance.exercise);
  writeNotNull('summary', instance.summary);
  writeNotNull('type', _$IncidentTypeEnumMap[instance.type]);
  writeNotNull('occurred', instance.occurred?.toIso8601String());
  writeNotNull('status', _$IncidentStatusEnumMap[instance.status]);
  writeNotNull('operations', instance.operations);
  writeNotNull('resolution', _$IncidentResolutionEnumMap[instance.resolution]);
  return val;
}

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

K? _$enumDecodeNullable<K, V>(
  Map<K, V> enumValues,
  dynamic source, {
  K? unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<K, V>(enumValues, source, unknownValue: unknownValue);
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
