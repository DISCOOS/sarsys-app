// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionModel _$SubscriptionModelFromJson(Map json) {
  return SubscriptionModel(
    maxCount: json['maxCount'] as int,
    minPeriod: json['minPeriod'] == null
        ? null
        : Duration(microseconds: json['minPeriod'] as int),
    types: (json['types'] as List)
        ?.map((e) => e == null
            ? null
            : SubscriptionTypeModel.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
  );
}

Map<String, dynamic> _$SubscriptionModelToJson(SubscriptionModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('maxCount', instance.maxCount);
  writeNotNull('minPeriod', instance.minPeriod?.inMicroseconds);
  writeNotNull('types', instance.types?.map((e) => e?.toJson())?.toList());
  return val;
}
