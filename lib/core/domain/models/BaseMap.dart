// @dart=2.11

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/domain/models/converters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:json_annotation/json_annotation.dart';

import 'core.dart';

part 'BaseMap.g.dart';

@JsonSerializable()
class BaseMap extends ValueObject<Map<String, dynamic>> {
  final String name;
  final String description;
  final String url;
  final double maxZoom;
  final double minZoom;
  final String attribution;
  final bool offline;
  final bool tms;
  final String previewFile;
  final List<String> subdomains;

  @LatLngBoundsConverter()
  final LatLngBounds bounds;

  BaseMap({
    @required this.url,
    @required this.name,
    this.description,
    this.maxZoom = Defaults.minZoom,
    this.minZoom = Defaults.maxZoom,
    this.attribution,
    this.bounds,
    this.offline = false,
    this.previewFile,
    this.tms = false,
    List<String> subdomains = const [],
  })  : this.subdomains = subdomains ?? const [],
        super([
          name,
          description,
          url,
          maxZoom,
          minZoom,
          attribution,
          offline,
          tms,
          previewFile,
          subdomains ?? const [],
          /*bounds, //LatLngBounds are not comparable, exclude to ensure similarity in BaseMapService */
        ]);

  /// Factory constructor for creating a new `BaseMap` instance
  factory BaseMap.fromJson(Map<String, dynamic> json) => _$BaseMapFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$BaseMapToJson(this);

  BaseMap cloneWith({String url, String previewFile}) => BaseMap(
        name: this.name,
        url: url ?? this.url,
        description: this.description,
        maxZoom: this.maxZoom,
        minZoom: this.minZoom,
        attribution: this.attribution,
        subdomains: this.subdomains,
        offline: this.offline,
        previewFile: previewFile ?? this.previewFile,
        tms: this.tms,
        bounds: this.bounds,
      );
}
