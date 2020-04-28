// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AggregateRef.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AggregateRef<T> _$AggregateRefFromJson<T extends Aggregate>(Map json) {
  return AggregateRef<T>(
    uuid: json['uuid'] as String,
  );
}

Map<String, dynamic> _$AggregateRefToJson<T extends Aggregate>(
        AggregateRef<T> instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
    };
