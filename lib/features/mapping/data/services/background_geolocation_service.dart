

import 'dart:async';
import 'dart:io';

import 'package:SarSys/core/data/streams.dart';
import 'package:SarSys/core/error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';

import 'location_service.dart';

class BackgroundGeolocationService implements LocationService {
  BackgroundGeolocationService({
    required LocationOptions options,
    String? duuid,
    AuthToken? token,
    bool? share = false,
    bool locationDebug = false,
    this.maxEvents = 100,
  }) {
    assert(options != null, "options are required");
    _duuid = duuid;
    _token = token;
    _options = options;
    _share = share ?? false;
    _events.insert(0, CreateEvent(duuid: duuid, share: _share, maxEvents: maxEvents));
  }

  final int maxEvents;
  static List<Position?> _positions = [];
  static List<LocationEvent> _events = [];

  @override
  LocationOptions? get options => _options;
  LocationOptions? _options;

  @override
  String? get duuid => _duuid;
  String? _duuid;

  @override
  bool get canStore => (_options?.locationStoreLocally ?? Defaults.locationStoreLocally);

  @override
  bool get isStoring => isReady && canStore;

  @override
  bool get canShare =>
      _duuid != null && _token != null && (_options?.locationAllowSharing ?? Defaults.locationAllowSharing);

  @override
  bool get share => _share;
  bool _share = true;

  @override
  bool get isSharing => _share && canShare;

  @override
  Activity get activity => _current?.activity ?? Activity.unknown;

  @override
  Iterable<Position?> get positions => _positions;

  @override
  double get odometer => _odometer;
  double _odometer = 0;

  @override
  Future<PermissionStatus> get status async {
    _status = await Permission.location.status;
    return _status;
  }

  PermissionStatus _status = PermissionStatus.denied;

  StreamController<Position?>? _positionController = StreamController.broadcast();
  StreamController<LocationEvent>? _eventController = StreamController.broadcast();

  @override
  Position? get current => _current;
  Position? _current;

  @override
  bool get isReady => _state?.enabled ?? false;
  bg.State? _state;

  @override
  Stream<Position?> get stream => _positionController!.stream;

  @override
  Stream<LocationEvent> get onEvent => _eventController!.stream;

  @override
  Iterable<LocationEvent> get events => List.unmodifiable(_events);

  @override
  LocationEvent operator [](int index) => _events[index];

  @override
  AuthToken? get token => _token;
  AuthToken? _token;

  final _queue = StreamRequestQueue<String, LocationOptions>();

  bool _isSubscribed = false;

  void _subscribe() {
    if (!_isSubscribed) {
      _isSubscribed = true;
      // Process heartbeat events
      bg.BackgroundGeolocation.onHeartbeat(_onHeartbeat);

      // Process for location, motion and activity changes
      bg.BackgroundGeolocation.onMotionChange(_onMoveChange);
      bg.BackgroundGeolocation.onLocation(_onLocation, _onError);
      bg.BackgroundGeolocation.onProviderChange(_onProviderChange);
      bg.BackgroundGeolocation.onActivityChange(_onActivityChange);

      // Process http service events
      bg.BackgroundGeolocation.onHttp(_onHttp);

      // Process authorization events
      bg.BackgroundGeolocation.onAuthorization(_onAuthorization);

      _notify(
        SubscribeEvent(_options),
      );
    }
  }

  @override
  Future<Iterable<Position>> backlog() async {
    final locations = await bg.BackgroundGeolocation.locations;
    return locations.map(_fromJson).toList();
  }

  Position _fromJson(json) => Position.fromJson(Map<String, dynamic>.from(json));

  @override
  Future clear() async {
    _events.clear();
    _positions.clear();
    await bg.BackgroundGeolocation.destroyLocations();
    _notify(ClearEvent(current));
  }

