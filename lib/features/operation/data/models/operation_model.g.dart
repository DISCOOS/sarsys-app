// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OperationModel _$OperationModelFromJson(Map json) {
  return OperationModel(
    uuid: json['uuid'] as String?,
    name: json['name'] as String?,
    ipp: json['ipp'] == null
        ? null
        : Location.fromJson(Map<String, dynamic>.from(json['ipp'] as Map)),
    author: json['author'] == null
        ? null
        : Author.fromJson(Map<String, dynamic>.from(json['author'] as Map)),
    meetup: json['meetup'] == null
        ? null
        : Location.fromJson(Map<String, dynamic>.from(json['meetup'] as Map)),
    type: _$enumDecodeNullable(_$OperationTypeEnumMap, json['type']),
    passcodes: json['passcodes'] == null
        ? null
        : Passcodes.fromJson(
            Map<String, dynamic>.from(json['passcodes'] as Map)),
    justification: json['justification'] as String?,
    status: _$enumDecodeNullable(_$OperationStatusEnumMap, json['status']),
    talkgroups: (json['talkgroups'] as List<dynamic>?)
        ?.map((e) => TalkGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    resolution:
        _$enumDecodeNullable(_$OperationResolutionEnumMap, json['resolution']),
    incident: json['incident'] == null
        ? null
        : AggregateRef.fromJson(json['incident']),
    commander: json['commander'] == null
        ? null
        : AggregateRef.fromJson(json['commander']),
    reference: json['reference'] as String?,
  );
}

Map<String, dynamic> _$OperationModelToJson(OperationModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

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
