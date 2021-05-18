// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_type_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionTypeModel _$SubscriptionTypeModelFromJson(Map json) {
  return SubscriptionTypeModel(
    name: json['name'] as String,
    statePatches: json['statePatches'] as bool,
    changedState: json['changedState'] as bool,
    previousState: json['previousState'] as bool,
    match: _$enumDecodeNullable(_$FilterMatchEnumMap, json['match']) ??
        FilterMatch.any,
    events: (json['events'] as List)
        ?.map((e) => e == null
            ? null
            : SubscriptionEventModel.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
    filters: (json['filters'] as List)
        ?.map((e) => e == null
            ? null
            : SubscriptionFilterModel.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
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
  writeNotNull('match', _$FilterMatchEnumMap[instance.match]);
  writeNotNull('events', instance.events?.map((e) => e?.toJson())?.toList());
  writeNotNull('filters', instance.filters?.map((e) => e?.toJson())?.toList());
  writeNotNull('changedState', instance.changedState);
  writeNotNull('statePatches', instance.statePatches);
  writeNotNull('previousState', instance.previousState);
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

const _$FilterMatchEnumMap = {
  FilterMatch.any: 'any',
  FilterMatch.all: 'all',
};
