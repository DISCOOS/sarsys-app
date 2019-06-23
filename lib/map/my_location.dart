import 'dart:ui';

import 'package:SarSys/map/icon_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart' hide Path;

class MyLocationOptions extends LayerOptions {
  double size;
  LatLng point;
  double bearing;
  double opacity;
  Color color;

  MyLocationOptions(
    this.point, {
    Stream<void> rebuild,
    this.size = 30.0,
    this.bearing,
    this.opacity = 1.00,
    this.color = Colors.green,
  }) : super(rebuild: rebuild);
}

class MyLocation extends IconLayer {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is MyLocationOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<void> stream) {
    final params = options as MyLocationOptions;
    return super.createLayer(
      IconLayerOptions(
        params.point,
        Icon(
          Icons.my_location,
          size: params.size,
          color: params.color,
        ),
        rebuild: params.rebuild,
        bearing: params.bearing,
        opacity: params.opacity,
      ),
      map,
      stream,
    );
  }
}