  @override
  Future<LocationOptions?> configure({
    bool? share,
    bool? debug,
    String? duuid,
    AuthToken? token,
    bool force = false,
    LocationOptions? options,
  }) async {
    _status = await Permission.location.status;
    if (_status != PermissionStatus.granted) {
      return _options;
    }

    final completer = Completer<LocationOptions>();
    try {
      final wasSharing = isSharing;
      final shouldForce = (force || !isReady);
      final shouldConfigure = shouldForce ||
          _isConfigChanged(
            duuid: duuid,
            token: token,
            debug: debug,
            share: share,
            options: options ?? _options,
          );
      if (shouldConfigure) {
        // NO bg api methods MUST BE
        // called before subscriptions
        // are registered.
        _subscribe();

        // Ensure debug flag is updated if given
        _options = (options ?? _options)!.copyWith(
          debug: debug ?? _options!.debug,
        );
        final config = _toConfig(
          duuid: duuid,
          token: token,
          share: share,
        );

        // Prevents concurrent configure
        _queue.only(StreamRequest<String, LocationOptions>(execute: () async {
          // Wait for previous to complete or check plugin
          _state = await bg.BackgroundGeolocation.state;
          if (isReady) {
            bg.BackgroundGeolocation.setConfig(config).then(
              (_) => _onConfigured(completer, wasSharing),
            );
          } else {
            bg.BackgroundGeolocation.ready(config).then(
              (_) => _onConfigured(completer, wasSharing),
            );
          }
          return StreamResult(
            value: await completer.future,
          );
        }));
      } else {
        completer.complete(_options);
      }
    } catch (e, stackTrace) {
      _notify(
        ErrorEvent(_options, e, stackTrace),
      );
      completer.completeError(
        "Failed to configure BackgroundLocation: $e",
        stackTrace,
      );
    }
    return completer.future;
  }

  static const skipped = ['499', '408'];

  Future<void> _onConfigured(Completer<LocationOptions> completer, bool wasSharing) async {
    // Set current state
    _state = await bg.BackgroundGeolocation.state;

    if (!isReady) {
      _state = await bg.BackgroundGeolocation.start();
      try {
        _current = _toPosition(
          await bg.BackgroundGeolocation.setOdometer(_odometer),
        );
      } on PlatformException catch (e) {
        if (!skipped.contains(e.code)) {
          rethrow;
        }
      }
    }

    if (isReady) {
      await update();

      // Only set once
      _positions ??= await (backlog() as FutureOr<List<Position?>>);

      _notify(ConfigureEvent(
        _duuid,
        _options,
      ));

      if (!completer.isCompleted) {
        completer.complete(_options);
      }

      if (!wasSharing && isSharing) {
        await push();
      }
    }
  }

  bg.Config _toConfig({
    bool? share,
    String? duuid,
    AuthToken? token,
  }) {
    _duuid = duuid ?? _duuid;
    _token = token ?? _token;
    _share = share ?? _share;
    debugPrint(
      '_toConfig{\n'
      '  bg.url: ${_toUrl()}\n'
      '}',
    );
    return bg.Config(
      reset: true,
      debug: _debug,
      url: _toUrl(),
      method: 'POST',
      batchSync: true,
      maxBatchSize: 10,
      autoSync: isSharing,
      autoSyncThreshold: 5,
      startOnBoot: isSharing,
      logMaxDays: 3,
      logLevel: _logLevel,
      stopOnTerminate: !isSharing,
      maxDaysToPersist: 3,
      maxRecordsToPersist: 1000,
      persistMode: _persistMode,
      httpRootProperty: '.',
      httpTimeout: 60000,
      heartbeatInterval: 60,
      preventSuspend: isSharing,
      authorization: _toAuthorization(),
      locationTemplate: locationTemplate,
      showsBackgroundLocationIndicator: true,
      // We handle permissions our self
      disableLocationAuthorizationAlert: true,
      locationUpdateInterval: _options!.timeInterval,
      desiredAccuracy: _toAccuracy(_options!.accuracy),
      distanceFilter: _options!.distanceFilter.toDouble(),
      fastestLocationUpdateInterval: _options!.timeInterval,
      disableMotionActivityUpdates: !_options!.activityRecognition,
      notification: bg.Notification(
        sticky: true,
        title: "SARSys",
        text: "Sporing er ${isSharing ? 'aktiv' : 'inaktiv'}",
      ),
    );
  }

  bool get _debug => (_options?.debug ?? kDebugMode);

  String? _toUrl({bool override = false}) =>
      override || isSharing ? '${Defaults.baseRestUrl}/devices/$_duuid/positions' : null;

  bg.Authorization? _toAuthorization() {
    return _token != null
        ? bg.Authorization(
            accessToken: _token!.accessToken,
            refreshToken: _token!.refreshToken,
            refreshUrl: UserIdentityService.REFRESH_URL,
            refreshPayload: {
                'client_id': _token!.clientId,
                'grant_type': 'refresh_token',
                'refresh_token': '{refreshToken}',
              })
        : null;
  }

  int get _persistMode => canStore ? bg.Config.PERSIST_MODE_LOCATION : bg.Config.PERSIST_MODE_NONE;
  int get _logLevel => Defaults.debugPrintLocation
      ? ((_options?.debug ?? kDebugMode) ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_INFO)
      : bg.Config.LOG_LEVEL_OFF;

