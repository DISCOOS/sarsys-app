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

typedef TrackingCallback = void Function(bool isLocated, bool isLocked);
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
  bool _resolving = false;
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
    @required this.appConfigBloc,
    @required this.mapController,
    @required this.onMessage,
    @required this.onPrompt,
    this.tickerProvider,
    this.onTrackingChanged,
    this.onLocationChanged,
  })  : assert(mapController != null, "mapController must not be null"),
        assert(onMessage != null, "onMessage must not be null"),
        assert(onPrompt != null, "onPrompt must not be null"),
        _service = LocationService(appConfigBloc);

  void init() async {
    final status = await _service.configure();
    _handleGeolocationStatusChange(status);
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
    }
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

  void _handleGeolocationStatusChange(GeolocationStatus status) async {
    var isReady = false;
    switch (status) {
      case GeolocationStatus.granted:
        if (_updateAppConfig(true)) onMessage("Stedstjenester er tilgjengelig");
        isReady = true;
        break;
      case GeolocationStatus.restricted:
        if (_updateAppConfig(true)) onMessage("Tilgang til stedstjenester er begrenset");
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
      if (isLocated && _resolving) onTrackingChanged(isLocated, _locked);
    } else {
      dispose();
    }

    _resolving = false;
  }

  bool _updateAppConfig(bool locationWhenInUse) {
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
          _handleGeolocationStatusChange(await _service.configure());
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
      _handleGeolocationStatusChange(await _service.configure());
    });
  }
}
