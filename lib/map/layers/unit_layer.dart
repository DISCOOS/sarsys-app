import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class UnitLayerOptions extends LayerOptions {
  double size;
  double opacity;
  bool showLabels;
  bool showTail;
  final TrackingBloc bloc;
  final MessageCallback onMessage;

  UnitLayerOptions({
    @required this.bloc,
    this.size = 24.0,
    this.opacity = 0.6,
    this.showLabels = true,
    this.showTail = true,
    this.onMessage,
  }) : super(rebuild: bloc.state.map((_) => null));
}

class UnitLayer extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is UnitLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return StreamBuilder<void>(
          stream: stream, // a Stream<int> or null
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            return _build(context, size, options as UnitLayerOptions, map);
          },
        );
      },
    );
  }

  Widget _build(BuildContext context, Size size, UnitLayerOptions options, MapState map) {
    final bounds = map.getBounds();
    final tracks = options.bloc.tracks;
    final units = sortMapValues<String, Unit, TrackingStatus>(
            options.bloc.units, (unit) => tracks[unit.tracking].status, (s1, s2) => s1.index - s2.index)
        .values
        .where((unit) => bounds.contains(toLatLng(tracks[unit.tracking].location)));
    return options.bloc.isEmpty
        ? Container()
        : Stack(
            overflow: Overflow.clip,
            children: [
              if (options.showTail)
                ...units.map((unit) => _buildTrack(context, size, options, map, unit, tracks[unit.tracking])).toList(),
              if (options.showLabels)
                ...units
                    .map((unit) => _buildLabel(context, options, map, unit, tracks[unit.tracking].location))
                    .toList(),
              ...units.map((unit) => _buildPoint(context, options, map, unit, tracks[unit.tracking])).toList(),
            ],
          );
  }

  _buildTrack(
    BuildContext context,
    Size size,
    UnitLayerOptions options,
    MapState map,
    Unit unit,
    Tracking tracking,
  ) {
    var offsets = tracking.track.reversed.take(10).map((point) {
      var pos = map.project(toLatLng(point));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      return Offset(pos.x.toDouble(), pos.y.toDouble());
    }).toList(growable: false);

    final color = _toTrackingStatusColor(context, tracking.status);

    return Opacity(
      opacity: options.opacity,
      child: CustomPaint(
        painter: LineStringPainter(
          offsets,
          color,
          color,
          4.0,
          false,
        ),
        size: size,
      ),
    );
  }

  Widget _buildPoint(BuildContext context, UnitLayerOptions options, MapState map, Unit unit, Tracking tracking) {
    var size = options.size;
    var pos = map.project(toLatLng(tracking.location));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      width: size,
      height: size,
      left: pos.x - size / 2,
      top: pos.y - size / 2,
      child: Opacity(
        opacity: options.opacity,
        child: CustomPaint(
          painter: PointPainter(
            size: size,
            color: _toTrackingStatusColor(context, tracking.status),
          ),
        ),
      ),
    );
  }

  _buildLabel(BuildContext context, UnitLayerOptions options, MapState map, Unit unit, Point point) {
    var pos = map.project(toLatLng(point));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      left: pos.x,
      top: pos.y,
      child: CustomPaint(
        painter: LabelPainter(
          unit.name,
        ),
      ),
    );
  }
}

Color _toTrackingStatusColor(BuildContext context, TrackingStatus status) {
  switch (status) {
    case TrackingStatus.None:
    case TrackingStatus.Created:
    case TrackingStatus.Closed:
      return Colors.red;
    case TrackingStatus.Tracking:
      return Colors.green;
    case TrackingStatus.Paused:
      return Colors.orange;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}