  int _toAccuracy(LocationAccuracy? accuracy) {
    switch (accuracy) {
      case LocationAccuracy.lowest:
        return bg.Config.DESIRED_ACCURACY_LOWEST;
      case LocationAccuracy.low:
        return bg.Config.DESIRED_ACCURACY_LOW;
      case LocationAccuracy.medium:
        return bg.Config.DESIRED_ACCURACY_MEDIUM;
      case LocationAccuracy.high:
        return bg.Config.DESIRED_ACCURACY_HIGH;
      case LocationAccuracy.best:
        return bg.Config.DESIRED_ACCURACY_HIGH;
      case LocationAccuracy.navigation:
        return bg.Config.DESIRED_ACCURACY_NAVIGATION;
      case LocationAccuracy.automatic:
      default:
        return bg.Config.DESIRED_ACCURACY_HIGH;
    }
  }

  @override
  Future<Position?> update() async {
    if (isReady) {
      try {
        final state = await bg.BackgroundGeolocation.state;
        if (state.isMoving!) {
          await bg.BackgroundGeolocation.getCurrentPosition();
        } else {
          await bg.BackgroundGeolocation.changePace(true);
        }
      } catch (e, stackTrace) {
        _notify(
          ErrorEvent(_options, e, stackTrace),
        );
        SarSysApp.reportCheckedError(
          "Failed to get position with error: $e",
          StackTrace.current,
        );
      }
    }
    return _current;
  }

  @override
  Future<int> push() async {
    final pushed = [];
    if (isReady) {
      try {
        pushed.addAll(await bg.BackgroundGeolocation.sync());
        _notify(PushEvent(pushed.map(_fromJson)));
      } catch (e, stackTrace) {
        _notify(
          ErrorEvent(_options, e, stackTrace),
        );
        if (_shouldReport(e)) {
          SarSysApp.reportCheckedError(
            "Failed to push backlog error: $e",
            StackTrace.current,
          );
        }
      }
    }
    return pushed.length;
  }

  bool _shouldReport(Object e) {
    return !(e is PlatformException &&
        !const [
          'timeout',
          'HTTPService is busy',
        ].contains('${e.message}'));
  }

  @override
  bool get disposed => _disposed;
  bool _disposed = false;

  @override
  Future dispose() async {
    if (!_disposed) {
      _disposed = true;
      _notify(UnsubscribeEvent(
        _options,
      ));
      if (isReady) {
        _state = await bg.BackgroundGeolocation.stop();
      }
      await bg.BackgroundGeolocation.removeListeners();
      await _eventController!.close();
      await _positionController!.close();
      _eventController = null;
      _positionController = null;
    }
    return Future.value();
  }

  bool _isDeviceChanged(String? duuid) => duuid != null && duuid != _duuid;
  bool _isTokenChanged(AuthToken? token) => token != null && token != _token;
  bool _isSharingStateChanged(bool? share) => share != null && share != _share;

  bool _isConfigChanged({
    bool? share,
    bool? debug,
    String? duuid,
    AuthToken? token,
    LocationOptions? options,
  }) {
    return _options?.debug != (debug ?? options!.debug ?? kDebugMode) ||
        _options?.accuracy != options!.accuracy ||
        _options?.locationAlways != (options.locationAlways ?? false) ||
        _options?.locationWhenInUse != (options.locationWhenInUse ?? false) ||
        _options?.activityRecognition != (options.activityRecognition ?? false) ||
        _options?.timeInterval != (options.timeInterval ?? Defaults.locationFastestInterval) ||
        _options?.distanceFilter != (options.distanceFilter ?? Defaults.locationSmallestDisplacement) ||
        _options?.locationStoreLocally != (options.locationStoreLocally ?? Defaults.locationStoreLocally) ||
        _options?.locationAllowSharing != (options.locationAllowSharing ?? Defaults.locationAllowSharing) ||
        _isTokenChanged(token) ||
        _isDeviceChanged(duuid) ||
        _isSharingStateChanged(share);
  }

  void _onHeartbeat(bg.HeartbeatEvent event) {
    if (!_disposed) {
      final location = event.location!;
      _odometer = location.odometer;
      _current = _toPosition(location);
      _positionController!.add(_current);
      _notify(PositionEvent(
        _current,
        heartbeat: true,
      ));
    }
  }

