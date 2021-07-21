// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Point _$PointFromJson(Map json) {
  return Point(
    coordinates: coordsFromJson(json['coordinates'] as List),
  );
}

Map<String, dynamic> _$PointToJson(Point instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('coordinates', coordsToJson(instance.coordinates));
  return val;
}
