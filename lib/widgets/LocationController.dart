import 'dart:async';

import 'package:SarSys/Services/LocationService.dart';
import 'package:SarSys/plugins/MyLocation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:system_setting/system_setting.dart';

typedef MessageCallback = void Function(String message, {String action, VoidCallback onPressed});
typedef PromptCallback = Future<bool> Function(String title, String message);
typedef TrackingCallback = void Function(bool isTracking);
typedef LocationCallback = void Function(LatLng point);

class LocationController {
  final MapController mapController;
  final MessageCallback onMessage;
  final PromptCallback onPrompt;
  final TrackingCallback onTrackingChanged;
  final LocationCallback onLocationChanged;

  bool _tracking = false;
  bool _resolving = false;
  MyLocationOptions _options;
  StreamSubscription<Position> _subscription;
  LocationService _service = LocationService();

  bool get isTracking => _tracking;
  bool get isReady => _service.isReady.value && _options != null;
  MyLocationOptions get options => _options;

  LocationController({
    @required this.mapController,
    @required this.onMessage,
    @required this.onPrompt,
    this.onTrackingChanged,
    this.onLocationChanged,
  })  : assert(mapController != null, "mapController must not be null"),
        assert(onMessage != null, "onMessage must not be null"),
        assert(onPrompt != null, "onPrompt must not be null");

  void init() async {
    _handleGeolocationStatusChange(await _service.init());
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  bool toggle() {
    var old = _tracking;
    if (_tracking) {
      _tracking = false;
    } else {
      _tracking = _service.isReady.value;
      if (!_tracking) {
        _service.init().then((status) => _handleGeolocationStatusChange(status));
      }
    }
    if (old != _tracking) {
      if (onTrackingChanged != null) onTrackingChanged(_tracking);
    }
    _updateLocation(_service.current, true);
    return _tracking;
  }

  LatLng _toLatLng(Position position) {
    return position == null ? null : LatLng(position?.latitude, position?.longitude);
  }

  void _updateLocation(Position position, bool force) {
    if (position != null && mapController.ready) {
      //locationOpts.bearing = _calculateBearing();
      final center = _toLatLng(position);

      // Full refresh of map needed?
      if (force || _tracking && _isMoved(center)) {
        _options?.point = center;
        if (onLocationChanged != null) onLocationChanged(center);
        mapController.move(center, mapController.zoom);
      }
    }
  }

  bool _isMoved(LatLng position) {
    return _options?.point == null ||
        position != null && (_options.point.latitude - position.latitude).abs() > 0.0001 ||
        (_options.point.longitude - position.longitude).abs() > 0.0001 ||
        (mapController.center.latitude - position.latitude).abs() > 0.0001 ||
        (mapController.center.longitude - position.longitude).abs() > 0.0001;
  }

  void _handleGeolocationStatusChange(GeolocationStatus status) async {
    var isReady = false;
    switch (status) {
      case GeolocationStatus.granted:
        onMessage("Stedstjenester er tilgjengelig");
        isReady = true;
        break;
      case GeolocationStatus.restricted:
        onMessage("Tilgang til stedstjenester er begrenset");
        isReady = true;
        break;
      case GeolocationStatus.denied:
        _handleLocationDenied();
        break;
      case GeolocationStatus.disabled:
        _handleLocationDisabled();
        break;
      default:
        _handlePermissions("Stedstjenester er ikke tilgjengelige");
        break;
    }

    if (isReady) {
      _options = MyLocationOptions(_toLatLng(_service.current));
      _subscription = _service.stream.listen(
        (position) => _updateLocation(position, false),
      );
      if (_tracking && _resolving) onTrackingChanged(_tracking);
    } else {
      dispose();
    }

    _resolving = false;
  }

  void _handlePermissions(String message) async {
    final handler = PermissionHandler();
    onMessage(message, action: "LØS", onPressed: () async {
      var prompt = true;
      // Only supported on Android, iOS always return false
      if (await handler.shouldShowRequestPermissionRationale(PermissionGroup.locationWhenInUse)) {
        prompt = await onPrompt(
            "Stedstjenester",
            "Du har tidligere avslått deling av posisjon. "
                "Du må akseptere deling av lokasjon med appen for å se hvor du er.");
      }
      if (prompt) {
        var response = await handler.requestPermissions([PermissionGroup.locationWhenInUse]);
        var status = response[PermissionGroup.locationWhenInUse];
        if (status == PermissionStatus.granted || status == PermissionStatus.restricted) {
          _resolving = true;
          _handleGeolocationStatusChange(await _service.init());
        } else {
          onMessage(message);
        }
      }
    });
  }

  void _handleLocationDenied() async {
    final handler = PermissionHandler();
    var check = await handler.checkServiceStatus(PermissionGroup.locationWhenInUse);
    if (check == ServiceStatus.disabled) {
      _handleLocationDisabled();
    } else {
      _handlePermissions("Lokalisering er ikke tillatt");
    }
  }

  void _handleLocationDisabled() async {
    onMessage("Stedstjenester er avslått", action: "LØS", onPressed: () async {
      // Will only work on Android. For iOS, this plugin only opens the app setting screen Settings application,
      // as using url schemes to open inner setting path is a violation of Apple's regulations. Using url scheme
      // to open settings can also leads to possible App Store rejection.
      await SystemSetting.goto(SettingTarget.LOCATION);
      _resolving = true;
      _handleGeolocationStatusChange(await _service.init());
    });
  }
}
