import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:SarSys/features/unit/data/repositories/unit_repository_impl.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/app_config/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/features/device/data/repositories/device_repository_impl.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/incident/presentation/blocs/incident_bloc.dart';
import 'package:SarSys/features/personnel/data/repositories/personnel_repository_impl.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/incident/data/repositories/incident_repository_impl.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/app_config/data/repositories/app_config_repository_impl.dart';
import 'package:SarSys/mock/app_config.dart';
import 'package:SarSys/mock/devices.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/personnels.dart';
import 'package:SarSys/mock/trackings.dart';
import 'package:SarSys/mock/units.dart';
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/features/app_config/domain/repositories/app_config_repository.dart';
import 'package:SarSys/repositories/auth_token_repository.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/repositories/tracking_repository.dart';
import 'package:SarSys/repositories/user_repository.dart';
import 'package:SarSys/features/app_config/data/services/app_config_service.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/utils/data_utils.dart';

const MethodChannel udidChannel = MethodChannel('flutter_udid');
const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class BlocTestHarness implements BlocDelegate {
  final baseRestUrl = Defaults.baseRestUrl;
  final assetConfig = 'assets/config/app_config.json';

  ConnectivityServiceMock _connectivity;
  ConnectivityServiceMock get connectivity => _connectivity;

  bool get isWifi => connectivity.isWifi;
  bool get isOnline => connectivity.isOnline;
  bool get isOffline => connectivity.isOffline;
  bool get isCellular => connectivity.isCellular;

  BlocEventBus get bus => _bus;
  BlocEventBus _bus = BlocEventBus();

  String _username;
  String _password;
  bool _authenticated;

  UserServiceMock get userService => _userService;
  UserServiceMock _userService;

  UserBloc _userBloc;
  UserBloc get userBloc => _userBloc;
  bool _withUserBloc = false;

  AppConfigBloc _configBloc;
  AppConfigBloc get configBloc => _configBloc;
  bool _withConfigBloc = false;

  IncidentServiceMock get incidentService => _incidentService;
  IncidentServiceMock _incidentService;

  IncidentBloc _incidentBloc;
  IncidentBloc get incidentBloc => _incidentBloc;
  bool _withIncidentBloc = false;

  DeviceServiceMock get deviceService => _deviceService;
  DeviceServiceMock _deviceService;

  DeviceBloc _deviceBloc;
  DeviceBloc get deviceBloc => _deviceBloc;
  bool _withDeviceBloc = false;

  PersonnelServiceMock get personnelService => _personnelService;
  PersonnelServiceMock _personnelService;

  PersonnelBloc _personnelBloc;
  PersonnelBloc get personnelBloc => _personnelBloc;
  bool _withPersonnelBloc = false;

  UnitServiceMock get unitService => _unitService;
  UnitServiceMock _unitService;

  UnitBloc _unitBloc;
  UnitBloc get unitBloc => _unitBloc;
  bool _withUnitBloc = false;

  TrackingServiceMock get trackingService => _trackingService;
  TrackingServiceMock _trackingService;

  TrackingBloc _trackingBloc;
  TrackingBloc get trackingBloc => _trackingBloc;
  bool _withTrackingBloc = false;

  bool _waitForIncidentsLoaded = false;

  void install() {
    BlocSupervisor.delegate = this;
    setUpAll(() async {
      // Required since provider need access to service bindings prior to calling 'test()'
      _withAssets();

      // TODO: Use flutter_driver instead?
      // Mock required plugins and services
      _buildUdidPlugin();
      _buildPathPlugin();
      _buildSecureStoragePlugin();

      // Initialize shared preferences for testing
      SharedPreferences.setMockInitialValues({});

      // Delete any previous data from failed tests
      return await Storage.destroy();
    });

    setUp(() async {
      // Hive does not handle close
      // with pending writes in a
      // well-behaved manner. This
      // is a workaround that allows
      // writes to complete in previous
      // zone before old files are
      // deleted from the next zone
      // before next test is run.
      if (Storage.initialized) {
        await Storage.destroy();
      }
      await Storage.init();
      _buildConnectivity();

      if (_withConfigBloc) {
        _buildAppConfigBloc();
      }
      if (_withUserBloc) {
        await _buildUserBloc();
      }
      if (_withIncidentBloc) {
        await _buildIncidentBloc();
      }
      if (_withDeviceBloc) {
        _buildDeviceBloc();
      }
      if (_withPersonnelBloc) {
        _buildPersonnelBloc();
      }
      if (_withUnitBloc) {
        _buildUnitBloc();
      }
      if (_withTrackingBloc) {
        _buildTrackingBloc();
      }
      // Needed for await above to work
      return Future.value();
    });

    tearDown(() async {
      if (_withConfigBloc) {
        await _configBloc?.close();
      }
      if (_withUserBloc) {
        await _userBloc?.close();
      }
      if (_withIncidentBloc) {
        await _incidentBloc?.close();
      }
      if (_withDeviceBloc) {
        await _deviceBloc?.close();
      }
      if (_withPersonnelBloc) {
        await _personnelBloc?.close();
      }
      if (_withUnitBloc) {
        await _unitBloc?.close();
      }
      if (_withTrackingBloc) {
        await _trackingBloc?.close();
        _trackingService.reset();
      }
      events.clear();
      errors.clear();
      bus.unsubscribeAll();
      _connectivity?.dispose();

      if (Storage.initialized) {
        return await Storage.destroy();
      }
      return Future.value();
    });

    tearDownAll(() async {
      if (Storage.initialized) {
        await Storage.destroy();
      }
      // Needed for await above to work
      return Future.value();
    });
  }

  void withConfigBloc() {
    _withConfigBloc = true;
  }

  void withUserBloc({
    String username = 'username',
    String password = 'password',
    bool authenticated = false,
  }) {
    withConfigBloc();
    _username = username;
    _password = password;
    _withUserBloc = true;
    _authenticated = authenticated;
  }

  void withIncidentBloc({
    String username = 'username',
    String password = 'password',
    bool authenticated = true,
  }) {
    withUserBloc(
      username: username,
      password: password,
      authenticated: authenticated,
    );
    _withIncidentBloc = true;
  }

  void withDeviceBloc() {
    _withDeviceBloc = true;
    _waitForIncidentsLoaded = true;
  }

  void withPersonnelBloc() {
    _withPersonnelBloc = true;
    _waitForIncidentsLoaded = true;
  }

  void withUnitBloc() {
    _withUnitBloc = true;
    _waitForIncidentsLoaded = true;
  }

  void withTrackingBloc() {
    _withTrackingBloc = true;
    _waitForIncidentsLoaded = true;
  }

  void _buildSecureStoragePlugin() {
    final Map<String, String> storage = {};
    secureStorageChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      if ('read' == methodCall.method) {
        return storage[methodCall.arguments['key']];
      } else if ('write' == methodCall.method) {
        return storage[methodCall.arguments['key']] = methodCall.arguments['value'];
      } else if ('readAll' == methodCall.method) {
        return storage.cast<String, String>();
      } else if ('delete' == methodCall.method) {
        return storage.remove(methodCall.arguments['key']);
      } else if ('deleteAll' == methodCall.method) {
        return storage.clear();
      }
      throw 'Unkown method $methodCall';
    });
  }

  void _buildPathPlugin() {
    pathChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      return ".";
    });
  }

  void _buildUdidPlugin() {
    final udid = Uuid().v4();
    udidChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      return udid;
    });
  }

  void _withAssets() {
    // Required since provider need access to service bindings prior to calling 'test()'
    WidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) {
      // The key is the asset key.
      String key = utf8.decode(message.buffer.asUint8List());
      // Manually load the file.
      var file = File('$key');
      final Uint8List encoded = utf8.encoder.convert(file.readAsStringSync());
      return Future.value(encoded.buffer.asByteData());
    });
  }

  void _buildConnectivity() {
    _connectivity = ConnectivityServiceMock();

    when(_connectivity.isOnline).thenAnswer((_) => ConnectivityStatus.offline != _connectivity.status);
    when(_connectivity.isOffline).thenAnswer((_) => ConnectivityStatus.offline == _connectivity.status);
    when(_connectivity.isWifi).thenAnswer((_) => ConnectivityStatus.wifi == _connectivity.status);
    when(_connectivity.isCellular).thenAnswer((_) => ConnectivityStatus.cellular == _connectivity.status);

    when(_connectivity.changes).thenAnswer((_) => _connectivity._controller.stream);
    when(_connectivity.whenOnline).thenAnswer(
      (_) => _connectivity._controller.stream.where(
        (status) => ConnectivityStatus.offline != status,
      ),
    );
    when(_connectivity.whenOffline).thenAnswer(
      (_) => _connectivity._controller.stream.where(
        (status) => ConnectivityStatus.offline == status,
      ),
    );
    when(_connectivity.update()).thenAnswer((_) async => _connectivity.status);
    when(_connectivity.test()).thenAnswer((_) async => ConnectivityStatus.offline != _connectivity.status);
  }

  void _buildAppConfigBloc() {
    final AppConfigService configService = AppConfigServiceMock.build(assetConfig, '$baseRestUrl/api', null);
    final AppConfigRepository configRepo = AppConfigRepositoryImpl(
      APP_CONFIG_VERSION,
      assets: assetConfig,
      service: configService,
      connectivity: _connectivity,
    );
    _configBloc = AppConfigBloc(configRepo);
  }

  Future _buildUserBloc() async {
    assert(_withConfigBloc, 'UserBloc requires AppConfigBloc');
    _userService = UserServiceMock.build(
      UserRole.commander,
      _username,
      _password,
    );
    _userBloc = UserBloc(
      UserRepository(
        auth: AuthTokenRepository(),
        service: userService,
        connectivity: connectivity,
      ),
      configBloc,
    );

    if (_authenticated) {
      await _userBloc.login(
        username: _username,
        password: _password,
      );
      expectThroughInOrder(
        _userBloc,
        [isA<UserAuthenticated>()],
        close: false,
      );
    }
  }

  Future _buildIncidentBloc({
    UserRole role = UserRole.commander,
    String passcode = 'T123',
  }) async {
    assert(_withUserBloc, 'IncidentBloc requires UserBloc');
    _incidentService = IncidentServiceMock.build(
      _userBloc.repo,
      role: role,
      passcode: passcode,
    );
    _incidentBloc = IncidentBloc(
      IncidentRepositoryImpl(
        _incidentService,
        connectivity: _connectivity,
      ),
      bus,
      _userBloc,
    );

    await _configBloc.init();

    if (_authenticated && _waitForIncidentsLoaded) {
      // Consume IncidentsLoaded fired by UserAuthenticated
      await expectThroughInOrderLater(
        _incidentBloc,
        [isA<IncidentsLoaded>()],
        close: false,
      );
    }
  }

  void _buildDeviceBloc({
    int tetraCount = 0,
    int appCount = 0,
    bool simulate = false,
  }) {
    assert(_withIncidentBloc, 'DeviceBloc requires IncidentBloc');
    _deviceService = DeviceServiceMock.build(
      _incidentBloc,
      tetraCount: tetraCount,
      appCount: appCount,
      simulate: simulate,
    );
    _deviceBloc = DeviceBloc(
      DeviceRepositoryImpl(
        _deviceService,
        connectivity: _connectivity,
      ),
      _incidentBloc,
    );
  }

  void _buildPersonnelBloc({
    int count = 0,
  }) {
    assert(_withIncidentBloc, 'PersonnelBloc requires IncidentBloc');
    _personnelService = PersonnelServiceMock.build(count);
    _personnelBloc = PersonnelBloc(
      PersonnelRepositoryImpl(
        _personnelService,
        connectivity: _connectivity,
      ),
      bus,
      _incidentBloc,
    );
  }

  void _buildUnitBloc({
    int count = 0,
  }) {
    assert(_withIncidentBloc, 'UnitBloc requires IncidentBloc');
    assert(_withPersonnelBloc, 'UnitBloc requires PersonnelBloc');
    _unitService = UnitServiceMock.build(count);
    _unitBloc = UnitBloc(
      UnitRepositoryImpl(
        _unitService,
        connectivity: _connectivity,
      ),
      bus,
      _incidentBloc,
      _personnelBloc,
    );

    if (_authenticated) {
      // Consume PersonnelsLoaded fired by IncidentsLoaded
      expectThroughInOrder(
        _personnelBloc,
        [isA<PersonnelsEmpty>()],
        close: false,
      );
    }
  }

  void _buildTrackingBloc({
    int personnelCount = 0,
    int unitCount = 0,
  }) {
    assert(_withIncidentBloc, 'UnitBloc requires IncidentBloc');
    assert(_withDeviceBloc, 'UnitBloc requires DeviceBloc');
    assert(_withPersonnelBloc, 'UnitBloc requires PersonnelBloc');
    assert(_withUnitBloc, 'UnitBloc requires UnitBloc');
    _trackingService = TrackingServiceMock.build(
      _deviceService,
      personnelCount: personnelCount,
      unitCount: unitCount,
    );
    _trackingBloc = TrackingBloc(
      TrackingRepository(
        _trackingService,
        connectivity: _connectivity,
      ),
      incidentBloc: _incidentBloc,
      deviceBloc: _deviceBloc,
      personnelBloc: _personnelBloc,
      unitBloc: _unitBloc,
    );

    if (_authenticated) {
      // Consume PersonnelsLoaded fired by IncidentsLoaded
      expectThroughInOrder(
        _unitBloc,
        [isA<UnitsEmpty>()],
        close: false,
      );
    }
  }

  final errors = <Bloc, List<Object>>{};

  @override
  void onError(Bloc bloc, Object error, StackTrace stacktrace) {
    errors.update(bloc, (errors) => errors..add(error), ifAbsent: () => [error]);
  }

  final events = <Bloc, List<Object>>{};

  @override
  void onEvent(Bloc bloc, Object event) {
    events.update(bloc, (events) => events..add(event), ifAbsent: () => [event]);
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    // TODO: implement onTransition
  }
}

