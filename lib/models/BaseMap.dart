import 'package:SarSys/core/defaults.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';

part 'BaseMap.g.dart';

@JsonSerializable()
class BaseMap extends Equatable {
  final String name;
  final String description;
  final String url;
  final double maxZoom;
  final double minZoom;
  final String attribution;
  final bool offline;
  final String previewFile;
  final bool tms;
  final List<String> subdomains;

  BaseMap({
    @required this.url,
    @required this.name,
    this.description,
    this.maxZoom = Defaults.minZoom,
    this.minZoom = Defaults.maxZoom,
    this.attribution,
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
          subdomains,
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
      );
}
