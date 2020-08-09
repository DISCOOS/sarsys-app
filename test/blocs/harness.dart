import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/features/affiliation/data/repositories/affiliation_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/department_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/division_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/organisation_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/person_repository_impl.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:SarSys/features/operation/data/repositories/operation_repository_impl.dart';
import 'package:SarSys/features/unit/data/repositories/unit_repository_impl.dart';
import 'package:SarSys/mock/affiliation_service_mock.dart';
import 'package:SarSys/mock/department_service_mock.dart';
import 'package:SarSys/mock/division_service_mock.dart';
import 'package:SarSys/mock/operation_service_mock.dart';
import 'package:SarSys/mock/organisation_service_mock.dart';
import 'package:SarSys/mock/person_service_mock.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/device/data/repositories/device_repository_impl.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/data/repositories/personnel_repository_impl.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/operation/data/repositories/incident_repository_impl.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/settings/data/repositories/app_config_repository_impl.dart';
import 'package:SarSys/mock/app_config_service_mock.dart';
import 'package:SarSys/mock/device_service_mock.dart';
import 'package:SarSys/mock/incident_service_mock.dart';
import 'package:SarSys/mock/personnel_service_mock.dart';
import 'package:SarSys/mock/tracking_service_mock.dart';
import 'package:SarSys/mock/unit_service_mock.dart';
import 'package:SarSys/mock/user_service_mock.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/settings/domain/repositories/app_config_repository.dart';
import 'package:SarSys/features/user/domain/repositories/auth_token_repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/settings/data/services/app_config_service.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/utils/data.dart';

