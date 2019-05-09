// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Point _$PointFromJson(Map<String, dynamic> json) {
  return Point(
      lat: (json['lat'] as num)?.toDouble(),
      lon: (json['lon'] as num)?.toDouble(),
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      alt: (json['alt'] as num)?.toDouble(),
      acc: (json['acc'] as num)?.toDouble());
}

Map<String, dynamic> _$PointToJson(Point instance) => <String, dynamic>{
      'lat': instance.lat,
      'lon': instance.lon,
      'alt': instance.alt,
      'acc': instance.acc,
      'timestamp': instance.timestamp?.toIso8601String()
    };
