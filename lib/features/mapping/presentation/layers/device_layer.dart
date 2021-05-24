import 'dart:math';

import 'package:SarSys/core/callbacks.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/mapping/presentation/painters.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class DeviceLayerOptions extends LayerOptions {
  DeviceLayerOptions({
    @required this.bloc,
    this.size = 8.0,
    this.opacity = 0.6,
    this.showTail = false,
    this.showLabels = true,
    this.onMessage,
  }) : super(rebuild: bloc.deviceBloc.stream.where((state) => state.isLocationChanged()).map((_) => null));

  final TrackingBloc bloc;
  final ActionCallback onMessage;

  double size;
  double opacity;
  bool showLabels;
  bool showTail;
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
    final ids = options.bloc.asDeviceIds();
    final devices = options.bloc.deviceBloc.values.where(
      (device) => bounds.contains(toLatLng(device.position?.geometry)),
    );
    return devices.isEmpty
        ? Container()
        : Stack(
            clipBehavior: Clip.none,
            children: [
              if (options.showTail)
                ...devices
                    .map((device) => _buildTrack(
                          context,
                          size,
                          options,
                          map,
                          device,
                          ids,
                        ))
                    .toList(),
              if (options.showLabels) ...devices.map((device) => _buildLabel(context, options, map, device)).toList(),
              ...devices.map((device) => _buildPoint(context, options, map, device)).toList(),
            ],
          );
  }

  TrackingTrack _toTrack(Map<String, Set<Tracking>> trackings, Device device) {
    final tracking = trackings[device.uuid]?.first;
    return tracking != null ? TrackingUtils.find(tracking.tracks, device.uuid) : null;
  }

  _buildTrack(
    BuildContext context,
    Size size,
    DeviceLayerOptions options,
    MapState map,
    Device device,
    Map<String, Set<Tracking>> trackings,
  ) {
    if (trackings != null) {
      final track = _toTrack(trackings, device);
      if (track?.isNotEmpty == true) {
        var offsets = track.positions.reversed.take(10).map((position) {
          var pos = map.project(toLatLng(position.geometry));
          pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
          return Offset(pos.x.toDouble(), pos.y.toDouble());
        }).toList(growable: false);

        final color = toPositionStatusColor(track.positions?.last);
        return CustomPaint(
          painter: LineStringPainter(
            offsets: offsets,
            color: color,
            borderColor: color,
            opacity: options.opacity,
          ),
          size: size,
        );
      }
    }
    return Container();
  }

  Widget _buildPoint(BuildContext context, DeviceLayerOptions options, MapState map, Device device) {
    var size = options.size;
    var point = device.position?.geometry;
    var pos = map.project(toLatLng(point));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    var pixelRadius = _toPixelRadius(map, size, pos.x, pos.y, device.position);

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
          color: toPositionStatusColor(device.position),
        ),
      ),
    );
  }

  _buildLabel(BuildContext context, DeviceLayerOptions options, MapState map, Device device) {
    var size = options.size;
    var point = device.position?.geometry;
    var pos = map.project(toLatLng(point));
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

  double _toPixelRadius(MapState map, double size, double x, double y, Position position) {
    if (position == null) return 0;
    var pixelRadius = size;
    if (position.acc != null && position.acc > 0.0) {
      var coords = ProjMath.calculateEndingGlobalCoordinates(
        position.lat,
        position.lon,
        45.0,
        position.acc,
      );
      var pos = map.project(LatLng(coords.y, coords.x));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      pixelRadius = min(max((pos.x - x).abs(), size), max((pos.y - y).abs(), size).abs()).toDouble();
    }
    return pixelRadius;
  }
}
