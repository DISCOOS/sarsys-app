// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'division_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DivisionModel _$DivisionModelFromJson(Map json) {
  return DivisionModel(
    uuid: json['uuid'] as String,
    name: json['name'] as String?,
    suffix: json['suffix'] as String?,
    organisation: json['organisation'] == null
        ? null
        : AggregateRef.fromJson(json['organisation']),
    departments: (json['departments'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    active: json['active'] as bool?,
  );
}

Map<String, dynamic> _$DivisionModelToJson(DivisionModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('suffix', instance.suffix);
  writeNotNull('departments', instance.departments);
  writeNotNull('organisation', instance.organisation?.toJson());
  writeNotNull('active', instance.active);
  return val;
}