class BlocEventBusMock extends Mock implements BlocEventBus {}

class ConnectivityServiceMock extends Mock implements ConnectivityService {
  ConnectivityServiceMock({ConnectivityStatus status = ConnectivityStatus.cellular}) : _status = status;

  StreamController<ConnectivityStatus> _controller = StreamController.broadcast();
  ConnectivityStatus _status = ConnectivityStatus.offline;

  @override
  ConnectivityStatus get status => _status;

  ConnectivityStatus wifi() => _change(ConnectivityStatus.wifi);
  ConnectivityStatus offline() => _change(ConnectivityStatus.offline);
  ConnectivityStatus cellular() => _change(ConnectivityStatus.cellular);

  ConnectivityStatus _change(ConnectivityStatus next) {
    final previous = _status;
    _status = next;
    _controller.add(next);
    return previous;
  }

  void dispose() {
    _controller.close();
  }
}

Future<void> expectExactlyLater<B extends Bloc<dynamic, State>, State>(
  B bloc,
  Iterable expected, {
  Duration duration,
  int skip = 0,
  bool close = false,
}) async {
  assert(bloc != null);
  final states = <State>[];
  final subscription = bloc.skip(skip).listen(states.add);
  if (duration != null) await Future.delayed(duration);
  if (close) {
    await bloc.close();
  }
  expect(states, expected);
  await subscription.cancel();
}

