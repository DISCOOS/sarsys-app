import 'dart:async';

import 'package:SarSys/core/domain/models/Position.dart';
import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:catcher/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:permission_handler/permission_handler.dart';

import 'location_service.dart';

class GeolocatorService implements LocationService {
  GeolocatorService({
    @required LocationOptions options,
    this.duuid,
    this.maxEvents = 100,
  }) {
    assert(options != null, "options are required");
    _options = options;
    _events.insert(0, CreateEvent(duuid: duuid, share: false, maxEvents: maxEvents));
  }

  final int maxEvents;
  static List<Position> _positions = [];
  static List<LocationEvent> _events = [];

  gl.Geolocator _geolocator;
  PermissionStatus _status = PermissionStatus.undetermined;

  Stream<Position> _internalStream;
  StreamSubscription _configSubscription;
  StreamSubscription _locatorSubscription;
  StreamController<Position> _positionController = StreamController.broadcast();
  StreamController<LocationEvent> _eventController = StreamController.broadcast();

  @override
  AuthToken token;

  @override
  final String duuid;

  @override
  final double odometer = 0;

  @override
  LocationOptions get options => _options;
  LocationOptions _options;

  @override
  bool get canStore => false;

  @override
  final bool isStoring = false;

  @override
  bool get share => false;

  @override
  bool get canShare => false;

  @override
  final bool isSharing = false;

  @override
  Position get current => _current;
  Position _current;

  @override
  Activity get activity => Activity.unknown;

  @override
  PermissionStatus get status => _status;

  @override
  ValueNotifier<bool> get isReady => _isReady;
  final _isReady = ValueNotifier(false);

  @override
  Stream<Position> get stream => _positionController.stream;

  @override
  Stream<LocationEvent> get onChanged => _eventController.stream;

  @override
  Iterable<LocationEvent> get events => List.unmodifiable(_events);

  @override
  Iterable<Position> get positions => events.whereType<PositionEvent>().map((e) => e.position);

  @override
  LocationEvent operator [](int index) => _events[index];

  @override
  Future<Iterable<Position>> backlog() async {
    return positions;
  }

  @override
  Future<int> push() {
    throw UnimplementedError('Push not implemented');
  }

  @override
  Future clear() async {
    _events.clear();
    _positions.clear();
    _notify(ClearEvent(current));
  }

  @override
  Future<PermissionStatus> configure({
    bool share,
    String duuid,
    AuthToken token,
    bool debug = false,
    bool force = false,
    LocationOptions options,
  }) async {
    _status = await Permission.locationWhenInUse.status;
    if ([PermissionStatus.granted].contains(_status)) {
      if (force || _isConfigChanged(_options)) {
        _notify(
          ConfigureEvent(duuid, _options),
        );
        _subscribe(_options);
      }
    } else {
      await dispose();
    }
    return _status;
  }

  @override
  Future<Position> update() async {
    if (_isReady.value) {
      try {
        final last = _current;
        _current = _toPosition(
          await _geolocator.getLastKnownPosition(
            desiredAccuracy: _toAccuracy(_options.accuracy),
          ),
        );
        if (_current == null) {
          _current = _toPosition(
            await _geolocator.getCurrentPosition(
              desiredAccuracy: _toAccuracy(_options.accuracy),
            ),
          );
        }
        if (last != _current) {
          _positionController.add(_current);
          _notify(PositionEvent(_current));
        }
      } on Exception catch (e, stackTrace) {
        _notify(ErrorEvent(_options, e, stackTrace));
        _unsubscribe();
        Catcher.reportCheckedError("Failed to get position with error: $e", StackTrace.current);
      }
    } else {
      await configure();
    }
    return _current;
  }

  void _notify(LocationEvent event) {
    if ((_events?.length ?? 0) > maxEvents) {
      _events.removeLast();
    }
    _events.insert(0, event);
    if (event is PositionEvent) {
      _positions.add(event.position);
    }
    _eventController.add(event);
    _eventController.add(event);
  }

  static gl.LocationAccuracy _toAccuracy(LocationAccuracy value) {
    switch (value) {
      case LocationAccuracy.lowest:
        return gl.LocationAccuracy.lowest;
      case LocationAccuracy.low:
        return gl.LocationAccuracy.low;
      case LocationAccuracy.medium:
        return gl.LocationAccuracy.medium;
      case LocationAccuracy.high:
        return gl.LocationAccuracy.high;
      case LocationAccuracy.best:
        return gl.LocationAccuracy.best;
      case LocationAccuracy.navigation:
        return gl.LocationAccuracy.bestForNavigation;
      default:
        return gl.LocationAccuracy.best;
    }
  }

  void _subscribe(LocationOptions options) async {
    if (_internalStream != null) _unsubscribe();
    _options = options;
    _internalStream = _geolocator
        .getPositionStream(gl.LocationOptions(
          accuracy: _toAccuracy(options.accuracy),
          distanceFilter: options.distanceFilter,
          timeInterval: options.timeInterval,
          forceAndroidLocationManager: options.forceAndroidLocationManager,
        ))
        .map(_toPosition);
    _locatorSubscription = _internalStream.listen((Position position) {
      _current = position;
      _positionController.add(position);
      _notify(PositionEvent(position));
    });
    _locatorSubscription.onDone(_unsubscribe);
    _locatorSubscription.onError(_handleError);
    _notify(SubscribeEvent(options));
    _isReady.value = true;
    await update();
  }

  @override
  bool get disposed => _disposed;
  bool _disposed = false;

  @override
  Future dispose() async {
    if (!_disposed) {
      await _eventController.close();
      await _positionController.close();
      await _configSubscription?.cancel();
      _eventController = null;
      _positionController = null;
      _configSubscription = null;
      _unsubscribe();
      _disposed = true;
    }
    return Future.value();
  }

  void _unsubscribe() {
    _internalStream = null;
    _locatorSubscription?.cancel();
    _locatorSubscription = null;
    _isReady.value = false;
    _notify(UnsubscribeEvent(_options));
  }

  bool _isConfigChanged(LocationOptions options) {
    return _options?.accuracy != options.accuracy ||
        _options?.timeInterval != options.timeInterval ||
        _options?.distanceFilter != options.distanceFilter;
  }

  _handleError(dynamic error, StackTrace stackTrace) {
    _unsubscribe();
    _notify(ErrorEvent(_options, error, stackTrace));
    Catcher.reportCheckedError(
      "Location stream failed with error: $error",
      stackTrace,
    );
  }

  Position _toPosition(gl.Position position) => Position.timestamp(
        lat: position.latitude,
        lon: position.longitude,
        alt: position.altitude,
        acc: position.accuracy,
        speed: position.speed,
        bearing: position.heading,
        timestamp: position.timestamp,
        source: PositionSource.device,
      );
}
