// @dart=2.11

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/domain/models/BaseMap.dart';
import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:SarSys/core/extensions.dart';

part 'map_widget_state_model.g.dart';

@JsonSerializable(
  explicitToJson: true,
  anyMap: true,
)
class MapWidgetStateModel extends Equatable {
  MapWidgetStateModel({
    this.center,
    this.zoom = Defaults.zoom,
    this.baseMap,
    this.filters,
    this.ouuid,
    this.following = false,
  });

  @override
  List<Object> get props => [
        center,
        zoom,
        baseMap,
        filters,
      ];

  final double zoom;
  @JsonKey(fromJson: _toLatLng, toJson: _toJson)
  final LatLng center;
  final BaseMap baseMap;
  final List<String> filters;
  final bool following;
  final String ouuid;

  /// Factory constructor for creating a new `MapWidgetStateModel` instance from json data
  factory MapWidgetStateModel.fromJson(Map<String, dynamic> json) => _$MapWidgetStateModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$MapWidgetStateModelToJson(this);

  static _toLatLng(Map<String, dynamic> value) => value?.isNotEmpty == true
      ? LatLng(
          value.elementAt('lat') as double,
          value.elementAt('lon') as double,
        )
      : null;

  static _toJson(LatLng center) => center == null
      ? null
      : {
          'lat': center.latitude,
          'lon': center.longitude,
        };

  MapWidgetStateModel cloneWith({
    LatLng center,
    double zoom,
    BaseMap baseMap,
    bool following,
    String incident,
    List<String> filters,
  }) =>
      MapWidgetStateModel(
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        baseMap: baseMap ?? this.baseMap,
        filters: filters ?? this.filters,
        ouuid: incident ?? this.ouuid,
        following: following ?? this.following,
      );
}
