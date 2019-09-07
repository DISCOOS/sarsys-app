import 'dart:async';
import 'dart:ui';
import 'dart:math';

import 'package:SarSys/map/painters.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart' hide Path;

class MyLocationOptions extends LayerOptions {
  double size;
  LatLng point;
  LatLng next;
  LatLng previous;
  double bearing;
  double accuracy;
  double opacity;
  int milliSeconds;
  TickerProvider tickerProvider;
  StreamController<Null> locationUpdateController;
  Color color;

  bool _isAnimating = false;

  bool get isAnimating => _isAnimating;

  MyLocationOptions(
    this.point, {
    this.size = 30.0,
    this.bearing,
    this.accuracy,
    this.opacity = 0.6,
    this.milliSeconds = 500,
    this.color = Colors.green,
    this.tickerProvider,
    this.locationUpdateController,
    Stream<Null> rebuild,
  }) : super(rebuild: rebuild);

  /// Move icon to given point
  void animatedMove(LatLng point, {double bearing, void onMove(LatLng p)}) {
    if (_isAnimating) return;
    _isAnimating = true;

    next = point;
    previous = this.point;

    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> previous position and the destination.
    final _latTween = Tween<double>(begin: previous.latitude, end: next.latitude);
    final _lngTween = Tween<double>(begin: previous.longitude, end: next.longitude);

    // Create a animation controller that has a duration and a TickerProvider.
    var controller = AnimationController(duration: Duration(milliseconds: milliSeconds), vsync: tickerProvider);

    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      this.point = LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation));
      if (onMove != null) onMove(this.point);
      locationUpdateController.add(null);
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dispose(controller, point);
      } else if (status == AnimationStatus.dismissed) {
        _dispose(controller, point);
      }
    });

    controller.forward();
  }

  void _dispose(AnimationController controller, LatLng point) {
    controller.dispose();
    this.point = point;
    next = null;
    previous = null;
    _isAnimating = false;
  }
}

class MyLocation extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is MyLocationOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return IgnorePointer(
      child: StreamBuilder<Null>(
        stream: stream,
        builder: (context, snapshot) => Stack(
          children: <Widget>[_buildPosition(context, options, map, stream)],
        ),
      ),
    );
  }

  Widget _buildPosition(
    BuildContext context,
    MyLocationOptions params,
    MapState map,
    Stream<Null> stream,
  ) {
    var size = 8.0;
    var pixelRadiusX = 0.0;
    var pixelRadiusY = 0.0;
    var pos = map.project(params.point);
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    var pixelPosX = (pos.x - size).toDouble();
    var pixelPosY = (pos.y - size).toDouble();

    if (params.accuracy != null && params.accuracy > 0.0) {
      var coords = ProjMath.calculateEndingGlobalCoordinates(
        params.point.latitude,
        params.point.longitude,
        params.bearing ?? 90.0,
        params.accuracy,
      );
      pos = map.project(LatLng(coords.y, coords.x));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      pixelRadiusX = max(pos.x - pixelPosX, 4).abs().toDouble();
      pixelRadiusY = max(pos.y - pixelPosY, 4).abs().toDouble();
    }

    return Positioned(
      left: pixelPosX - pixelRadiusX / 2,
      top: pixelPosY - pixelRadiusY / 2,
      width: pixelRadiusX,
      height: pixelRadiusY,
      child: Stack(
        overflow: Overflow.visible,
        children: [
          Positioned(
            left: pixelRadiusX / 2,
            top: pixelRadiusY / 2,
            child: CustomPaint(
              painter: PointPainter(
                size: 8.0,
                color: Colors.green,
                opacity: params.opacity,
                outer: pixelRadiusX,
              ),
            ),
          ),
          if (params.bearing != null)
            Opacity(
              opacity: params.opacity,
              child: CustomPaint(
                painter: BearingPainter(params.bearing),
              ),
            ),
          Positioned(
            left: (pixelRadiusX + size) / 2,
            top: size + 16,
            child: CustomPaint(
              painter: LabelPainter("Meg", top: size / 2),
              size: Size(size, size),
            ),
          ),
        ],
      ),
    );
  }
}
