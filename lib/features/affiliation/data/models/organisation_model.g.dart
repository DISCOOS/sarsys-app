// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organisation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganisationModel _$OrganisationModelFromJson(Map json) {
  return OrganisationModel(
    uuid: json['uuid'] as String,
    name: json['name'] as String?,
    prefix: json['prefix'] as String?,
    fleetMap: json['fleetMap'] == null
        ? null
        : FleetMap.fromJson(Map<String, dynamic>.from(json['fleetMap'] as Map)),
    divisions:
        (json['divisions'] as List<dynamic>?)?.map((e) => e as String).toList(),
    active: json['active'] as bool?,
  );
}

Map<String, dynamic> _$OrganisationModelToJson(OrganisationModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('prefix', instance.prefix);
  writeNotNull('fleetMap', instance.fleetMap?.toJson());
  writeNotNull('divisions', instance.divisions);
  writeNotNull('active', instance.active);
  return val;
}
