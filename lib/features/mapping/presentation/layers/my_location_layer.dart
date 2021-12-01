

import 'dart:async';
import 'dart:ui';
import 'dart:math';

import 'package:SarSys/core/error_handler.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/mapping/presentation/painters.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'dart:io';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/core/permission_controller.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

typedef TrackingCallback = void Function(bool isLocated, bool isLocked);
typedef LocationCallback = void Function(LatLng point, bool located, bool locked);

class MyLocationLayerOptions extends LayerOptions {
  MyLocationLayerOptions(
    this.point, {
    required this.tickerProvider,
    required this.locationUpdates,
    this.bearing,
    this.accuracy,
    this.size = 30.0,
    this.opacity = 0.6,
    this.showTail = true,
    this.milliSeconds = 500,
    this.color = Colors.green,
    Stream<Null>? rebuild,
    Iterable<Position?> track = const [],
  })  : track = List<Position>.from(track),
        super(rebuild: rebuild) {
    assert(tickerProvider != null, 'tickerProvider can not be null');
    assert(locationUpdates != null, 'locationUpdates can not be null');
  }

  final Color color;
  final double? bearing;
  final double opacity;
  final int milliSeconds;
  final List<Position> track;
  final TickerProvider? tickerProvider;
  final StreamSink<Null>? locationUpdates;

  // Allow external change
  double size;
  LatLng point;
  LatLng? next;
  bool showTail;
  LatLng? previous;
  double? accuracy;

  AnimationController? _controller;
  bool get isAnimating => _controller != null;

  void cancel() {
    if (_controller != null) {
      _controller!.dispose();
      _controller = null;
      next = null;
      previous = null;
    }
  }

  /// Move icon to given point
  void animatedMove(Position position, {double? bearing, void onMove(LatLng p)?}) {
    if (isAnimating) return;

    previous = this.point;
    track.add(position);
    next = position.toLatLng();

    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> previous position and the destination.
    final _latTween = Tween<double>(begin: previous!.latitude, end: next!.latitude);
    final _lngTween = Tween<double>(begin: previous!.longitude, end: next!.longitude);

    // Create a animation controller that has a duration and a TickerProvider.
    _controller = AnimationController(duration: Duration(milliseconds: milliSeconds), vsync: tickerProvider!);

    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation = CurvedAnimation(parent: _controller!, curve: Curves.fastOutSlowIn);

    _controller!.addListener(() {
      point = LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation));
      _moveNext(point, position);
      if (onMove != null) {
        onMove(this.point);
      }
    });

    animation.addStatusListener((status) {
      if ([AnimationStatus.completed, AnimationStatus.dismissed].contains(status)) {
        _moveEnd(position);
      }
    });
    _controller!.forward();
  }

  void _moveNext(LatLng next, Position end) {
    point = next;
    track.removeLast();
    track.add(end.copyWith(
      lat: next.latitude,
      lon: next.longitude,
    ));
    locationUpdates!.add(null);
  }

  void _moveEnd(Position position) {
    point = position.toLatLng();
    track.add(position);
    locationUpdates!.add(null);
    cancel();
  }
}

