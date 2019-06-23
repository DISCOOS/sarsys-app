import 'dart:ui';

import 'package:SarSys/map/icon_layer.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class TrackingLayerOptions extends LayerOptions {
  double size;
  double bearing;
  double opacity;
  Color color;
  List<Tracking> tracks;

  TrackingLayerOptions(
    this.tracks, {
    Stream<void> rebuild,
    this.size = 30.0,
    this.bearing,
    this.opacity = 1.00,
    this.color = Colors.blue,
  }) : super(rebuild: rebuild);
}

class TrackingLayer extends IconLayer {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is TrackingLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<void> stream) {
    final params = options as TrackingLayerOptions;
    return super.createLayer(
      IconLayerOptions(
        params.tracks
            .where((tracking) => tracking.location != null)
            .map((tracking) => toLatLng(tracking.location))
            .toList(),
        Icon(
          Icons.perm_device_information,
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
