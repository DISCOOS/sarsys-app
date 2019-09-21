import 'dart:async';

import 'package:SarSys/Services/location_service.dart';
import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/map/layers/my_location.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

typedef TrackingCallback = void Function(bool isLocated, bool isLocked);
typedef LocationCallback = void Function(LatLng point);

class LocationController {
  final AppConfigBloc configBloc;
  final IncidentMapController mapController;
  final PermissionController permissionController;
  final TickerProvider tickerProvider;
  final TrackingCallback onTrackingChanged;
  final LocationCallback onLocationChanged;

  bool _locked = false;
  LocationService _service;
  MyLocationOptions _options;
  StreamSubscription _positionSubscription;
  StreamController<Null> _locationUpdateController;

  bool get isLocked => _locked;
  bool get isAnimating => mapController.isAnimating || (_options != null && _options.isAnimating);
  bool get isLocated => mapController.ready && (isLocked || _toLatLng(_service?.current) == mapController?.center);
  bool get isReady => _service.isReady.value && _options != null;
  MyLocationOptions get options => _options;

  LocationController({
    @required this.configBloc,
    @required this.mapController,
    @required this.permissionController,
    this.tickerProvider,
    this.onTrackingChanged,
    this.onLocationChanged,
  })  : assert(mapController != null, "mapController must not be null"),
        assert(permissionController != null, "permissionController must not be null"),
        _service = LocationService(configBloc);

  /// Get current location
  get current => _service.current;

  void init() async {
    _handle(await _service.configure());
  }

  void dispose() {
    _options = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationUpdateController?.close();
    _locationUpdateController = null;
  }

  bool goto({locked: false}) {
    if (isReady) {
      var wasLocked = _locked;
      var wasLocated = isLocated;
      _locked = locked;
      _updateLocation(_service.current, isReady);
      if (wasLocated != isLocated || wasLocked != _locked) {
        if (onTrackingChanged != null) onTrackingChanged(isLocated, _locked);
      }
    } else
      _handle(_service.status);
    return isLocated;
  }

  bool stop() {
    var wasLocked = _locked;
    _locked = false;
    if (wasLocked != _locked) {
      if (onTrackingChanged != null) onTrackingChanged(isLocated, _locked);
    }
    return wasLocked;
  }

  LatLng _toLatLng(Position position) {
    return position == null ? LatLng(0, 0) : LatLng(position?.latitude, position?.longitude);
  }

  bool _updateLocation(Position position, bool goto) {
    bool hasMoved = false;
    bool wasLocated = isLocated;
    if (position != null && mapController.ready) {
      final wasChangeInAccuracy = (_options?.accuracy != position.accuracy);
      _options.accuracy = position.accuracy;
      final point = _toLatLng(position);
      // Full refresh of map needed?
      if (goto || isLocked) {
        hasMoved = true;
        if (onLocationChanged != null) onLocationChanged(point);
        if (goto || _locked) {
          if (tickerProvider != null) {
            mapController.animatedMove(
              point,
              mapController.zoom ?? Defaults.zoom,
              tickerProvider,
            );
            options.animatedMove(point, onMove: (point) {
              // Synchronize map control state with my location animation
              if (onTrackingChanged != null) onTrackingChanged(isLocated, _locked);
            });
          } else {
            mapController.move(point, mapController.zoom ?? Defaults.zoom);
          }
        }
      } else if (_isMoved(point)) {
        if (onLocationChanged != null) onLocationChanged(point);
        if (_options.point == null || tickerProvider == null) {
          _locationUpdateController.add(null);
        } else {
          _options.animatedMove(point, onMove: (point) {
            // Synchronize map control state with my location animation
            if (onTrackingChanged != null) onTrackingChanged(isLocated, _locked);
          });
        }
      } else if (wasChangeInAccuracy) {
        _locationUpdateController.add(null);
      }
    }
    if (onTrackingChanged != null && wasLocated != isLocated) onTrackingChanged(isLocated, _locked);
    return hasMoved;
  }

  bool _isMoved(LatLng position) {
    return _options?.point == null ||
        position != null && (_options.point.latitude - position.latitude).abs() > 0.0001 ||
        (_options.point.longitude - position.longitude).abs() > 0.0001 ||
        (mapController.center.latitude - position.latitude).abs() > 0.0001 ||
        (mapController.center.longitude - position.longitude).abs() > 0.0001;
  }

  void _handle(PermissionStatus status) async {
    await permissionController.handle(
        status, permissionController.locationWhenInUseRequest.copyWith(onReady: _onReady));
  }

  void _onReady() async {
    final status = await _service.configure();
    if (_service.isReady.value) {
      assert(_locationUpdateController == null);
      _locationUpdateController = StreamController.broadcast();

      _options = MyLocationOptions(
        _toLatLng(_service.current),
        opacity: 0.5,
        tickerProvider: tickerProvider,
        locationUpdateController: _locationUpdateController,
        rebuild: _locationUpdateController.stream,
      );
      _positionSubscription = _service.stream.listen(
        (position) => _updateLocation(position, false),
      );
      if (isLocated && permissionController.resolving) onTrackingChanged(isLocated, _locked);
    } else
      _handle(status);
  }
}
