// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Location _$LocationFromJson(Map json) {
  return Location(
    point: json['point'] == null
        ? null
        : Point.fromJson(Map<String, dynamic>.from(json['point'] as Map)),
    description: json['description'] as String?,
    address: json['address'] == null
        ? null
        : Address.fromJson(Map<String, dynamic>.from(json['address'] as Map)),
  );
}

Map<String, dynamic> _$LocationToJson(Location instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('point', instance.point?.toJson());
  writeNotNull('address', instance.address?.toJson());
  writeNotNull('description', instance.description);
  return val;
}