void expectThrough<B extends Bloc<dynamic, State>, State>(
  B bloc,
  expected, {
  bool close = false,
}) {
  assert(bloc != null);
  assert(expected != null);
  expect(bloc, emitsThrough(expected));
  if (close) {
    bloc.close();
  }
}

void expectThroughInOrder<B extends Bloc<dynamic, State>, State>(
  B bloc,
  Iterable expected, {
  bool close = false,
}) {
  assert(bloc != null);
  assert(expected != null);
  expect(bloc, emitsThrough(emitsInOrder(expected)));
  if (close) {
    bloc.close();
  }
}

Future<void> expectThroughLater<B extends Bloc<dynamic, State>, State>(
  B bloc,
  expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  assert(expected != null);
  await expectLater(bloc, emitsThrough(expected));
  if (close) {
    bloc.close();
  }
}

Future<void> expectThroughInOrderLater<B extends Bloc<dynamic, State>, State>(
  B bloc,
  Iterable expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  assert(expected != null);
  await expectLater(bloc, emitsThrough(emitsInOrder(expected)));
  if (close) {
    await bloc.close();
  }
}

Stream<StorageStatus> toStatusChanges(Stream<StorageTransition> changes) =>
    changes.where((state) => state.to.isRemote).map((state) => state.to.status);

void expectStorageStatus(
  StorageState actual,
  StorageStatus expected, {
  @required bool remote,
}) {
  expect(
    actual.status,
    equals(expected),
    reason: "SHOULD HAVE status ${enumName(expected)}",
  );
  expect(
    actual.isRemote,
    remote ? isTrue : isFalse,
    reason: "SHOULD HAVE ${remote ? 'remote' : 'local'} origin",
  );
}
