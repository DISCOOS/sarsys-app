// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IncidentModel _$IncidentModelFromJson(Map json) {
  return IncidentModel(
    uuid: json['uuid'] as String,
    name: json['name'] as String,
    type: _$enumDecodeNullable(_$IncidentTypeEnumMap, json['type']),
    status: _$enumDecodeNullable(_$IncidentStatusEnumMap, json['status']),
    occurred: json['occurred'] == null
        ? null
        : DateTime.parse(json['occurred'] as String),
    talkgroups: (json['talkgroups'] as List)
        ?.map((e) => e == null
            ? null
            : TalkGroup.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
    justification: json['justification'] as String,
    ipp: json['ipp'] == null
        ? null
        : Location.fromJson((json['ipp'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    meetup: json['meetup'] == null
        ? null
        : Location.fromJson((json['meetup'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    passcodes: json['passcodes'] == null
        ? null
        : Passcodes.fromJson((json['passcodes'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    created: json['created'] == null
        ? null
        : Author.fromJson((json['created'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    changed: json['changed'] == null
        ? null
        : Author.fromJson((json['changed'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    exercise: json['exercise'] as bool,
    reference: json['reference'] as String,
  );
}

Map<String, dynamic> _$IncidentModelToJson(IncidentModel instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'type': _$IncidentTypeEnumMap[instance.type],
      'status': _$IncidentStatusEnumMap[instance.status],
      'occurred': instance.occurred?.toIso8601String(),
      'justification': instance.justification,
      'talkgroups': instance.talkgroups?.map((e) => e?.toJson())?.toList(),
      'ipp': instance.ipp?.toJson(),
      'meetup': instance.meetup?.toJson(),
      'passcodes': instance.passcodes?.toJson(),
      'reference': instance.reference,
      'created': instance.created?.toJson(),
      'changed': instance.changed?.toJson(),
      'exercise': instance.exercise,
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
  IncidentType.Lost: 'Lost',
  IncidentType.Distress: 'Distress',
  IncidentType.Other: 'Other',
};

const _$IncidentStatusEnumMap = {
  IncidentStatus.Registered: 'Registered',
  IncidentStatus.Handling: 'Handling',
  IncidentStatus.Cancelled: 'Cancelled',
  IncidentStatus.Resolved: 'Resolved',
  IncidentStatus.Other: 'Other',
};
