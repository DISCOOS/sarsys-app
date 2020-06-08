// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OperationModel _$OperationModelFromJson(Map json) {
  return OperationModel(
    uuid: json['uuid'] as String,
    name: json['name'] as String,
    ipp: json['ipp'] == null
        ? null
        : Location.fromJson((json['ipp'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    author: json['author'] == null
        ? null
        : Author.fromJson((json['author'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    meetup: json['meetup'] == null
        ? null
        : Location.fromJson((json['meetup'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    type: _$enumDecodeNullable(_$OperationTypeEnumMap, json['type']),
    passcodes: json['passcodes'] == null
        ? null
        : Passcodes.fromJson((json['passcodes'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    justification: json['justification'] as String,
    status: _$enumDecodeNullable(_$OperationStatusEnumMap, json['status']),
    talkgroups: (json['talkgroups'] as List)
        ?.map((e) => e == null
            ? null
            : TalkGroup.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
    resolution:
        _$enumDecodeNullable(_$OperationResolutionEnumMap, json['resolution']),
    incident: json['incident'] == null
        ? null
        : AggregateRef.fromJson((json['incident'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    commander: json['commander'] == null
        ? null
        : AggregateRef.fromJson((json['commander'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    reference: json['reference'] as String,
  );
}

Map<String, dynamic> _$OperationModelToJson(OperationModel instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'ipp': instance.ipp?.toJson(),
      'author': instance.author?.toJson(),
      'meetup': instance.meetup?.toJson(),
      'reference': instance.reference,
      'type': _$OperationTypeEnumMap[instance.type],
      'passcodes': instance.passcodes?.toJson(),
      'justification': instance.justification,
      'status': _$OperationStatusEnumMap[instance.status],
      'talkgroups': instance.talkgroups?.map((e) => e?.toJson())?.toList(),
      'resolution': _$OperationResolutionEnumMap[instance.resolution],
      'incident': instance.incident?.toJson(),
      'commander': instance.commander?.toJson(),
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

const _$OperationTypeEnumMap = {
  OperationType.search: 'search',
  OperationType.rescue: 'rescue',
  OperationType.other: 'other',
};

const _$OperationStatusEnumMap = {
  OperationStatus.planned: 'planned',
  OperationStatus.enroute: 'enroute',
  OperationStatus.onscene: 'onscene',
  OperationStatus.completed: 'completed',
};

const _$OperationResolutionEnumMap = {
  OperationResolution.unresolved: 'unresolved',
  OperationResolution.cancelled: 'cancelled',
  OperationResolution.duplicate: 'duplicate',
  OperationResolution.resolved: 'resolved',
};
