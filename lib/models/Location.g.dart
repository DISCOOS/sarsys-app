// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Location _$LocationFromJson(Map json) {
  return Location(
    point: json['point'] == null
        ? null
        : Point.fromJson((json['point'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    description: json['description'] as String,
    address: json['address'] == null
        ? null
        : Address.fromJson((json['address'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
  );
}

Map<String, dynamic> _$LocationToJson(Location instance) => <String, dynamic>{
      'point': instance.point?.toJson(),
      'address': instance.address?.toJson(),
      'description': instance.description,
    };
