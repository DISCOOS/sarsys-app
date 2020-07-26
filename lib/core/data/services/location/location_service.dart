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
  Position get current;

  PermissionStatus get status;

  ValueNotifier<bool> get isReady;

  Stream<Position> get stream;

  Stream<LocationEvent> get onChanged;

  Iterable<LocationEvent> get events;

  LocationEvent operator [](int index);

  Future<PermissionStatus> configure({bool force = false});

  Future<Position> update();

  bool get disposed;

  Future dispose();

  static LatLng toLatLng(Position position) => position == null ? Defaults.origo : LatLng(position?.lat, position?.lon);

  static Point toPoint(Position position) => utils.toPoint(toLatLng(position));

  static toAccuracyName(LocationAccuracy value) {
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
    }
  }

  static LocationService _singleton;

  factory LocationService([AppConfigBloc bloc]) {
    if (_singleton == null || _singleton.disposed) {
      _singleton = BackgroundGeolocationService(bloc);
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
  CreateEvent(this.config) : super(StackTrace.current);
  final AppConfig config;

  @override
  String toString() => 'When: ${timestamp.toIso8601String()}\n'
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
