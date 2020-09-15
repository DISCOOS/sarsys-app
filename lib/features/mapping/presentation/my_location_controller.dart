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
  MyLocationController({
    @required this.mapController,
    @required this.permissionController,
    this.tickerProvider,
    this.onTrackingChanged,
    this.onLocationChanged,
  })  : assert(mapController != null, "mapController must not be null"),
        assert(permissionController != null, "permissionController must not be null");

  final TickerProvider tickerProvider;
  final MapWidgetController mapController;
  final TrackingCallback onTrackingChanged;
  final LocationCallback onLocationChanged;
  final PermissionController permissionController;

  bool _locked = false;
  MyLocationOptions _options;
  StreamSubscription _positionSubscription;
  StreamController<Null> _updateController = StreamController.broadcast();

  bool get isLocked => _locked;
  Position get current => service?.current;
  MyLocationOptions get options => _options;
  bool get isReady => service?.isReady == true && _options != null;
  LocationService get service => LocationService.exists ? LocationService() : null;
  bool get isAnimating => mapController.isAnimating || (_options != null && _options.isAnimating);
  bool get isLocated => mapController.ready && (isLocked || service?.current?.toLatLng() == mapController?.center);

  Future<LatLng> configure() async {
    return _handle(Completer<LatLng>());
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
      service.update();
      _updateLocation(service.current, isReady);
      if (wasLocated != isLocated || wasLocked != _locked) {
        if (onTrackingChanged != null) {
          onTrackingChanged(isLocated, _locked);
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
        onTrackingChanged(isLocated, _locked);
      }
    }
    return wasLocked;
  }

  void _subscribe() {
    if (_positionSubscription == null) {
      _positionSubscription = service.stream.listen(
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
    bool moveMap = goto || _locked;
    if (position != null && mapController.ready) {
      final point = position?.toLatLng();
      final wasChangeInAccuracy = (_options?.accuracy != position?.acc);
      _options?.accuracy = position?.acc;
      // Should move position?
      if (moveMap || _isMoved(point)) {
        hasMoved = true;
        if (onLocationChanged != null) {
          onLocationChanged(point, goto, _locked);
        }
        if (isAnimated()) {
          // Move map to position?
          if (moveMap) {
            mapController.animatedMove(
              point,
              mapController.zoom ?? Defaults.zoom,
              tickerProvider,
            );
          }
          _options.animatedMove(position, onMove: (point) {
            // Synchronize map control state with my location animation
            if (onTrackingChanged != null) {
              onTrackingChanged(isLocated, _locked);
            }
          });
        } else {
          if (moveMap) {
            mapController.move(
              point,
              mapController.zoom ?? Defaults.zoom,
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
      onTrackingChanged(isLocated, _locked);
    }
    return hasMoved;
  }

  bool isAnimated() => tickerProvider != null;

  void _progress(Position position, {@required bool moved}) {
    _options?.point = position.toLatLng();
    if (moved) {
      _options?.track?.add(position);
    }
    _updateController.add(null);
  }

  bool _isMoved(LatLng position) {
    return _options?.point == null ||
        position != null && (_options.point.latitude - position.latitude).abs() > 0.0001 ||
        (_options.point.longitude - position.longitude).abs() > 0.0001 ||
        (mapController.center.latitude - position.latitude).abs() > 0.0001 ||
        (mapController.center.longitude - position.longitude).abs() > 0.0001;
  }

  Future<LatLng> _handle(Completer<LatLng> completer) async {
    final status = await service.status;
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
        _toLatLng(service.current),
      );
    }
    try {
      if (service.isReady) {
        _onReady(completer);
      } else {
        final status = await service.status;
        if (status != PermissionStatus.granted) {
          // Wait before retrying
          await Future.delayed(
            const Duration(milliseconds: 100),
            () => _handle(completer),
          );
        } else if (!service.isReady) {
          service.onEvent.where((event) => event is ConfigureEvent).first.then(
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
    final options = build();
    _subscribe();
    if (isLocated) {
      onTrackingChanged(isLocated, _locked);
    }
    if (onLocationChanged != null) {
      onLocationChanged(options.point, isLocated, _locked);
    }
    completer.complete(options.point);
  }

  MyLocationOptions build({bool withTail}) {
    // Duplicates are overwritten
    final point = _toLatLng(service.current);
    _options?.cancel();
    _options = MyLocationOptions(
      point,
      opacity: 0.5,
      track: service.positions,
      accuracy: service.current?.acc,
      tickerProvider: tickerProvider,
      locationUpdates: _updateController,
      rebuild: _updateController?.stream,
      showTail: withTail ?? _options?.showTail ?? false,
    );
    return _options;
  }
}
