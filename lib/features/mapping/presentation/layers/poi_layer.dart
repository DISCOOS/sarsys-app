import 'dart:ui';

import 'package:badges/badges.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/mapping/presentation/painters.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/core/utils/data.dart';

typedef IconBuilder = Icon Function(BuildContext context, int index);

class POI extends Equatable {
  final String name;
  final Point point;
  final POIType type;

  POI({
    this.type,
    @required this.name,
    @required this.point,
  });

  @override
  List<Object> get props => [
        name,
        point,
        type,
      ];
}

enum POIType { IPP, Meetup, Any }

class POILayerOptions extends LayerOptions {
  OperationBloc bloc;
  String ouuid;
  double bearing;
  double opacity;
  Icon icon;
  Text text;
  bool showBadge;
  bool showLabels;
  AnchorAlign align;
  IconBuilder builder;

  POILayerOptions(
    this.bloc, {
    this.ouuid,
    this.icon,
    this.builder,
    this.bearing,
    this.showBadge = false,
    this.showLabels = true,
    this.opacity = 0.6,
    this.align = AnchorAlign.center,
    Stream<Null> rebuild,
  }) : super(rebuild: rebuild);
}

class POILayer implements MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is POILayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return IgnorePointer(
      child: stream == null
          ? Builder(
              builder: (context) => _buildLayer(context, options, map),
            )
          : StreamBuilder<void>(
              stream: stream, // a Stream<int> or null
              builder: (context, snapshot) => _buildLayer(context, options, map),
            ),
    );
  }

  Widget _buildLayer(BuildContext context, POILayerOptions params, MapState map) {
    int index = 0;
    List<Widget> icons = toItems(params.bloc.get(params.ouuid) ?? params.bloc.selected)
        .where((poi) => map.bounds.contains(toLatLng(poi.point)))
        .map((poi) => _buildIcon(context, map, params, toLatLng(poi.point), poi.name, index++))
        .toList();
    return icons.isEmpty
        ? Container()
        : Stack(
            children: icons,
          );
  }

  static POI toItem(Operation operation, POIType type) {
    switch (type) {
      case POIType.Meetup:
        return POI(
          name: "Oppmøte",
          point: operation?.meetup?.point,
          type: POIType.Meetup,
        );
      case POIType.IPP:
      default:
        return POI(
          name: "IPP",
          point: operation?.ipp?.point,
          type: POIType.IPP,
        );
    }
  }

  static List<POI> toItems(Operation operation) {
    return [
      toItem(operation, POIType.IPP),
      toItem(operation, POIType.Meetup),
    ];
  }

  Widget _buildIcon(
    BuildContext context,
    MapState map,
    POILayerOptions params,
    LatLng point,
    String label,
    int index,
  ) {
    var icon = params.icon ?? params.builder(context, index);
    var size = icon.size;
    var anchor = Anchor.forPos(AnchorPos.align(params.align), icon.size, icon.size);
    var pos = map.project(point);
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    var pixelPosX = (pos.x - (size - anchor.left)).toDouble();
    var pixelPosY = (pos.y - (size - anchor.top)).toDouble();

    return Positioned(
      left: pixelPosX,
      top: pixelPosY,
      child: Stack(
        children: [
          Container(
            child: Opacity(
              opacity: params.opacity,
              child: Badge(
                child: icon,
                badgeColor: Colors.white70,
                toAnimate: false,
                showBadge: params.showBadge,
                position: BadgePosition.topStart(),
                badgeContent: Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          if (params.showLabels && label != null)
            Positioned(
              left: size / 2,
              top: size,
              child: CustomPaint(
                painter: LabelPainter(label, top: size / 2),
              ),
            ),
          if (params.bearing != null)
            Opacity(
              opacity: 0.54,
              child: CustomPaint(
                painter: BearingPainter(params.bearing),
                size: Size(size, size),
              ),
            ),
        ],
      ),
    );
  }
}
