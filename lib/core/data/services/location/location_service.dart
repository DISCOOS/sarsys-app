import 'package:SarSys/core/data/services/location/background_geolocation_service.dart';
import 'package:SarSys/core/domain/models/Position.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/core/domain/models/Point.dart';
import 'package:SarSys/core/utils/data.dart' as utils;
import 'package:flutter/foundation.dart';
import 'package:latlong/latlong.dart';
import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

abstract class LocationService {
  /// Get [Device.uuid] being tracked
  String get duuid;

  /// Check if positions stored locally
  bool get isTracking;

  /// Check if positions stored locally are posted to [Device.uuid]
  bool get isSharing;

  /// Get [AppConfigBloc] instance
  AppConfigBloc get configBloc;

  /// Get current [Position]
  Position get current;

  /// Get permission status
  PermissionStatus get status;

  /// Get [ValueNotifier] for
  /// detecting when service is ready
  ValueNotifier<bool> get isReady;

  /// Get stream of positions
  Stream<Position> get stream;

  /// Get stream of events
  Stream<LocationEvent> get onChanged;

  /// Get all events registered @
  /// since last application start
  Iterable<LocationEvent> get events;

  /// Get positions gathered since
  /// last application start
  Iterable<Position> get positions;

  /// Get all positions stored on this device
  Future<Iterable<Position>> history();

  /// Clear all positions stored on this device
  Future clear();

  /// Get authentication token required
  /// to publish positions to backend
  String get token;
  set token(String token);

  /// Get event from index
  LocationEvent operator [](int index);

  /// Configure location service from
  /// [configBloc.config] and given params.
  ///
  /// Use [duuid] to change which id positions are publish with
  /// Use [token] to change which authorisation token to publish positions with
  /// Use [track] to control storing positions to history locally
  /// Use [share] to control pushing positions with id [duuid]
  /// Use [force] to force reconfiguration of service
  Future<PermissionStatus> configure({
    String duuid,
    String token,
    bool track,
    bool share,
    bool force = false,
  });

  /// Request location update manually.
  Future<Position> update();

  /// Check if service is disposed.
  /// If disposed, it can not be
  /// used anymore and [LocationService]
  /// must be created one more.
  bool get disposed;

  /// Dispose service.
  /// If disposed, it can not be
  /// used anymore and [LocationService]
  /// must be created one more.
  Future dispose();

  static LatLng toLatLng(Position position) => position == null ? Defaults.origo : LatLng(position?.lat, position?.lon);

  static Point toPoint(Position position) => utils.toPoint(toLatLng(position));

  static String toAccuracyName(LocationAccuracy value) {
    switch (value) {
      case LocationAccuracy.lowest:
        return "Lavest";
      case LocationAccuracy.low:
        return "Lav";
      case LocationAccuracy.medium:
        return "Medium";
      case LocationAccuracy.high:
        return "Høy";
      case LocationAccuracy.best:
        return "Best";
      case LocationAccuracy.bestForNavigation:
        return "Navigasjon";
      default:
        return "Høy";
    }
  }

  static LocationService _singleton;

  factory LocationService({
    String duuid,
    String token,
    AppConfigBloc configBloc,
  }) {
    if (_singleton == null || _singleton.disposed) {
      _singleton = BackgroundGeolocationService(
        duuid: duuid ?? _singleton?.duuid,
        token: token ?? _singleton?.token,
        configBloc: configBloc ?? _singleton?.configBloc,
      );
//      _singleton = GeolocatorService(bloc);
    }
    return _singleton;
  }
}

enum LocationAccuracy {
  lowest,
  low,
  medium,
  high,
  best,
  bestForNavigation,
}

class LocationOptions {
  /// Initializes a new [LocationOptions] instance with default values.
  ///
  /// The following default values are used:
  /// - accuracy: best
  /// - distanceFilter: 0
  /// - forceAndroidLocationManager: false
  /// - timeInterval: 0
  const LocationOptions({
    this.accuracy = LocationAccuracy.best,
    this.distanceFilter = 0,
    this.forceAndroidLocationManager = false,
    this.timeInterval = 0,
  });

  /// Defines the desired accuracy that should be used to determine the location data.
  ///
  /// The default value for this field is [LocationAccuracy.best].
  final LocationAccuracy accuracy;

  /// The minimum distance (measured in meters) a device must move horizontally before an update event is generated.
  ///
  /// Supply 0 when you want to be notified of all movements. The default is 0.
  final int distanceFilter;

  /// Uses [FusedLocationProviderClient] by default and falls back to [LocationManager] when set to true.
  ///
  /// On platforms other then Android this parameter is ignored.
  final bool forceAndroidLocationManager;

  /// The desired interval for active location updates, in milliseconds (Android only).
  ///
  /// On iOS this value is ignored since position updates based on time intervals are not supported.
  final int timeInterval;
}

abstract class LocationEvent {
  LocationEvent(this.stackTrace);
  final StackTrace stackTrace;
  final DateTime timestamp = DateTime.now();
}

class CreateEvent extends LocationEvent {
  CreateEvent(this.duuid, this.config) : super(StackTrace.current);
  final String duuid;
  final AppConfig config;

  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
      'duuid: $duuid,'
      'AppConfig: {\n'
      '   accuracy: ${config.locationAccuracy}\n'
      '   interval: ${config.locationFastestInterval}\n'
      '   displacement: ${config.locationSmallestDisplacement}\n'
      '   permission: ${config.locationWhenInUse}\n'
      '}';
}

class PositionEvent extends LocationEvent {
  PositionEvent(this.position) : super(StackTrace.current);
  final Position position;

  @override
  String toString() {
    return 'When: ${timestamp.toIso8601String()}\n'
        'Position: {\n'
        '   lat: ${position.lat}\n'
        '   lon: ${position.lon}\n'
        '   alt: ${position.alt}\n'
        '   acc: ${position.acc}\n'
        '   heading: ${position.bearing}\n'
        '   speed: ${position.speed}\n'
        '   time: ${position.timestamp.toIso8601String()}\n'
        '}';
  }
}

class SubscribeEvent extends LocationEvent {
  SubscribeEvent(this.options) : super(StackTrace.current);
  final LocationOptions options;
  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
      'Options: {\n'
      '   accuracy: ${options.accuracy}\n'
      '   timeInterval: ${options.timeInterval}\n'
      '   distanceFilter: ${options.distanceFilter}\n'
      '   forceAndroidLocationManager: ${options.forceAndroidLocationManager}\n'
      '}';
}

class UnsubscribeEvent extends LocationEvent {
  UnsubscribeEvent(this.options) : super(StackTrace.current);
  final LocationOptions options;
  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
      'Options: {\n'
      '   accuracy: ${options.accuracy}\n'
      '   timeInterval: ${options.timeInterval}\n'
      '   distanceFilter: ${options.distanceFilter}\n'
      '   forceAndroidLocationManager: ${options.forceAndroidLocationManager}\n'
      '}';
}

class ErrorEvent extends LocationEvent {
  ErrorEvent(this.options, this.error, StackTrace stackTrace) : super(stackTrace);
  final Object error;
  final LocationOptions options;
  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
      'Error: {\n'
      '   message: $error\n'
      '   stackTrace: $stackTrace\n'
      '}\n'
      'Options: {\n'
      '   accuracy: ${options.accuracy}\n'
      '   timeInterval: ${options.timeInterval}\n'
      '   distanceFilter: ${options.distanceFilter}\n'
      '   forceAndroidLocationManager: ${options.forceAndroidLocationManager}\n'
      '}';
}
