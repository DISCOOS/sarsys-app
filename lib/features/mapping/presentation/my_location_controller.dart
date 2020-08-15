import 'dart:async';
import 'dart:io';

import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/core/permission_controller.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/mapping/presentation/layers/my_location.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:catcher/catcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

typedef TrackingCallback = void Function(bool isLocated, bool isLocked);
typedef LocationCallback = void Function(LatLng point, bool located, bool locked);

class MyLocationController {
  final TickerProvider tickerProvider;
  final MapWidgetController mapController;
  final TrackingCallback onTrackingChanged;
  final LocationCallback onLocationChanged;
  final PermissionController permissionController;

  bool _locked = false;
  LocationService _service;
  MyLocationOptions _options;
  StreamSubscription _positionSubscription;
  StreamController<Null> _updateController = StreamController.broadcast();

  bool get isLocked => _locked;
  LocationService get service => _service;
  MyLocationOptions get options => _options;
  bool get isReady => _service.isReady.value && _options != null;
  bool get isAnimating => mapController.isAnimating || (_options != null && _options.isAnimating);
  bool get isLocated => mapController.ready && (isLocked || _service?.current?.toLatLng() == mapController?.center);

  MyLocationController({
    @required this.mapController,
    @required this.permissionController,
    this.tickerProvider,
    this.onTrackingChanged,
    this.onLocationChanged,
  })  : assert(mapController != null, "mapController must not be null"),
        assert(permissionController != null, "permissionController must not be null"),
        _service = LocationService();

  Position get current => _service.current;

  Future<LatLng> configure() async {
    return _handle(
      await _service.configure(),
    );
  }

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    options?.cancel();
    mapController?.cancel();
    permissionController?.dispose();
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
      _updateLocation(_service.current, isReady);
      if (wasLocated != isLocated || wasLocked != _locked) {
        if (onTrackingChanged != null) {
          onTrackingChanged(isLocated, _locked);
        }
      }
    } else {
      _handle(_service.status);
    }
    return isLocated;
  }

  bool stop() {
    var wasLocked = _locked;
    _locked = false;
    if (wasLocked != _locked) {
      if (onTrackingChanged != null) {
        onTrackingChanged(isLocated, _locked);
      }
    }
    return wasLocked;
  }

  void _subscribe() {
    if (_positionSubscription == null) {
      _positionSubscription = _service.stream.listen(
        (position) => _updateLocation(position, false),
      );
      if (Platform.isIOS) {
        // Proposed workaround on iOS for https://github.com/BaseflowIT/flutter-geolocator/issues/190
        _positionSubscription.onError((e, stackTrace) {
          Catcher.reportCheckedError(e, stackTrace);
          _positionSubscription.cancel();
          _subscribe();
        });
      }
    }
  }

  LatLng _toLatLng(Position position) {
    return position == null ? LatLng(0, 0) : LatLng(position?.lat, position?.lon);
  }

  bool _updateLocation(Position position, bool goto) {
    bool hasMoved = false;
    bool wasLocated = isLocated;
    if (position != null && mapController.ready) {
      final wasChangeInAccuracy = (_options?.accuracy != position?.acc);
      _options?.accuracy = position?.acc;
      final point = _toLatLng(position);
      // Full refresh of map needed?
      if (goto || _locked) {
        hasMoved = true;
        if (onLocationChanged != null) {
          onLocationChanged(point, goto, _locked);
        }
        if (goto || _locked) {
          if (tickerProvider != null) {
            mapController.animatedMove(
              point,
              mapController.zoom ?? Defaults.zoom,
              tickerProvider,
            );
            _options.animatedMove(point, onMove: (point) {
              // Synchronize map control state with my location animation
              if (onTrackingChanged != null) {
                onTrackingChanged(isLocated, _locked);
              }
            });
          } else {
            _options?.point = point;
            mapController.move(point, mapController.zoom ?? Defaults.zoom);
          }
        }
      } else if (_isMoved(point)) {
        if (onLocationChanged != null) {
          onLocationChanged(point, false, isLocked);
        }
        if (tickerProvider == null) {
          _options?.point = point;
          _updateController.add(null);
        } else {
          _options.animatedMove(point, onMove: (point) {
            // Synchronize map control state with my location animation
            if (onTrackingChanged != null) {
              onTrackingChanged(isLocated, _locked);
            }
          });
        }
      } else if (wasChangeInAccuracy) {
        _options?.point = point;
        _updateController.add(null);
      }
    }
    if (onTrackingChanged != null && wasLocated != isLocated) {
      onTrackingChanged(isLocated, _locked);
    }
    return hasMoved;
  }

  bool _isMoved(LatLng position) {
    return _options?.point == null ||
        position != null && (_options.point.latitude - position.latitude).abs() > 0.0001 ||
        (_options.point.longitude - position.longitude).abs() > 0.0001 ||
        (mapController.center.latitude - position.latitude).abs() > 0.0001 ||
        (mapController.center.longitude - position.longitude).abs() > 0.0001;
  }

  Future<LatLng> _handle(PermissionStatus status) async {
    final completer = Completer<LatLng>();
    if (status.isGranted) {
      _onReady(completer);
    } else {
      // Wait for result to prevent concurrent attempts
      await permissionController.handle(
        status,
        permissionController.locationWhenInUseRequest.copyWith(
          onReady: () => _onReady(completer),
        ),
      );
    }
    return completer.future;
  }

  void _onReady(Completer<LatLng> completer) async {
    if (_disposed) {
      return completer.complete(
        _toLatLng(_service.current),
      );
    }
    try {
      var status = _service.status;
      if (!_service.isReady.value) {
        status = await _service.configure();
      }
      if (_service.isReady.value) {
        final options = build();
        _subscribe();
        if (isLocated && !permissionController.resolving) {
          onTrackingChanged(isLocated, _locked);
        }
        completer.complete(options.point);
      } else if (status != PermissionStatus.granted) {
        await Future.delayed(Duration(milliseconds: 100));
        final point = await _handle(status);
        completer.complete(point);
      } else {
        completer.complete(options?.point);
      }
    } on Exception catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
    }
  }

  MyLocationOptions build({bool withTail}) {
    // Duplicates are overwritten
    final history = List<Position>.from(_service.positions);
    final point = _toLatLng(_service.current);
    _options?.cancel();
    _options = MyLocationOptions(
      point,
      opacity: 0.5,
      track: history,
      accuracy: service.current?.acc,
      tickerProvider: tickerProvider,
      locationUpdates: _updateController,
      rebuild: _updateController?.stream,
      showTail: withTail ?? _options?.showTail ?? false,
    );
    return _options;
  }
}
