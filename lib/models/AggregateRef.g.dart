// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AggregateRef.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AggregateRef _$AggregateRefFromJson(Map json) {
  return AggregateRef(
    uuid: json['uuid'] as String,
    type: json['type'] as String,
  );
}

Map<String, dynamic> _$AggregateRefToJson(AggregateRef instance) =>
    <String, dynamic>{
      'type': instance.type,
      'uuid': instance.uuid,
    };
