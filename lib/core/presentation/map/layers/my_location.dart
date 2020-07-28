import 'dart:async';
import 'dart:ui';
import 'dart:math';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/domain/models/Position.dart';
import 'package:SarSys/core/presentation/map/painters.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart' hide Path;

class MyLocationOptions extends LayerOptions {
  MyLocationOptions(
    this.point, {
    @required this.tickerProvider,
    @required this.locationUpdates,
    this.bearing,
    this.accuracy,
    this.size = 30.0,
    this.opacity = 0.6,
    this.showTail = true,
    this.track = const [],
    this.milliSeconds = 500,
    this.color = Colors.green,
    Stream<Null> rebuild,
  }) : super(rebuild: rebuild) {
    assert(tickerProvider != null, 'tickerProvider can not be null');
    assert(locationUpdates != null, 'locationUpdates can not be null');
  }

  final Color color;
  final double bearing;
  final double opacity;
  final int milliSeconds;
  final Iterable<Position> track;
  final TickerProvider tickerProvider;
  final StreamSink<Null> locationUpdates;

  // Allow external change
  double size;
  LatLng point;
  LatLng next;
  bool showTail;
  LatLng previous;
  double accuracy;

  AnimationController _controller;
  bool get isAnimating => _controller != null;

  void cancel() {
    if (_controller != null) {
      _controller.dispose();
      _controller = null;
      next = null;
      previous = null;
    }
  }

  /// Move icon to given point
  void animatedMove(LatLng point, {double bearing, void onMove(LatLng p)}) {
    if (isAnimating) return;

    next = point;
    previous = this.point;

    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> previous position and the destination.
    final _latTween = Tween<double>(begin: previous.latitude, end: next.latitude);
    final _lngTween = Tween<double>(begin: previous.longitude, end: next.longitude);

    // Create a animation controller that has a duration and a TickerProvider.
    _controller = AnimationController(duration: Duration(milliseconds: milliSeconds), vsync: tickerProvider);

    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation = CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn);

    _controller.addListener(() {
      this.point = LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation));
      if (onMove != null) onMove(this.point);
      locationUpdates.add(null);
    });

    animation.addStatusListener((status) {
      if ([AnimationStatus.completed, AnimationStatus.dismissed].contains(status)) {
        _finish(point);
      }
    });
    _controller.forward();
  }

  void _finish(LatLng point) {
    this.point = point;
    cancel();
  }
}

class MyLocation extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is MyLocationOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints bc) {
      final size = Size(bc.maxWidth, bc.maxHeight);
      return IgnorePointer(
        child: StreamBuilder<Null>(
          stream: stream,
          builder: (context, snapshot) => _build(
            context,
            options as MyLocationOptions,
            map,
            size,
          ),
        ),
      );
    });
  }

  Stack _build(
    BuildContext context,
    MyLocationOptions options,
    MapState map,
    Size size,
  ) {
    return Stack(
      children: <Widget>[
        _buildPosition(context, options, map),
        if (options.showTail && options.track.isNotEmpty)
          _buildTrack(
            context,
            options,
            map,
            size,
          ),
      ],
    );
  }

  Widget _buildPosition(BuildContext context, MyLocationOptions options, MapState map) {
    var size = 8.0;
    var pos = map.project(options.point);
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    var pixelRadius = _toPixelRadius(map, size, pos.x, pos.y, options);

    return Positioned(
      top: pos.y,
      left: pos.x,
      width: pixelRadius,
      height: pixelRadius,
      child: Stack(
        overflow: Overflow.visible,
        children: [
          Positioned(
            left: 0.0,
            top: 0.0,
            child: CustomPaint(
              painter: PointPainter(
                size: 8.0,
                color: Colors.green,
                opacity: options.opacity,
                outer: pixelRadius,
              ),
            ),
          ),
          if (options.bearing != null)
            CustomPaint(
              painter: BearingPainter(options.bearing),
            ),
          Positioned(
            left: 0,
            top: size,
            child: CustomPaint(
              painter: LabelPainter("Meg", top: size),
              size: Size(size, size),
            ),
          ),
        ],
      ),
    );
  }

  static int _idx = 0;

  _buildTrack(
    BuildContext context,
    MyLocationOptions options,
    MapState map,
    Size size,
  ) {
    final track = List<Position>.from(options.track);
    final bounds = map.getBounds();
    _idx++;
    print('$_idx');
    var offsets = track.reversed.take(10).map((p) => p.toLatLng()).where((p) => bounds.contains(p)).map((position) {
      var pos = map.project(position);
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      return Offset(pos.x.toDouble(), pos.y.toDouble());
    }).toList();

    return CustomPaint(
      painter: LineStringPainter(
        offsets: offsets,
        color: Colors.blue,
        borderColor: Colors.blue,
        opacity: options.opacity,
      ),
      size: size,
    );
  }

  double _toPixelRadius(MapState map, double size, double x, double y, MyLocationOptions options) {
    var pixelRadius = size;
    if (options.accuracy != null && options.accuracy > 0.0) {
      var coords = ProjMath.calculateEndingGlobalCoordinates(
        options.point.latitude,
        options.point.longitude,
        45.0,
        options.accuracy,
      );
      var pos = map.project(LatLng(coords.y, coords.x));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      pixelRadius = min(max((pos.x - x).abs(), size), max((pos.y - y).abs(), size).abs()).toDouble();
    }
    return pixelRadius;
  }
}
