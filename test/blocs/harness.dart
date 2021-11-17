

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:SarSys/features/tracking/data/repositories/tracking_repository_impl.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/features/affiliation/data/repositories/affiliation_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/department_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/division_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/organisation_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/person_repository_impl.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:SarSys/features/operation/data/repositories/operation_repository_impl.dart';
import 'package:SarSys/features/unit/data/repositories/unit_repository_impl.dart';
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
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/settings/domain/repositories/app_config_repository.dart';
import 'package:SarSys/features/user/domain/repositories/auth_token_repository.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/settings/data/services/app_config_service.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/utils/data.dart';

import '../mock/affiliation_service_mock.dart';
import '../mock/department_service_mock.dart';
import '../mock/division_service_mock.dart';
import '../mock/operation_service_mock.dart';
import '../mock/organisation_service_mock.dart';
import '../mock/person_service_mock.dart';
import '../mock/app_config_service_mock.dart';
import '../mock/device_service_mock.dart';
import '../mock/incident_service_mock.dart';
import '../mock/personnel_service_mock.dart';
import '../mock/tracking_service_mock.dart';
import '../mock/unit_service_mock.dart';
import '../mock/user_service_mock.dart';

const MethodChannel udidChannel = MethodChannel('flutter_udid');
const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const MethodChannel permissionHandlerChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class BlocTestHarness implements BlocObserver {
  static const TRUSTED = 'username@some.domain';
  static const UNTRUSTED = 'username';
  static const PASSWORD = 'password';
  static const USER_ID = 'user_id';
  static const DIVISION = 'division';
  static const DEPARTMENT = 'department';

  final baseRestUrl = Defaults.baseRestUrl;
  final assetConfig = 'assets/config/app_config.json';

  late ConnectivityServiceMock _connectivity
  ;
  ConnectivityServiceMock? get connectivity => _connectivity;

  bool get isWifi => connectivity!.isWifi;
  bool get isOnline => connectivity!.isOnline;
  bool get isOffline => connectivity!.isOffline;
  bool get isCellular => connectivity!.isCellular;

  BlocEventBus get bus => _observer.bus;
  AppBlocObserver _observer = AppBlocObserver();

  User get user => _userService!.token!.toUser();

  String? _userId;
  String? get userId => _userId;

  String? _username;
  String? get username => _username;

  String? _password;
  String? get password => _password;

  String? get division => _division;
  String? _division;

  String? get department => _department;
  String? _department;

  bool get isAuthenticated => _authenticated;
  bool _authenticated = false;

  UserServiceMock? get userService => _userService;
  UserServiceMock? _userService;

  UserBloc? get userBloc => _userBloc;
  UserBloc? _userBloc;
  bool _withUserBloc = false;

  AppConfigBloc? get configBloc => _configBloc;
  AppConfigBloc? _configBloc;
  bool _withConfigBloc = false;

  AffiliationBloc? get affiliationBloc => _affiliationBloc;
  AffiliationBloc? _affiliationBloc;
  bool _withAffiliationBloc = false;

  OrganisationServiceMock? get organisationService => _organisationService;
  OrganisationServiceMock? _organisationService;

  DivisionServiceMock? get divisionService => _divisionService;
  DivisionServiceMock? _divisionService;

  DepartmentServiceMock? get departmentService => _departmentService;
  DepartmentServiceMock? _departmentService;

  PersonServiceMock? get personService => _personService;
  PersonServiceMock? _personService;

  AffiliationServiceMock? get affiliationService => _affiliationService;
  AffiliationServiceMock? _affiliationService;

  IncidentServiceMock? get incidentService => _incidentService;
  IncidentServiceMock? _incidentService;

  OperationServiceMock? get operationService => _operationService;
  OperationServiceMock? _operationService;

  OperationBloc? get operationsBloc => _operationsBloc;
  OperationBloc? _operationsBloc;
  bool _withOperationBloc = false;

  DeviceServiceMock? get deviceService => _deviceService;
  DeviceServiceMock? _deviceService;

  DeviceRepository? get deviceRepo => _deviceRepo;
  DeviceRepository? _deviceRepo;

  DeviceBloc? get deviceBloc => _deviceBloc;
  DeviceBloc? _deviceBloc;
  bool _withDeviceBloc = false;

  PersonnelServiceMock? get personnelService => _personnelService;
  PersonnelServiceMock? _personnelService;

  PersonnelBloc? get personnelBloc => _personnelBloc;
  PersonnelBloc? _personnelBloc;
  bool _withPersonnelBloc = false;

  UnitServiceMock? get unitService => _unitService;
  UnitServiceMock? _unitService;

  UnitBloc? get unitBloc => _unitBloc;
  UnitBloc? _unitBloc;
  bool _withUnitBloc = false;

  TrackingServiceMock? get trackingService => _trackingService;
  TrackingServiceMock? _trackingService;

  TrackingBloc? get trackingBloc => _trackingBloc;
  TrackingBloc? _trackingBloc;
  bool _withTrackingBloc = false;

  void install() {
    Timer? timer;
    Bloc.observer = this;
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
        (error, stackTrace) => debugPrintError(
          'install > Storage.destroy failed',
          error,
          stackTrace,
        ),
      );
    });

    setUp(() async {
      assert(timer == null, 'Do not run test in parallel');
      timer = Timer(_timeout, () async {
        debugPrint('------TIMEOUT------');
        debugPrint('Listing events from ${_streamEvents.length} logs...');
        _streamEvents.entries.forEach((entry) {
          debugPrint('------LOG:${entry.key}------');
          debugPrint('>> ${entry.value.join('\n>>  ')}');
          debugPrint('>> log ended');
          debugPrint('');
        });
        throw 'Test timeout';
      });
      debugPrint('setUp...');
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
          (e, stackTrace) => debugPrintError(
            'setUp > Storage.destroy() failed',
            e,
            stackTrace,
          ),
        );
      }
      await Storage.init().catchError(
        (e, stackTrace) => debugPrintError('setUp > Storage.init() failed', e, stackTrace),
      );

      _buildConnectivity();

      if (_withConfigBloc) {
        _buildAppConfigBloc();
      }
      if (_withUserBloc) {
        _buildUserBloc();
      }
      if (_withOperationBloc) {
        _buildOperationBloc();
      }
      if (_withAffiliationBloc) {
        await _buildAffiliationBloc().catchError(
          (e, stackTrace) => debugPrintError('setUp > _buildAffiliationBloc() failed', e, stackTrace),
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

      if (_authenticated) {
        assert(_userBloc != null);
        await _userBloc!.login(
          username: _username,
          password: _password,
        );
        await Future.wait<void>([
          _configBloc!.init(),
          expectThroughLater(
            _userBloc!.stream,
            isA<UserAuthenticated>(),
          ),
          if (_withOperationBloc)
            expectThroughLater(
              _operationsBloc!.stream,
              isA<OperationsLoaded>().having((event) => event.isRemote, 'Should be remote', isTrue),
            ),
          if (_withAffiliationBloc)
            expectThroughLater(
              _affiliationBloc!.stream,
              emitsThrough(isA<UserOnboarded>().having((event) => event.isRemote, 'Should be remote', isTrue)),
            ),
        ]);
      }

      debugPrint('setUp...ok');

      // Needed for await above to work
      return Future.value();
    });

    tearDown(() async {
      debugPrint('teardown...');
      if (_withConfigBloc) {
        await _configBloc?.close().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _configBloc.close() failed', e, stackTrace),
            );
      }
      if (_withUserBloc) {
        await _userBloc?.close().timeout(Duration(seconds: 1)).catchError(
              (e, stackTrace) => debugPrintError('tearDown > _userBloc.close() failed', e, stackTrace),
            );
      }
      if (_withAffiliationBloc) {
        await _affiliationBloc?.close().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _affiliationBloc.close() failed', e, stackTrace),
            );
        await _personService?.dispose().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _personService.dispose() failed', e, stackTrace),
            );
        await _affiliationService?.dispose().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _affiliationService.dispose() failed', e, stackTrace),
            );
      }
      if (_withOperationBloc) {
        await _operationsBloc?.close().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _operationsBloc.close() failed', e, stackTrace),
            );
      }
      if (_withDeviceBloc) {
        await _deviceBloc?.close().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _deviceBloc.close() failed', e, stackTrace),
            );
      }
      if (_withPersonnelBloc) {
        await _personnelBloc?.close().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _personnelBloc.close() failed', e, stackTrace),
            );
      }
      if (_withUnitBloc) {
        await _unitBloc?.close().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _unitBloc.close() failed', e, stackTrace),
            );
      }
      if (_withTrackingBloc) {
        await _trackingBloc?.close().catchError(
              (e, stackTrace) => debugPrintError('tearDown > _trackingBloc.close() failed', e, stackTrace),
            );
        _trackingService?.reset();
      }
      history.clear();
      errors.clear();
      bus.unsubscribeAll();
      _connectivity.dispose();
      timer?.cancel();
      timer = null;
      _streamEvents.clear();

      if (Storage.initialized) {
        debugPrint('teardown...destroy');
        return Storage.destroy().catchError(
          (e, stackTrace) => debugPrintError('tearDown > Storage.destroy() failed', e, stackTrace),
        );
      }
      debugPrint('teardown...ok');
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

  void withDebug({
    bool errors = true,
    bool streams = true,
    bool commands = true,
    bool transitions = true,
    Duration timeout = const Duration(seconds: 5),
  }) {
    _timeout = timeout;
    _debugErrors = errors;
    _debugStreams = streams;
    _debugCommands = commands;
    _debugTransitions = transitions;
  }

  bool get _debug => _debugCommands || _debugTransitions || _debugErrors;

  bool _debugErrors = false;
  bool _debugCommands = false;
  bool _debugTransitions = false;
  Duration _timeout = Duration(seconds: 5);

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

  void withDeviceBloc() {
    _withDeviceBloc = true;
  }

  void withPersonnelBloc() {
    _withPersonnelBloc = true;
  }

  void withUnitBloc() {
    _withUnitBloc = true;
  }

  void withTrackingBloc() {
    _withTrackingBloc = true;
  }

  void _buildSecureStoragePlugin() {
    final Map<String, String> storage = {};
    secureStorageChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      if ('read' == methodCall.method) {
        storage[methodCall.arguments['key']];
      } else if ('write' == methodCall.method) {
        storage[methodCall.arguments['key']] = methodCall.arguments['value'];
      } else if ('readAll' == methodCall.method) {
        storage.cast<String, String>();
      } else if ('delete' == methodCall.method) {
        storage.remove(methodCall.arguments['key']);
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
      String key = utf8.decode(message!.buffer.asUint8List());
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
    when(_connectivity.update()).thenAnswer((_) async => _connectivity.state);
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

  void _buildUserBloc() {
    assert(_withConfigBloc, 'UserBloc requires AppConfigBloc');
    _userService = UserServiceMock.build(
      role: UserRole.commander,
      userId: _userId,
      username: _username,
      password: _password,
      division: _division,
      department: _department,
      connectivity: _connectivity,
    );
    _userBloc = UserBloc(
      UserRepository(
        tokens: AuthTokenRepository(),
        service: userService,
      ),
      configBloc,
      bus,
    );
  }

  Future _buildAffiliationBloc() async {
    assert(_withUserBloc, 'OperationBloc requires UserBloc');
    _organisationService = OrganisationServiceMock.build() as OrganisationServiceMock?;
    _divisionService = DivisionServiceMock.build() as DivisionServiceMock?;
    _departmentService = DepartmentServiceMock.build() as DepartmentServiceMock?;
    _personService = await (PersonServiceMock.build() as FutureOr<PersonServiceMock?>);
    _affiliationService = await (AffiliationServiceMock.build(_personService) as FutureOr<AffiliationServiceMock?>);
    _affiliationBloc = AffiliationBloc(
      repo: AffiliationRepositoryImpl(
        affiliationService!,
        connectivity: _connectivity,
        orgs: OrganisationRepositoryImpl(
          _organisationService!,
          connectivity: _connectivity,
        ),
        divs: DivisionRepositoryImpl(
          _divisionService!,
          connectivity: _connectivity,
        ),
        deps: DepartmentRepositoryImpl(
          _departmentService!,
          connectivity: _connectivity,
        ),
        persons: PersonRepositoryImpl(
          personService!,
          connectivity: _connectivity,
        ),
      ),
      users: _userBloc,
      bus: bus,
    );

    return Future.value();
  }

  void _buildOperationBloc({
    UserRole role = UserRole.commander,
    String passcode = 'T123',
  }) {
    assert(_withUserBloc, 'OperationBloc requires UserBloc');

    _incidentService = IncidentServiceMock.build(
      _userBloc!.repo,
      role: role,
      passcode: passcode,
    ) as IncidentServiceMock?;
    _operationService = OperationServiceMock.build(
      _userBloc!.repo,
      role: role,
      passcode: passcode,
    ) as OperationServiceMock?;
    _operationsBloc = OperationBloc(
      OperationRepositoryImpl(
        _operationService!,
        connectivity: _connectivity,
        incidents: IncidentRepositoryImpl(
          _incidentService!,
          connectivity: _connectivity,
        ),
      ),
      _userBloc,
      bus,
    );
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
    ) as DeviceServiceMock?;
    _deviceRepo = DeviceRepositoryImpl(
      _deviceService!,
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
    _personnelService = PersonnelServiceMock.build(
      count,
      _affiliationService,
    );
    _personnelBloc = PersonnelBloc(
      PersonnelRepositoryImpl(
        _personnelService!,
        affiliations: _affiliationBloc!.repo,
        units: _unitBloc!.repo,
        connectivity: _connectivity,
      ),
      _affiliationBloc,
      _operationsBloc,
      bus,
    );
  }

  void _buildUnitBloc({
    int count = 0,
  }) {
    assert(_withOperationBloc, 'UnitBloc requires OperationBloc');
    _unitService = UnitServiceMock.build(count) as UnitServiceMock?;
    _unitBloc = UnitBloc(
      UnitRepositoryImpl(
        _unitService!,
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
      TrackingRepositoryImpl(
        _trackingService!,
        tracks: null,
        connectivity: _connectivity,
      ),
      operationBloc: _operationsBloc,
      deviceBloc: _deviceBloc!,
      personnelBloc: _personnelBloc,
      unitBloc: _unitBloc!,
      bus: bus,
    );
  }

  final errors = <Bloc, List<Object>>{};

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    errors.update(
      bloc as Bloc<dynamic, dynamic>,
      (errors) => errors..add(error),
      ifAbsent: () => [error],
    );
    debugPrintError('onError(${bloc.runtimeType})', error, stackTrace);
  }

  final List<Pair<Bloc<dynamic, dynamic>, Object?>> history = <Pair<Bloc, Object>>[];

  @override
  void onEvent(Bloc bloc, Object? event) {
    history.add(Pair.of(bloc, event));
    if (_debugCommands) {
      debugPrint('------COMMAND-------');
      debugPrint('bloc: ${bloc.runtimeType}');
      debugPrint('command: ${event.runtimeType}');
    }
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    history.add(Pair.of(bloc, transition.nextState));
    if (_debugTransitions) {
      debugPrint('------TRANSITION-------');
      debugPrint('bloc: ${bloc.runtimeType}');
      debugPrint('transition.event: ${transition.event.runtimeType}');
      debugPrint('transition.nextState: ${transition.nextState.runtimeType}');
    }
  }

  void debugPrintError(String message, Object error, StackTrace stackTrace) {
    if (_debugErrors) {
      debugPrint('------ERROR-------');
      debugPrint('message: $message');
      debugPrint('error: $error');
      debugPrint('stackTrace: $stackTrace');
    }
  }

  void debugPrint(String message) {
    if (_debug) {
      print(message);
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {}

  @override
  void onClose(BlocBase bloc) {}

  @override
  void onCreate(BlocBase bloc) {}
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
  Duration? duration,
  int skip = 0,
  bool close = false,
}) async {
  assert(bloc != null);
  final states = <State>[];
  final sub1 = _printStream('expectExactlyLater', bloc.stream);
  final sub2 = bloc.stream.skip(skip).listen(
        states.add,
      );
  if (duration != null) await Future.delayed(duration);
  if (close) {
    await bloc.close();
  }
  expect(states, expected);
  await _cancelPrintStream('expectExactlyLater', bloc.stream, sub1);
  await sub2.cancel();
}

void expectThrough<B extends Bloc<dynamic, State>?, State>(
  B bloc,
  expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  assert(expected != null);
  final sub = _printStream('expectThrough', bloc!.stream);
  expect(bloc.stream, emitsThrough(expected));
  if (close) {
    bloc.close();
  }
  await _cancelPrintStream('expectThrough', bloc.stream, sub);
}

void expectThroughInOrder<B extends Bloc<dynamic, State>?, State>(
  B bloc,
  Iterable expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  assert(expected != null);
  final sub = _printStream('expectThroughInOrder', bloc!.stream);
  expect(bloc.stream, emitsThrough(emitsInOrder(expected)));
  if (close) {
    bloc.close();
  }
  await _cancelPrintStream('expectThroughInOrder', bloc.stream, sub);
}

Future<void> expectThroughLater(Stream<BlocState?> stream, expected) async {
  assert(stream != null);
  assert(expected != null);
  var sub;
  if (stream.isBroadcast) {
    sub = _printStream('expectThroughLater', stream);
  }
  await expectLater(stream, emitsThrough(expected));
  await _cancelPrintStream('expectThroughLater', stream, sub);
}

Future<void> expectThroughLaterIf<State extends BlocState>(
  Bloc bloc,
  expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  if (bloc.state is State) {
    assert(expected != null);
    final sub = _printStream('expectThroughLaterIf', bloc.stream);
    await expectLater(bloc.stream, emitsThrough(expected));
    if (close) {
      bloc.close();
    }
    await _cancelPrintStream('expectThroughLaterIf', bloc.stream, sub);
  }
}

Future<void> expectThroughLaterIfNot<State extends BlocState>(
  Bloc bloc,
  expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  if (bloc.state is! State) {
    final sub = _printStream('expectThroughLaterIfNot', bloc.stream);
    assert(expected != null);
    await expectLater(bloc.stream, emitsThrough(expected));
    if (close) {
      bloc.close();
    }
    await _cancelPrintStream('expectThroughLaterIfNot', bloc.stream, sub);
  }
}

Future<void> expectThroughInOrderLater<B extends Bloc<dynamic, State>?, State>(
  B bloc,
  Iterable expected, {
  bool close = false,
}) async {
  assert(bloc != null);
  assert(expected != null);
  final sub = _printStream('expectThroughInOrderLater', bloc!.stream);
  await expectLater(bloc.stream, emitsThrough(emitsInOrder(expected)));
  if (close) {
    await bloc.close();
  }
  await _cancelPrintStream('expectThroughInOrderLater', bloc.stream, sub);
}

Stream<StorageStatus> toStatusChanges(Stream<StorageTransition?> changes) =>
    changes.where((state) => state!.to.isRemote!).map((state) => state!.to.status);

void expectStorageStatus(
  StorageState actual,
  StorageStatus expected, {
  required bool remote,
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
  String? uuid,
  StatefulRepository repo,
  StorageStatus expected, {
  required bool remote,
  dynamic key,
  Duration timeout = const Duration(milliseconds: 100),
}) async {
  StackTrace stackTrace = StackTrace.current;
  if (repo.states[uuid]?.isRemote != true) {
    await expectLater(
      repo.onChanged,
      emitsThrough(
        isA<StorageTransition>().having(
          (transition) =>
              transition.status == expected &&
              transition.to.value is Aggregate &&
              (transition.to.value as Aggregate?)?.uuid == uuid &&
              (remote ? transition.isRemote : transition.isLocal),
          'is ${remote ? 'remote' : 'local'}',
          isTrue,
        ),
      ),
    ).timeout(timeout).catchError((e) {
      print('Storage status $expected:$remote not received');
      print('Stacktrace: $stackTrace');
      throw e;
    });
  }
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

var _debugStreams = false;

final _streamEvents = <String, List<String>>{};

StreamSubscription _printStream(String test, Stream stream) {
  final key = '$test:${stream.runtimeType}';
  final buffer = StringBuffer();
  buffer.writeln('------STREAM------');
  buffer.writeln('test: $test');
  buffer.writeln('type: ${stream.runtimeType}');
  buffer.writeln('event: listening');
  _logStreamEvent(key, buffer);

  return stream.listen((e) {
    final buffer = StringBuffer();
    buffer.writeln('------STREAM------');
    buffer.writeln('test: $test');
    buffer.writeln('type: ${stream.runtimeType}');
    buffer.writeln('event: ${e.runtimeType}');
    _logStreamEvent(key, buffer);
  });
}

void _logStreamEvent(String key, StringBuffer buffer) {
  _streamEvents.update(
    key,
    (events) => events..add(buffer.toString()),
    ifAbsent: () => [buffer.toString()],
  );
  if (_debugStreams) {
    print(buffer.toString());
  }
}

Future<void>? _cancelPrintStream(String test, Stream stream, StreamSubscription? sub) {
  final key = '$test:${stream.runtimeType}';
  final buffer = StringBuffer();
  buffer.writeln('------STREAM------');
  buffer.writeln('test: $test');
  buffer.writeln('type: ${stream.runtimeType}');
  buffer.writeln('event: cancelled');
  _logStreamEvent(key, buffer);
  return sub?.cancel();
}
