import 'dart:async';

import 'package:SarSys/Services/location_service.dart';
import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/map/layers/my_location.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:system_setting/system_setting.dart';

typedef TrackingCallback = void Function(bool isTracking, bool isLocked);
typedef LocationCallback = void Function(LatLng point);

class LocationController {
  final AppConfigBloc appConfigBloc;
  final IncidentMapController mapController;
  final TickerProvider tickerProvider;
  final PromptCallback onPrompt;
  final MessageCallback onMessage;
  final TrackingCallback onTrackingChanged;
  final LocationCallback onLocationChanged;

  bool _locked = false;
  bool _tracking = false;
  bool _resolving = false;
  MyLocationOptions _options;
  StreamSubscription<Position> _subscription;
  LocationService _service = LocationService();

  bool get isLocked => _locked;
  bool get isTracking => _tracking;
  bool get isReady => _service.isReady.value && _options != null;
  MyLocationOptions get options => _options;

  LocationController({
    @required this.appConfigBloc,
    @required this.mapController,
    @required this.onMessage,
    @required this.onPrompt,
    this.tickerProvider,
    this.onTrackingChanged,
    this.onLocationChanged,
  })  : assert(mapController != null, "mapController must not be null"),
        assert(onMessage != null, "onMessage must not be null"),
        assert(onPrompt != null, "onPrompt must not be null");

  void init() async {
    mapController.progress.addListener(_onMapMoved);
    _handleGeolocationStatusChange(await _service.init());
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    mapController.progress.removeListener(_onMapMoved);
  }

  bool toggle({locked: false}) {
    var wasLocked = _locked;
    var wasTracking = _tracking;
    if (_tracking && !locked) {
      _locked = false;
      _tracking = false;
    } else {
      _locked = locked;
      _tracking = _service.isReady.value;
      if (!_tracking) {
        _service.init().then((status) => _handleGeolocationStatusChange(status));
      }
    }
    if (wasTracking != _tracking || wasLocked != _locked) {
      if (onTrackingChanged != null) onTrackingChanged(_tracking, _locked);
    }
    _updateLocation(_service.current, _tracking);
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
        if (tickerProvider != null)
          mapController.animatedMove(center, mapController.zoom ?? Defaults.zoom, tickerProvider);
        else
          mapController.move(center, mapController.zoom ?? Defaults.zoom);
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
        if (_updateConfig(true)) onMessage("Stedstjenester er tilgjengelig");
        isReady = true;
        break;
      case GeolocationStatus.restricted:
        if (_updateConfig(true)) onMessage("Tilgang til stedstjenester er begrenset");
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
      if (_tracking && _resolving) onTrackingChanged(_tracking, _locked);
    } else {
      dispose();
    }

    _resolving = false;
  }

  bool _updateConfig(bool locationWhenInUse) {
    var notify = true;
    if (appConfigBloc.isReady) {
      if (notify = appConfigBloc.config.locationWhenInUse != locationWhenInUse) {
        appConfigBloc.update(locationWhenInUse: locationWhenInUse);
      }
    }
    return notify;
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

  void _onMapMoved() {}
}