const MethodChannel udidChannel = MethodChannel('flutter_udid');
const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const MethodChannel permissionHandlerChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class BlocTestHarness implements BlocDelegate {
  static const TRUSTED = 'username@some.domain';
  static const UNTRUSTED = 'username';
  static const PASSWORD = 'password';
  static const USER_ID = 'user_id';
  static const DIVISION = 'division';
  static const DEPARTMENT = 'department';

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

  User get user => _userService.token.toUser();

  String _userId;
  String get userId => _userId;

  String _username;
  String get username => _username;

  String _password;
  String get password => _password;

  String _division;
  String get division => _division;

  String _department;
  String get department => _department;

  bool _authenticated;
  bool get isAuthenticated => _authenticated;

  UserServiceMock get userService => _userService;
  UserServiceMock _userService;

  UserBloc _userBloc;
  UserBloc get userBloc => _userBloc;
  bool _withUserBloc = false;

  AppConfigBloc _configBloc;
  AppConfigBloc get configBloc => _configBloc;
  bool _withConfigBloc = false;

  AffiliationBloc _affiliationBloc;
  AffiliationBloc get affiliationBloc => _affiliationBloc;
  bool _withAffiliationBloc = false;

  OrganisationServiceMock get organisationService => _organisationService;
  OrganisationServiceMock _organisationService;

  DivisionServiceMock get divisionService => _divisionService;
  DivisionServiceMock _divisionService;

  DepartmentServiceMock get departmentService => _departmentService;
  DepartmentServiceMock _departmentService;

  PersonServiceMock get personService => _personService;
  PersonServiceMock _personService;

  AffiliationServiceMock get affiliationService => _affiliationService;
  AffiliationServiceMock _affiliationService;

  IncidentServiceMock get incidentService => _incidentService;
  IncidentServiceMock _incidentService;

  OperationServiceMock get operationService => _operationService;
  OperationServiceMock _operationService;

  OperationBloc _operationsBloc;
  OperationBloc get operationsBloc => _operationsBloc;
  bool _withOperationBloc = false;

  DeviceServiceMock get deviceService => _deviceService;
  DeviceServiceMock _deviceService;

  DeviceRepository get deviceRepo => _deviceRepo;
  DeviceRepository _deviceRepo;

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

  bool _waitForOperationsLoaded = false;

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
      _buildPermissionHandlerPlugin();

      // Initialize shared preferences for testing
      SharedPreferences.setMockInitialValues({});

      // Delete any previous data from failed tests
      return await Storage.destroy().catchError(
        (e, stackTrace) => _printError('install > Storage.destroy failed', e, stackTrace),
      );
    });

    setUp(() async {
      _print('setUp...');
      // Hive does not handle close
      // with pending writes in a
      // well-behaved manner. This
      // is a workaround that allows
      // writes to complete in previous
      // zone before old files are
      // deleted from the next zone
      // before next test is run.
      if (Storage.initialized) {
        await Storage.destroy().catchError(
          (e, stackTrace) => _printError('setUp > Storage.destroy() failed', e, stackTrace),
        );
      }
      await Storage.init().catchError(
        (e, stackTrace) => _printError('setUp > Storage.init() failed', e, stackTrace),
      );

      _buildConnectivity();

      if (_withConfigBloc) {
        _buildAppConfigBloc();
      }
      if (_withUserBloc) {
        await _buildUserBloc().catchError(
          (e, stackTrace) => _printError('setUp > _buildUserBloc() failed', e, stackTrace),
        );
      }
      if (_withAffiliationBloc) {
        await _buildAffiliationBloc().catchError(
          (e, stackTrace) => _printError('setUp > _buildAffiliationBloc() failed', e, stackTrace),
        );
      }
      if (_withOperationBloc) {
        await _buildOperationBloc().catchError(
          (e, stackTrace) => _printError('setUp > _buildOperationBloc() failed', e, stackTrace),
        );
      }
      if (_withDeviceBloc) {
        _buildDeviceBloc();
      }
      if (_withUnitBloc) {
        _buildUnitBloc();
      }
      if (_withPersonnelBloc) {
        _buildPersonnelBloc();
      }
      if (_withTrackingBloc) {
        _buildTrackingBloc();
      }

      _print('setUp...ok');

      // Needed for await above to work
      return Future.value();
    });

    tearDown(() async {
      _print('teardown...');
      if (_withConfigBloc) {
        await _configBloc?.close()?.catchError(
              (e, stackTrace) => _printError('tearDown > _configBloc.close() failed', e, stackTrace),
            );
      }
      if (_withUserBloc) {
        await _userBloc?.close()?.catchError(
              (e, stackTrace) => _printError('tearDown > _userBloc.close() failed', e, stackTrace),
            );
      }
      if (_withAffiliationBloc) {
        await _affiliationBloc?.close()?.catchError(
              (e, stackTrace) => _printError('tearDown > _affiliationBloc.close() failed', e, stackTrace),
            );
      }
      if (_withOperationBloc) {
        await _operationsBloc?.close()?.catchError(
              (e, stackTrace) => _printError('tearDown > _operationsBloc.close() failed', e, stackTrace),
            );
      }
      if (_withDeviceBloc) {
        await _deviceBloc?.close()?.catchError(
              (e, stackTrace) => _printError('tearDown > _deviceBloc.close() failed', e, stackTrace),
            );
      }
      if (_withPersonnelBloc) {
        await _personnelBloc?.close()?.catchError(
              (e, stackTrace) => _printError('tearDown > _personnelBloc.close() failed', e, stackTrace),
            );
      }
      if (_withUnitBloc) {
        await _unitBloc?.close()?.catchError(
              (e, stackTrace) => _printError('tearDown > _unitBloc.close() failed', e, stackTrace),
            );
      }
      if (_withTrackingBloc) {
        await _trackingBloc?.close()?.catchError(
              (e, stackTrace) => _printError('tearDown > _trackingBloc.close() failed', e, stackTrace),
            );
        _trackingService?.reset();
      }
      events.clear();
      errors.clear();
      bus.unsubscribeAll();
      _connectivity?.dispose();

      if (Storage.initialized) {
        _print('teardown...destroy');
        return Storage.destroy().catchError(
          (e, stackTrace) => _printError('tearDown > Storage.destroy() failed', e, stackTrace),
        );
      }

      _print('teardown...ok');
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
    String userId = USER_ID,
    String username = UNTRUSTED,
    String password = PASSWORD,
    String division = DIVISION,
    String department = DEPARTMENT,
    bool authenticated = false,
  }) {
    withConfigBloc();
    _userId = userId;
    _username = username;
    _password = password;
    _department = department;
    _division = division;
    _withUserBloc = true;
    _authenticated = authenticated;
  }

  void withAffiliationBloc({
    String userId = USER_ID,
    String username = UNTRUSTED,
    String password = PASSWORD,
    String division = DIVISION,
    String department = DEPARTMENT,
    bool authenticated = true,
  }) {
    withUserBloc(
      username: username,
      password: password,
      authenticated: authenticated,
    );
    _withAffiliationBloc = true;
  }

  void withOperationBloc({
    String userId = USER_ID,
    String username = UNTRUSTED,
    String password = PASSWORD,
    String division = DIVISION,
    String department = DEPARTMENT,
    bool authenticated = false,
  }) {
    withAffiliationBloc(
      username: username,
      password: password,
      division: division,
      department: department,
      authenticated: authenticated,
    );
    _withOperationBloc = true;
  }

  void withDeviceBloc({
    bool waitForOperationsLoaded = true,
  }) {
    _withDeviceBloc = true;
    _waitForOperationsLoaded = waitForOperationsLoaded;
  }

  void withPersonnelBloc({
    bool waitForOperationsLoaded = true,
  }) {
    _withPersonnelBloc = true;
    _waitForOperationsLoaded = waitForOperationsLoaded;
  }

  void withUnitBloc({
    bool waitForOperationsLoaded = true,
  }) {
    _withUnitBloc = true;
    _waitForOperationsLoaded = waitForOperationsLoaded;
  }

  void withTrackingBloc({
    bool waitForOperationsLoaded = true,
  }) {
    _withTrackingBloc = true;
    _waitForOperationsLoaded = waitForOperationsLoaded;
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

  void _buildPermissionHandlerPlugin() {
    permissionHandlerChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'checkPermissionStatus':
          return 1; // PermissionStatus.granted;
      }
      throw UnimplementedError(
        'PermissionHandler method ${methodCall.method} not implemented',
      );
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
    _configBloc = AppConfigBloc(configRepo, bus);
  }

  Future _buildUserBloc() async {
    assert(_withConfigBloc, 'UserBloc requires AppConfigBloc');
    _userService = UserServiceMock.build(
      role: UserRole.commander,
      userId: _userId,
      username: _username,
      password: _password,
      division: _division,
      department: _department,
    );
    _userBloc = UserBloc(
      UserRepository(
        tokens: AuthTokenRepository(),
        service: userService,
        connectivity: connectivity,
      ),
      configBloc,
      bus,
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

  Future _buildAffiliationBloc() async {
    assert(_withUserBloc, 'OperationBloc requires UserBloc');
    _organisationService = OrganisationServiceMock.build();
    _divisionService = DivisionServiceMock.build();
    _departmentService = DepartmentServiceMock.build();
    _personService = PersonServiceMock.build();
    _affiliationService = await AffiliationServiceMock.build();
    _affiliationBloc = AffiliationBloc(
      repo: AffiliationRepositoryImpl(
        affiliationService,
        connectivity: _connectivity,
        orgs: OrganisationRepositoryImpl(
          _organisationService,
          connectivity: _connectivity,
        ),
        divs: DivisionRepositoryImpl(
          _divisionService,
          connectivity: _connectivity,
        ),
        deps: DepartmentRepositoryImpl(
          _departmentService,
          connectivity: _connectivity,
        ),
        persons: PersonRepositoryImpl(
          personService,
          connectivity: _connectivity,
        ),
      ),
      users: _userBloc,
      bus: bus,
    );

    if (_authenticated) {
      await expectThroughLater(_affiliationBloc, emits(isA<UserOnboarded>()));
    }

    return Future.value();
  }

  Future _buildOperationBloc({
    UserRole role = UserRole.commander,
    String passcode = 'T123',
  }) async {
    assert(_withUserBloc, 'OperationBloc requires UserBloc');

    _incidentService = IncidentServiceMock.build(
      _userBloc.repo,
      role: role,
      passcode: passcode,
    );
    _operationService = OperationServiceMock.build(
      _userBloc.repo,
      role: role,
      passcode: passcode,
    );
    _operationsBloc = OperationBloc(
      OperationRepositoryImpl(
        _operationService,
        connectivity: _connectivity,
        incidents: IncidentRepositoryImpl(
          _incidentService,
          connectivity: _connectivity,
        ),
      ),
      _userBloc,
      bus,
    );

    await _configBloc.init();

    if (_authenticated && _waitForOperationsLoaded) {
      // Consume IncidentsLoaded fired by UserAuthenticated
      await expectThroughInOrderLater(
        _operationsBloc,
        [isA<OperationsLoaded>()],
        close: false,
      );
    }
  }

  void _buildDeviceBloc({
    int tetraCount = 0,
    int appCount = 0,
    bool simulate = false,
  }) {
    assert(_withOperationBloc, 'DeviceBloc requires OperationBloc');
    _deviceService = DeviceServiceMock.build(
      _operationsBloc,
      tetraCount: tetraCount,
      appCount: appCount,
      simulate: simulate,
    );
    _deviceRepo = DeviceRepositoryImpl(
      _deviceService,
      connectivity: _connectivity,
    );
    _deviceBloc = DeviceBloc(
      _deviceRepo,
      _userBloc,
      bus,
    );
  }

  void _buildPersonnelBloc({
    int count = 0,
  }) {
    assert(_withUnitBloc, 'PersonnelBloc requires UnitBloc');
    assert(_withOperationBloc, 'PersonnelBloc requires OperationBloc');
    assert(_withAffiliationBloc, 'PersonnelBloc requires AffiliationBloc');
    _personnelService = PersonnelServiceMock.build(count);
    _personnelBloc = PersonnelBloc(
      PersonnelRepositoryImpl(
        _personnelService,
        affiliations: _affiliationBloc.repo,
        units: _unitBloc.repo,
        connectivity: _connectivity,
      ),
      _affiliationBloc,
      _operationsBloc,
      bus,
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

  void _buildUnitBloc({
    int count = 0,
  }) {
    assert(_withOperationBloc, 'UnitBloc requires OperationBloc');
    _unitService = UnitServiceMock.build(count);
    _unitBloc = UnitBloc(
      UnitRepositoryImpl(
        _unitService,
        connectivity: _connectivity,
      ),
      _operationsBloc,
      bus,
    );
  }

  void _buildTrackingBloc({
    int personnelCount = 0,
    int unitCount = 0,
  }) {
    assert(_withOperationBloc, 'UnitBloc requires OperationBloc');
    assert(_withDeviceBloc, 'UnitBloc requires DeviceBloc');
    assert(_withPersonnelBloc, 'UnitBloc requires PersonnelBloc');
    assert(_withUnitBloc, 'UnitBloc requires UnitBloc');
    _trackingService = TrackingServiceMock.build(
      _deviceRepo,
      personnelCount: personnelCount,
      unitCount: unitCount,
    );
    _trackingBloc = TrackingBloc(
      TrackingRepository(
        _trackingService,
        connectivity: _connectivity,
      ),
      operationBloc: _operationsBloc,
      deviceBloc: _deviceBloc,
      personnelBloc: _personnelBloc,
      unitBloc: _unitBloc,
      bus: bus,
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

  void _printError(String message, Object error, StackTrace stackTrace) {
    print(message);
    print(error);
    print(stackTrace);
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

Future<void> expectThroughLater(Stream<BlocEvent> bloc, expected) async {
  assert(bloc != null);
  assert(expected != null);
  await expectLater(bloc, emitsThrough(expected));
}

Future<void> expectThroughLaterIf<State extends BlocEvent>(
  Bloc bloc,
  expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  if (bloc.state is State) {
    assert(expected != null);
    await expectLater(bloc, emitsThrough(expected));
    if (close) {
      bloc.close();
    }
  }
}

Future<void> expectThroughLaterIfNot<State extends BlocEvent>(
  Bloc bloc,
  expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  if (bloc.state is! State) {
    assert(expected != null);
    await expectLater(bloc, emitsThrough(expected));
    if (close) {
      bloc.close();
    }
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

Future expectStorageStatusLater(
  String uuid,
  ConnectionAwareRepository repo,
  StorageStatus expected, {
  @required bool remote,
  dynamic key,
}) async {
  await expectLater(
    repo.onChanged,
    emitsThrough(
      isA<StorageTransition>().having(
        (transition) =>
            transition.from?.value is Aggregate &&
            (transition.from?.value as Aggregate)?.uuid == uuid &&
            (remote ? transition.isRemote : transition.isLocal),
        'is ${remote ? 'remote' : 'local'}',
        isTrue,
      ),
    ),
  );
  expect(
    repo.getState(key ?? uuid)?.status,
    equals(expected == StorageStatus.deleted && remote ? isNull : expected),
    reason: "SHOULD HAVE status ${enumName(expected)}",
  );
  expect(
    repo.getState(key ?? uuid)?.isRemote,
    expected == StorageStatus.deleted && remote ? isNull : (remote ? isTrue : isFalse),
    reason: "SHOULD HAVE ${remote ? 'remote' : 'local'} origin",
  );
}

bool _debug = false;
void _print(String message) {
  if (_debug) {
    print(message);
  }
}
