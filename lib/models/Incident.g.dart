// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Incident.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Incident _$IncidentFromJson(Map<String, dynamic> json) {
  return Incident(
      id: json['id'] as String,
      name: json['name'] as String,
      type: _$enumDecodeNullable(_$IncidentTypeEnumMap, json['type']),
      status: _$enumDecodeNullable(_$IncidentStatusEnumMap, json['status']),
      occurred: json['occurred'] == null
          ? null
          : DateTime.parse(json['occurred'] as String),
      talkgroups: (json['talkgroups'] as List)
          ?.map((e) =>
              e == null ? null : TalkGroup.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      justification: json['justification'] as String,
      ipp: json['ipp'] == null
          ? null
          : Point.fromJson(json['ipp'] as Map<String, dynamic>),
      meetup: json['meetup'] == null
          ? null
          : Point.fromJson(json['meetup'] as Map<String, dynamic>),
      passcodes: json['passcodes'] == null
          ? null
          : Passcodes.fromJson(json['passcodes'] as Map<String, dynamic>),
      created: json['created'] == null
          ? null
          : Author.fromJson(json['created'] as Map<String, dynamic>),
      changed: json['changed'] == null
          ? null
          : Author.fromJson(json['changed'] as Map<String, dynamic>),
      reference: json['reference'] as String);
}

Map<String, dynamic> _$IncidentToJson(Incident instance) => <String, dynamic>{
      'id': instance.id,
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
      'changed': instance.changed?.toJson()
    };

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError(
              '`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$IncidentTypeEnumMap = <IncidentType, dynamic>{
  IncidentType.Lost: 'Lost',
  IncidentType.Distress: 'Distress',
  IncidentType.Other: 'Other'
};

const _$IncidentStatusEnumMap = <IncidentStatus, dynamic>{
  IncidentStatus.Registered: 'Registered',
  IncidentStatus.Handling: 'Handling',
  IncidentStatus.Cancelled: 'Cancelled',
  IncidentStatus.Resolved: 'Resolved',
  IncidentStatus.Other: 'Other'
};
