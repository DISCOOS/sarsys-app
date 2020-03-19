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
          ?.map((e) => e == null ? null : TalkGroup.fromJson(e))
          ?.toList(),
      justification: json['justification'] as String,
      ipp: json['ipp'] == null
          ? null
          : Location.fromJson(json['ipp'] as Map<String, dynamic>),
      meetup: json['meetup'] == null
          ? null
          : Location.fromJson(json['meetup'] as Map<String, dynamic>),
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

Map<String, dynamic> _$IncidentToJson(Incident instance) =>
    _$IncidentJsonMapWrapper(instance);

class _$IncidentJsonMapWrapper extends $JsonMapWrapper {
  final Incident _v;
  _$IncidentJsonMapWrapper(this._v);

  @override
  Iterable<String> get keys => const [
        'id',
        'name',
        'type',
        'status',
        'occurred',
        'justification',
        'talkgroups',
        'ipp',
        'meetup',
        'passcodes',
        'reference',
        'created',
        'changed'
      ];

  @override
  dynamic operator [](Object key) {
    if (key is String) {
      switch (key) {
        case 'id':
          return _v.id;
        case 'name':
          return _v.name;
        case 'type':
          return _$IncidentTypeEnumMap[_v.type];
        case 'status':
          return _$IncidentStatusEnumMap[_v.status];
        case 'occurred':
          return _v.occurred?.toIso8601String();
        case 'justification':
          return _v.justification;
        case 'talkgroups':
          return $wrapListHandleNull<TalkGroup>(
              _v.talkgroups, (e) => e?.toJson());
        case 'ipp':
          return _v.ipp?.toJson();
        case 'meetup':
          return _v.meetup?.toJson();
        case 'passcodes':
          return _v.passcodes?.toJson();
        case 'reference':
          return _v.reference;
        case 'created':
          return _v.created?.toJson();
        case 'changed':
          return _v.changed?.toJson();
      }
    }
    return null;
  }
}

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
