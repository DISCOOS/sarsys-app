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

Map<String, dynamic> _$PointToJson(Point instance) => <String, dynamic>{
      'coordinates': coordsToJson(instance.coordinates),
    };
