import 'package:SarSys/core/data/services/location/background_geolocation_service.dart';
import 'package:SarSys/core/domain/models/Position.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/core/domain/models/Point.dart';
import 'package:SarSys/core/utils/data.dart' as utils;
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong/latlong.dart';
import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

abstract class LocationService {
  /// Get [Device.uuid] being tracked
  String get duuid;

  /// Check if service is able to store
  /// positions locally. Storing is only
  /// possible if user has enabled it with
  /// [AppConfig.locationStoreLocally].
  bool get canStore;

  /// Check if positions are stored locally.
  /// Storing is controlled with [configure]
  /// using parameter [store]. Storing is
  /// only possible if [canStore] is [true].
  bool get isStoring;

  /// Check if service is able to share
  /// positions for given [duuid]. Sharing is
  /// only possible if both [duuid] and
  /// [token] is given, and user has enabled
  /// it with [AppConfig.locationAllowSharing].
  bool get canShare;

  /// Check if sharing is requested.
  bool get share;

  /// Check if positions stored locally are
  /// shared by posting to backend using id
  /// [duuid]. Storing is only possible
  /// if [canShare] is [true].
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

  /// Get backlog of positions stored on this device pending push to backend
  Future<Iterable<Position>> backlog();

  /// Clear all positions stored on this device
  Future clear();

  /// Get authentication token required
  /// to publish positions to backend
  AuthToken get token;
  set token(AuthToken token);

  /// Get event from index
  LocationEvent operator [](int index);

  /// Configure location service from
  /// [configBloc.config] and given params.
  ///
  /// Use [duuid] to change which id positions are publish with
  /// Use [token] to change which authorisation token to publish positions with
  /// Use [share] to control pushing positions with id [duuid]
  /// Use [debug] to enable debugging
  /// Use [force] to force reconfiguration of service
  Future<PermissionStatus> configure({
    bool share,
    String duuid,
    AuthToken token,
    bool debug = false,
    bool force = false,
  });

  /// Request location update manually.
  Future<Position> update();

  /// Push buffered positions to backend.
  /// Returns number of positions pushed.
  Future<int> push();

  /// Check if service is disposed.
  /// If disposed, it can not be
  /// used anymore and [LocationService]
  /// must be created one more.
  bool get disposed;

  /// Dispose service.
  /// If disposed, it can not be
  /// used anymore and a new
  /// [LocationService] must
  /// be created again.
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
      case LocationAccuracy.navigation:
        return "Navigasjon";
      default:
        return "Høy";
    }
  }

  static LocationService _singleton;
  static LocationService get instance => _singleton;
  static bool get exists => _singleton?.disposed == false;

  factory LocationService({
    String duuid,
    String token,
    AppConfigBloc configBloc,
  }) {
    if (!exists) {
      _singleton = BackgroundGeolocationService(
        share: _singleton?.share,
        duuid: duuid ?? _singleton?.duuid,
        token: token ?? _singleton?.token,
        configBloc: configBloc ?? _singleton?.configBloc,
      );
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
  navigation,
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
    this.debug = false,
    this.timeInterval = 0,
    this.distanceFilter = 0,
    this.locationAlways,
    this.locationWhenInUse,
    this.activityRecognition,
    this.locationStoreLocally,
    this.locationAllowSharing,
    this.accuracy = LocationAccuracy.best,
    this.forceAndroidLocationManager,
  });

  /// Tells service to enter debug mode
  ///
  final bool debug;

  /// Tells service to track location also when app is terminated by OS
  ///
  final bool locationAlways;

  /// Tells service to track location only when app is in use
  ///
  final bool locationWhenInUse;

  /// Tells service to use activity recognition service to optimize location tracking
  ///
  final bool activityRecognition;

  /// Tells service to store positions locally in backlog
  ///
  /// The default value for this field is [Defaults.locationStoreLocally].
  final bool locationStoreLocally;

  /// Tells service to push positions in backlog to backend
  ///
  /// The default value for this field is [Defaults.locationAllowSharing].
  final bool locationAllowSharing;

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

  @override
  String toString() => 'Options: {\n'
      '   debug: $debug\n'
      '   accuracy: $accuracy\n'
      '   timeInterval: $timeInterval\n'
      '   distanceFilter: $distanceFilter\n'
      '   locationAlways: $locationAlways\n'
      '   locationWhenInUse: $locationWhenInUse\n'
      '   activityRecognition: $activityRecognition\n'
      '   locationStoreLocally: $locationStoreLocally\n'
      '   locationAllowSharing: $locationAllowSharing\n'
      '   forceAndroidLocationManager: $forceAndroidLocationManager\n'
      '}';
}

