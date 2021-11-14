

import 'dart:math';

import 'package:SarSys/core/callbacks.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/presentation/painters.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';

class PersonnelLayerOptions extends LayerOptions {
  double size;
  double opacity;
  bool showLabels;
  bool showTail;
  bool showRetired;
  final TrackingBloc bloc;
  final ActionCallback? onMessage;

  PersonnelLayerOptions({
    required this.bloc,
    this.size = 8.0,
    this.opacity = 0.6,
    this.showLabels = true,
    this.showTail = true,
    this.showRetired = false,
    this.onMessage,
  }) : super(rebuild: bloc.stream.map((_) => null));
}

class PersonnelLayer extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is PersonnelLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return StreamBuilder<void>(
          stream: stream, // a Stream<int> or null
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            return _build(context, size, options as PersonnelLayerOptions, map);
          },
        );
      },
    );
  }

  Widget _build(BuildContext context, Size size, PersonnelLayerOptions options, MapState map) {
    final bounds = map.getBounds();
    final trackings = options.bloc.trackings;
    final personnels = sortMapValues<String?, Personnel?, TrackingStatus>(
            options.bloc.personnels.where(exclude: options.showRetired ? [] : [TrackingStatus.closed]).map,
            (personnel) => trackings[personnel!.tracking!.uuid]!.status ?? TrackingStatus.none,
            (s1, s2) => s1!.index - s2!.index)
        .values
        .where((personnel) => trackings[personnel!.tracking!.uuid]?.position?.isNotEmpty == true)
        .where((personnel) => options.showRetired || personnel!.status != PersonnelStatus.retired)
        .where(
          (personnel) => bounds.contains(toLatLng(trackings[personnel!.tracking!.uuid]?.position?.geometry)),
        );
    return trackings.isEmpty
        ? Container()
        : Stack(
            clipBehavior: Clip.none,
            children: [
              if (options.showTail) ..._buildTracks(context, personnels, size, options, map, trackings) as Iterable<Widget>,
              if (options.showLabels) ..._buildLabels(context, personnels, options, map, trackings) as Iterable<Widget>,
              ..._buildPoints(context, personnels, options, map, trackings),
            ],
          );
  }

  List<Widget> _buildPoints(
    BuildContext context,
    Iterable<Personnel?> personnels,
    PersonnelLayerOptions options,
    MapState map,
    Map<String?, Tracking?> trackings,
  ) =>
      personnels
          .map((personnels) => _buildPoint(
                context,
                options,
                map,
                personnels!,
                trackings[personnels.tracking!.uuid]!,
              ))
          .toList();

  List _buildLabels(
    BuildContext context,
    Iterable<Personnel?> personnels,
    PersonnelLayerOptions options,
    MapState map,
    Map<String?, Tracking?> trackings,
  ) =>
      personnels
          .map((personnels) => _buildLabel(
                context,
                options,
                map,
                personnels!,
                trackings[personnels.tracking!.uuid]?.position?.geometry,
              ))
          .toList();

  List _buildTracks(
    BuildContext context,
    Iterable<Personnel?> personnels,
    Size size,
    PersonnelLayerOptions options,
    MapState map,
    Map<String?, Tracking?> trackings,
  ) =>
      personnels
          .map((personnels) => _buildTrack(
                context,
                size,
                options,
                map,
                personnels,
                trackings[personnels!.tracking!.uuid]!,
              ))
          .toList();

  _buildTrack(
    BuildContext context,
    Size size,
    PersonnelLayerOptions options,
    MapState map,
    Personnel? personnels,
    Tracking tracking,
  ) {
    var offsets = tracking.history.reversed.take(10).map((position) {
      var pos = map.project(toLatLng(position!.geometry));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      return Offset(pos.x.toDouble(), pos.y.toDouble());
    }).toList(growable: false);

    final color = toPositionStatusColor(tracking.position);

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

  Widget _buildPoint(
      BuildContext context, PersonnelLayerOptions options, MapState map, Personnel personnels, Tracking tracking) {
    var size = options.size;
    var point = tracking.position!.geometry;
    var pos = map.project(toLatLng(point));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    var pixelRadius = _toPixelRadius(map, size, pos.x as double, pos.y as double, tracking.position);

    return Positioned(
      top: pos.y as double?,
      left: pos.x as double?,
      width: pixelRadius,
      height: pixelRadius,
      child: CustomPaint(
        painter: PointPainter(
          size: size,
          opacity: options.opacity,
          outer: pixelRadius,
          centerColor: toPersonnelStatusColor(personnels.status),
          color: toPositionStatusColor(tracking.position),
        ),
      ),
    );
  }

  _buildLabel(BuildContext context, PersonnelLayerOptions options, MapState map, Personnel personnels, Point? point) {
    var size = options.size;
    var pos = map.project(toLatLng(point));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      top: pos.y + size,
      left: pos.x as double?,
      child: CustomPaint(
        painter: LabelPainter("${personnels.fname}\n${personnels.lname}", top: size),
        size: Size(size, size),
      ),
    );
  }
}

double _toPixelRadius(MapState map, double size, double x, double y, Position? position) {
  if (position == null) return 0;
  var pixelRadius = size;
  if (position.acc != null && position.acc! > 0.0) {
    var coords = ProjMath.calculateEndingGlobalCoordinates(
      position.lat!,
      position.lon,
      45.0,
      position.acc!,
    );
    var pos = map.project(LatLng(coords.y!, coords.x!));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    pixelRadius = min(max((pos.x - x).abs(), size), max((pos.y - y).abs(), size).abs()).toDouble();
  }
  return pixelRadius;
}
