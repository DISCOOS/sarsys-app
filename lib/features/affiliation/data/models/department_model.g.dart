// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'department_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DepartmentModel _$DepartmentModelFromJson(Map json) {
  return DepartmentModel(
    uuid: json['uuid'] as String,
    name: json['name'] as String?,
    suffix: json['suffix'] as String?,
    division: json['division'] == null
        ? null
        : AggregateRef.fromJson(json['division']),
    active: json['active'] as bool?,
  );
}

Map<String, dynamic> _$DepartmentModelToJson(DepartmentModel instance) {
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
  writeNotNull('division', instance.division?.toJson());
  writeNotNull('active', instance.active);
  return val;
}