abstract class LocationEvent {
  LocationEvent(this.stackTrace);
  final StackTrace stackTrace;
  final DateTime timestamp = DateTime.now();
}

class CreateEvent extends LocationEvent {
  CreateEvent(
    this.duuid,
    this.config,
  ) : super(StackTrace.current);
  final String duuid;
  final AppConfig config;

  @override
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()},\n'
      'Device: {uuid: $duuid},'
      'AppConfig: {\n'
      '   store: ${config.locationStoreLocally}\n'
      '   accuracy: ${config.locationAccuracy}\n'
      '   interval: ${config.locationFastestInterval}\n'
      '   displacement: ${config.locationSmallestDisplacement}\n'
      '   locationAlways: ${config.locationAlways}\n'
      '   locationWhenInUse: ${config.locationWhenInUse}\n'
      '   activityRecognition: ${config.activityRecognition}\n'
      '}';
}

class ConfigureEvent extends LocationEvent {
  ConfigureEvent(
    this.duuid,
    this.config,
    this.options,
  ) : super(StackTrace.current);
  final String duuid;
  final AppConfig config;
  final LocationOptions options;

  @override
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()},\n'
      'Device: {uuid: $duuid},'
      'AppConfig: {\n'
      '   store: ${config.locationStoreLocally}\n'
      '   accuracy: ${config.locationAccuracy}\n'
      '   interval: ${config.locationFastestInterval}\n'
      '   displacement: ${config.locationSmallestDisplacement}\n'
      '   locationAlways: ${config.locationAlways}\n'
      '   locationWhenInUse: ${config.locationWhenInUse}\n'
      '   activityRecognition: ${config.activityRecognition}\n'
      '},\n'
      '$options';
}

class PositionEvent extends LocationEvent {
  PositionEvent(this.position, {this.historic = false}) : super(StackTrace.current);
  final Position position;
  final bool historic;

  @override
  String toString() {
    return '$runtimeType\n'
        'When: ${timestamp.toIso8601String()},\n'
        'Historic: $historic,\n'
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
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()},\n'
      '$options';
}

class UnsubscribeEvent extends LocationEvent {
  UnsubscribeEvent(this.options) : super(StackTrace.current);
  final LocationOptions options;
  @override
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()},\n'
      '$options';
}

class MoveEvent extends LocationEvent {
  final bool isMoving;
  final Position position;

  MoveEvent(this.position, this.isMoving) : super(StackTrace.current);

  @override
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()},\n'
      'IsMoving: $isMoving,\n'
      'Position: $position';
}

class PushEvent extends LocationEvent {
  final Iterable<Position> positions;

  PushEvent(this.positions) : super(StackTrace.current);

  @override
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()},\n'
      'Positions: $positions';
}

class HttpServiceEvent extends LocationEvent {
  HttpServiceEvent(this.options, this.status, this.reason) : super(null);
  final int status;
  final String reason;
  final LocationOptions options;
  @override
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()}\n'
      'HttpServiceEvent: {\n'
      '   status: $status\n'
      '   reason: $reason\n'
      '},\n'
      '$options';
}

class ClearEvent extends LocationEvent {
  final Position position;

  ClearEvent(this.position) : super(StackTrace.current);

  @override
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()}';
}

class ErrorEvent extends LocationEvent {
  ErrorEvent(this.options, this.error, StackTrace stackTrace) : super(stackTrace);
  final Object error;
  final LocationOptions options;
  @override
  String toString() => '$runtimeType\n'
      'When: ${timestamp.toIso8601String()}\n'
      'Error: {\n'
      '   message: $error\n'
      '   stackTrace: $stackTrace\n'
      '},\n'
      '$options';
}