  void _onLocation(bg.Location location) {
    if (!_disposed) {
      _odometer = location.odometer;
      _current = _toPosition(location);
      _positionController!.add(_current);
      _notify(PositionEvent(
        _current,
        sample: location.sample,
      ));
    }
  }

  void _onMoveChange(bg.Location location) {
    if (!_disposed) {
      _odometer = location.odometer;
      _current = _toPosition(location);
      _positionController!.add(_current);
      _notify(
        MoveChangeEvent(
          _toPosition(location),
        ),
      );
    }
  }

  static const AUTHORIZATION_STATUS = {
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS: 'AUTHORIZATION_STATUS_ALWAYS',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED: 'AUTHORIZATION_STATUS_DENIED',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_RESTRICTED: 'AUTHORIZATION_STATUS_RESTRICTED',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE: 'AUTHORIZATION_STATUS_WHEN_IN_USE',
    bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED: 'AUTHORIZATION_STATUS_NOT_DETERMINED',
  };

  void _onProviderChange(bg.ProviderChangeEvent event) {
    if (!_disposed) {
      _notify(
        ProviderChangeEvent(
          gps: event.gps,
          enabled: event.enabled,
          network: event.network,
          status: AUTHORIZATION_STATUS[event.status],
        ),
      );
    }
  }

  void _onActivityChange(bg.ActivityChangeEvent event) {
    if (!_disposed) {
      _current = _current?.copyWith(
        activity: Activity.fromJson(event.toMap()),
      );
      _notify(
        ActivityChangeEvent(_current),
      );
    }
  }

  void _onHttp(event) {
    if (!_disposed) {
      _notify(
        HttpServiceEvent(
          _toUrl(override: true),
          _options,
          event.status,
          event.responseText,
        ),
      );
      // Retry later on conflict
      if (event.status == HttpStatus.conflict) {
        Future.delayed(
          const Duration(milliseconds: 500),
          () => push(),
        );
      }
    }
  }

  void _onAuthorization(bg.AuthorizationEvent event) {
    if (!_disposed) {
      if (event.success) {
        _token = AuthToken(
          idToken: _token!.idToken,
          clientId: _token!.clientId,
          accessToken: event.response!['access_token'],
          refreshToken: event.response!['refresh_token'],
          accessTokenExpiration: DateTime.now()
            ..add(
              Duration(seconds: event.response!['expires_in'] ?? 300),
            ),
        );
        _notify(
          HttpServiceEvent(
            UserIdentityService.REFRESH_URL,
            _options,
            200,
            '{$event.response}',
          ),
        );
      } else {
        _notify(
          HttpServiceEvent(
            UserIdentityService.REFRESH_URL,
            _options,
            401,
            event.error,
          ),
        );
      }
    }
  }

  void _notify(LocationEvent event) {
    if ((_events?.length ?? 0) > maxEvents) {
      _events.removeLast();
    }
    _events.insert(0, event);
    if (event is PositionEvent && !(event.sample! || event.heartbeat)) {
      _positions.add(event.position);
    }
    _eventController!.add(event);
  }

  Position _toPosition(bg.Location location) => Position.timestamp(
        isMoving: location.isMoving,
        speed: location.coords.speed,
        lat: location.coords.latitude,
        lon: location.coords.longitude,
        alt: location.coords.altitude,
        acc: location.coords.accuracy,
        source: PositionSource.device,
        bearing: location.coords.heading,
        activity: Activity.fromJson({
          'type': location.activity.type,
          'confidence': location.activity.confidence,
        }),
        timestamp: DateTime.tryParse(location.timestamp) ?? DateTime.now(),
      );

  void _onError(bg.LocationError error) {
    final stackTrace = StackTrace.current;
    _notify(ErrorEvent(_options, error, stackTrace));
    SarSysApp.reportCheckedError(
      "Location stream failed with error: $error",
      stackTrace,
    );
  }

  static String locationTemplate = '{'
      '"type": "Feature",'
      '"geometry": {"type": "Point", "coordinates": [<%= longitude %>, <%= latitude %>, <%= altitude %>]},'
      '"properties": {'
      '"source": "device",'
      '"speed": <%= speed %>,'
      '"bearing": <%= heading %>,'
      '"accuracy": <%= accuracy %>,'
      '"isMoving": <%= is_moving %>,'
      '"timestamp": "<%= timestamp %>",'
      '"activity": {"type": "<%= activity.type %>", "confidence": <%= activity.confidence %>}'
      '}}';

  /// Send log to given [address]
  static void emailLog(String address) {
    bg.Logger.emailLog(address).catchError(SarSysApp.reportCheckedError);
  }
}