class MyLocationLayer extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is MyLocationLayerOptions;
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
            options as MyLocationLayerOptions,
            map,
            size,
          ),
        ),
      );
    });
  }

  Stack _build(
    BuildContext context,
    MyLocationLayerOptions options,
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

  Widget _buildPosition(BuildContext context, MyLocationLayerOptions options, MapState map) {
    var size = 8.0;
    var pos = map.project(options.point);
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
    var pixelRadius = _toPixelRadius(map, size, pos.x as double, pos.y as double, options);

    return Positioned(
      top: pos.y as double?,
      left: pos.x as double?,
      width: pixelRadius,
      height: pixelRadius,
      child: Stack(
        clipBehavior: Clip.none,
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

  _buildTrack(
    BuildContext context,
    MyLocationLayerOptions options,
    MapState map,
    Size size,
  ) {
    final track = List<Position>.from(options.track);
    final bounds = map.getBounds();
    var offsets = track.reversed
        .where((p) => p.isNotEmpty)
        .take(1000)
        .map((p) => p.toLatLng())
        .where((p) => bounds.contains(p))
        .map((position) {
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

  double _toPixelRadius(MapState map, double size, double x, double y, MyLocationLayerOptions options) {
    var pixelRadius = size;
    if (options.accuracy != null && options.accuracy! > 0.0) {
      var coords = ProjMath.calculateEndingGlobalCoordinates(
        options.point.latitude,
        options.point.longitude,
        45.0,
        options.accuracy!,
      );
      var pos = map.project(LatLng(coords.y!, coords.x!));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      pixelRadius = min(max((pos.x - x).abs(), size), max((pos.y - y).abs(), size).abs()).toDouble();
    }
    return pixelRadius;
  }
}

class MyLocationLayerController {
  MyLocationLayerController({
    required this.mapController,
    required this.permissionController,
    this.tickerProvider,
    this.onTrackingChanged,
    this.onLocationChanged,
  })  : assert(mapController != null, "mapController must not be null"),
        assert(permissionController != null, "permissionController must not be null");

  final TickerProvider? tickerProvider;
  final MapWidgetController mapController;
  final TrackingCallback? onTrackingChanged;
  final LocationCallback? onLocationChanged;
  final PermissionController permissionController;

  bool _locked = false;
  MyLocationLayerOptions? _options;
  StreamSubscription? _positionSubscription;
  StreamController<Null>? _updateController = StreamController.broadcast();

  bool get isLocked => _locked;
  Position? get current => service?.current;
  MyLocationLayerOptions? get options => _options;
  bool get isReady => service?.isReady == true && _options != null && _disposed == false;
  LocationService? get service => LocationService.exists ? LocationService() : null;
  bool get isAnimating => mapController.isAnimating || (_options != null && _options!.isAnimating);
  bool get isLocated => isLocked || service?.current?.toLatLng() == mapController.center;

  Future<LatLng> configure() async {
    assert(_disposed == false, "Is disposed");
    return _handle(Completer<LatLng>());
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    options?.cancel();
    mapController.cancel();
    permissionController.dispose();
    _positionSubscription?.cancel();
    _updateController?.close();
    _options = null;
    _positionSubscription = null;
    _updateController = null;
  }

  bool goto({locked: false}) {
    if (isReady) {
      var wasLocked = _locked;
      var wasLocated = isLocated;
      _locked = locked;
      service!.update();
      _updateLocation(service!.current, isReady);
      if (wasLocated != isLocated || wasLocked != _locked) {
        if (onTrackingChanged != null) {
          onTrackingChanged!(isLocated, _locked);
        }
      }
    } else {
      _handle(Completer<LatLng>());
    }
    return isLocated;
  }

  bool stop() {
    var wasLocked = _locked;
    _locked = false;
    if (wasLocked != _locked) {
      if (onTrackingChanged != null) {
        onTrackingChanged!(isLocated, _locked);
      }
    }
    return wasLocked;
  }

  void _subscribe() {
    if (_positionSubscription == null) {
      _positionSubscription = service!.stream.listen(
        (position) => _updateLocation(position, false),
      );
      if (Platform.isIOS) {
        // Proposed workaround on iOS for https://github.com/BaseflowIT/flutter-geolocator/issues/190
        _positionSubscription!.onError((e, stackTrace) {
          SarSysApp.reportCheckedError(e, stackTrace);
          _positionSubscription!.cancel();
          _subscribe();
        });
      }
    }
  }

  LatLng _toLatLng(Position? position) {
    return position == null ? LatLng(0, 0) : LatLng(position.lat!, position.lon!);
  }

  bool _updateLocation(Position? position, bool goto) {
    bool hasMoved = false;
    if (!_disposed) {
      bool wasLocated = isLocated;
      bool moveMap = goto || _locked;
      if (position != null) {
        final point = position.toLatLng();
        final wasChangeInAccuracy = (_options?.accuracy != position.acc);
        _options?.accuracy = position.acc;
        // Should move position?
        if (moveMap || _isMoved(point)) {
          hasMoved = true;
          if (onLocationChanged != null) {
            onLocationChanged!(point, goto, _locked);
          }
          if (isAnimated()) {
            // Move map to position?
            if (moveMap) {
              mapController.animatedMove(
                point,
                mapController.zoom,
                tickerProvider,
              );
            }
            _options!.animatedMove(position, onMove: (point) {
              // Synchronize map control state with my location animation
              if (onTrackingChanged != null) {
                onTrackingChanged!(isLocated, _locked);
              }
            });
          } else {
            if (moveMap) {
              mapController.move(
                point,
                mapController.zoom,
              );
            }
          }
        }
        if (hasMoved || wasChangeInAccuracy) {
          _progress(
            position,
            // Only if move is not animated
            moved: hasMoved && isAnimated(),
          );
        }
      }
      if (onTrackingChanged != null && wasLocated != isLocated) {
        onTrackingChanged!(isLocated, _locked);
      }
    }
    return hasMoved;
  }

  bool isAnimated() => tickerProvider != null;

  void _progress(Position position, {required bool moved}) {
    _options?.point = position.toLatLng();
    if (moved) {
      _options?.track.add(position);
    }
    _updateController!.add(null);
  }

  bool _isMoved(LatLng position) {
    return _options?.point == null ||
        position != null && (_options!.point.latitude - position.latitude).abs() > 0.0001 ||
        (_options!.point.longitude - position.longitude).abs() > 0.0001 ||
        (mapController.center.latitude - position.latitude).abs() > 0.0001 ||
        (mapController.center.longitude - position.longitude).abs() > 0.0001;
  }

  Future<LatLng> _handle(Completer<LatLng> completer) async {
    final status = await service!.status;
    if (status.isGranted) {
      _onGranted(completer);
    } else {
      // Wait for result to prevent concurrent attempts
      await permissionController.handle(
        status,
        permissionController.locationRequest.copyWith(
          onReady: () => _onGranted(completer),
        ),
      );
    }
    return completer.future;
  }

  void _onGranted(Completer<LatLng> completer) async {
    if (_disposed) {
      return completer.complete(
        _toLatLng(service!.current),
      );
    }
    try {
      if (service!.isReady!) {
        _onReady(completer);
      } else {
        final status = await service!.status;
        if (status != PermissionStatus.granted) {
          // Wait before retrying
          await Future.delayed(
            const Duration(milliseconds: 100),
            () => _handle(completer),
          );
        } else if (!service!.isReady!) {
          service!.onEvent.where((event) => event is ConfigureEvent).first.then(
            (_) {
              return _onReady(completer);
            },
          );
        } else {
          completer.complete(options?.point);
        }
      }
    } on Exception catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
    }
  }

  void _onReady(Completer<LatLng> completer) {
    if (_disposed) {
      completer.complete(
        service!.current?.toLatLng(),
      );
    } else {
      final options = build()!;
      _subscribe();
      if (isLocated) {
        onTrackingChanged!(isLocated, _locked);
      }
      if (onLocationChanged != null) {
        onLocationChanged!(options.point, isLocated, _locked);
      }
      completer.complete(options.point);
    }
  }

  MyLocationLayerOptions? build({bool? withTail}) {
    // Duplicates are overwritten
    final point = _toLatLng(service!.current);
    _options?.cancel();
    _options = MyLocationLayerOptions(
      point,
      opacity: 0.5,
      track: service!.positions,
      accuracy: service!.current?.acc,
      tickerProvider: tickerProvider,
      locationUpdates: _updateController,
      rebuild: _updateController?.stream,
      showTail: withTail ?? _options?.showTail ?? false,
    );
    return _options;
  }
}
