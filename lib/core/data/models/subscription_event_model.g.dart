// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionEventModel _$SubscriptionEventModelFromJson(Map json) {
  return SubscriptionEventModel(
    name: json['name'] as String?,
    statePatches: json['statePatches'] as bool?,
    changedState: json['changedState'] as bool?,
    previousState: json['previousState'] as bool?,
  );
}

Map<String, dynamic> _$SubscriptionEventModelToJson(
    SubscriptionEventModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('changedState', instance.changedState);
  writeNotNull('statePatches', instance.statePatches);
  writeNotNull('previousState', instance.previousState);
  return val;
}
