import 'dart:math';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:latlong/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class DeviceLayerOptions extends LayerOptions {
  double size;
  double opacity;
  bool showLabels;
  bool showTail;
  final DeviceBloc bloc;
  final MessageCallback onMessage;

  DeviceLayerOptions({
    @required this.bloc,
    this.size = 8.0,
    this.opacity = 0.6,
    this.showLabels = true,
    this.onMessage,
  }) : super(rebuild: bloc.state.map((_) => null));
}

class DeviceLayer extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is DeviceLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return StreamBuilder<void>(
          stream: stream, // a Stream<int> or null
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            return _build(context, size, options as DeviceLayerOptions, map);
          },
        );
      },
    );
  }

  Widget _build(BuildContext context, Size size, DeviceLayerOptions options, MapState map) {
    final bounds = map.getBounds();
    final devices = options.bloc.devices.values.where((device) => bounds.contains(toLatLng(device.location)));
    return options.bloc.isEmpty
        ? Container()
        : Stack(
            overflow: Overflow.clip,
            children: [
              if (options.showLabels) ...devices.map((device) => _buildLabel(context, options, map, device)).toList(),
              ...devices.map((device) => _buildPoint(context, options, map, device)).toList(),
            ],
          );
  }

  Widget _buildPoint(BuildContext context, DeviceLayerOptions options, MapState map, Device device) {
    var size = options.size;
    var location = device.location;
    var pos = map.project(toLatLng(location));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    var pixelRadius = _toPixelRadius(map, size, pos.x, pos.y, location);

    return Positioned(
      top: pos.y,
      left: pos.x,
      width: pixelRadius,
      height: pixelRadius,
      child: CustomPaint(
        painter: PointPainter(
          size: size,
          outer: pixelRadius,
          opacity: options.opacity,
          color: toPointStatusColor(context, device.location),
        ),
      ),
    );
  }

  _buildLabel(BuildContext context, DeviceLayerOptions options, MapState map, Device device) {
    var size = options.size;
    var location = device.location;
    var pos = map.project(toLatLng(location));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      top: pos.y + size,
      left: pos.x,
      child: CustomPaint(
        painter: LabelPainter(device.name, top: size),
        size: Size(size, size),
      ),
    );
  }

  double _toPixelRadius(MapState map, double size, double x, double y, Point point) {
    if (point == null) return 0;
    var pixelRadius = size;
    if (point.acc != null && point.acc > 0.0) {
      var coords = ProjMath.calculateEndingGlobalCoordinates(
        point.lat,
        point.lon,
        45.0,
        point.acc,
      );
      var pos = map.project(LatLng(coords.y, coords.x));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      pixelRadius = min(max((pos.x - x).abs(), size), max((pos.y - y).abs(), size).abs()).toDouble();
    }
    return pixelRadius;
  }
}
