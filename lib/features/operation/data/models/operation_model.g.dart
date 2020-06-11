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

Map<String, dynamic> _$OperationModelToJson(OperationModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('uuid', instance.uuid);
  writeNotNull('name', instance.name);
  writeNotNull('ipp', instance.ipp?.toJson());
  writeNotNull('author', instance.author?.toJson());
  writeNotNull('meetup', instance.meetup?.toJson());
  writeNotNull('reference', instance.reference);
  writeNotNull('type', _$OperationTypeEnumMap[instance.type]);
  writeNotNull('passcodes', instance.passcodes?.toJson());
  writeNotNull('justification', instance.justification);
  writeNotNull('status', _$OperationStatusEnumMap[instance.status]);
  writeNotNull('talkgroups', JsonUtils.toNull(instance.talkgroups));
  writeNotNull('resolution', _$OperationResolutionEnumMap[instance.resolution]);
  writeNotNull('incident', instance.incident?.toJson());
  writeNotNull('commander', instance.commander?.toJson());
  return val;
}

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
