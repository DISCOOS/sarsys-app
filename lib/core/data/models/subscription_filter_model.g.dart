// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_filter_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionFilterModel _$SubscriptionFilterModelFromJson(Map json) {
  return SubscriptionFilterModel(
    pattern: json['pattern'] as String,
  );
}

Map<String, dynamic> _$SubscriptionFilterModelToJson(
    SubscriptionFilterModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('pattern', instance.pattern);
  return val;
}
