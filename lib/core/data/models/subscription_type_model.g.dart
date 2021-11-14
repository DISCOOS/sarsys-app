// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_type_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionTypeModel _$SubscriptionTypeModelFromJson(Map json) {
  return SubscriptionTypeModel(
    name: json['name'] as String?,
    statePatches: json['statePatches'] as bool?,
    changedState: json['changedState'] as bool?,
    previousState: json['previousState'] as bool?,
    match: _$enumDecodeNullable(_$FilterMatchEnumMap, json['match']) ??
        FilterMatch.any,
    events: (json['events'] as List<dynamic>?)
        ?.map((e) => SubscriptionEventModel.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList(),
    filters: (json['filters'] as List<dynamic>?)
        ?.map((e) => SubscriptionFilterModel.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

Map<String, dynamic> _$SubscriptionTypeModelToJson(
    SubscriptionTypeModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  val['match'] = _$FilterMatchEnumMap[instance.match];
  val['events'] = instance.events.map((e) => e.toJson()).toList();
  val['filters'] = instance.filters.map((e) => e.toJson()).toList();
  writeNotNull('changedState', instance.changedState);
  writeNotNull('statePatches', instance.statePatches);
  writeNotNull('previousState', instance.previousState);
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

const _$FilterMatchEnumMap = {
  FilterMatch.any: 'any',
  FilterMatch.all: 'all',
};
