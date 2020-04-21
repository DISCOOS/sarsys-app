import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/mock/app_config.dart';
import 'package:SarSys/mock/devices.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/users.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/repositories/app_config_repository.dart';
import 'package:SarSys/repositories/device_repository.dart';
import 'package:SarSys/repositories/incident_repository.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/repositories/user_repository.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const MethodChannel udidChannel = MethodChannel('flutter_udid');
const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class BlocTestHarness {
  final baseRestUrl = Defaults.baseRestUrl;
  final assetConfig = 'assets/config/app_config.json';

  ConnectivityServiceMock _connectivity;

  ConnectivityServiceMock get connectivity => _connectivity;

  String _username;
  String _password;
  UserServiceMock get userService => _userService;
  UserServiceMock _userService;

  UserBloc _userBloc;
  UserBloc get userBloc => _userBloc;
  bool _withUserBloc = false;

  AppConfigBloc _configBloc;
  AppConfigBloc get configBloc => _configBloc;
  bool _withConfigBloc = false;

  DeviceBloc _deviceBloc;
  DeviceBloc get deviceBloc => _deviceBloc;
  bool _withDeviceBloc = false;

  IncidentBloc _incidentBloc;
  IncidentBloc get incidentBloc => _incidentBloc;
  bool _withIncidentBloc = false;

  void install() {
    setUpAll(() {
      // Required since provider need access to service bindings prior to calling 'test()'
      _withAssets();

      // TODO: Use flutter_driver instead?
      // Mock required plugins and services
      _buildUdidPlugin();
      _buildPathPlugin();
      _buildSecureStoragePlugin();

      // Initialize shared preferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() async {
      _buildConnectivity();
      if (_withConfigBloc) {
        _buildAppConfigBloc();
      }
      if (_withUserBloc) {
        _buildUserBloc();
      }
      if (_withDeviceBloc) {
        _buildDeviceBloc();
      }
      if (_withIncidentBloc) {
        _buildIncidentBloc();
      }
      return await Storage.init();
    });

    tearDown(() async {
      if (_withConfigBloc) {
        await _configBloc?.close();
      }
      if (_withUserBloc) {
        await _userBloc?.close();
      }
      if (_withDeviceBloc) {
        await _deviceBloc?.close();
      }
      if (_withIncidentBloc) {
        await _incidentBloc?.close();
      }
      _connectivity?.dispose();
      if (Storage.initialized) {
        await Storage.destroy();
      }
    });

    tearDownAll(() async {});
  }

  void withConfigBloc() {
    _withConfigBloc = true;
  }

  void withUserBloc({String username = 'username', String password = 'password'}) {
    withConfigBloc();
    _username = username;
    _password = password;
    _withUserBloc = true;
  }

  void withDeviceBloc() {
    _withDeviceBloc = true;
  }

  void withIncidentBloc() {
    withUserBloc();
    _withIncidentBloc = true;
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
    final AppConfigRepository configRepo = AppConfigRepository(
      APP_CONFIG_VERSION,
      configService,
      connectivity: _connectivity,
    );
    _configBloc = AppConfigBloc(configRepo);
  }

  void _buildUserBloc() {
    assert(_withConfigBloc, 'UserBloc requires AppConfigBloc');
    _userService = UserServiceMock.build(
      UserRole.commander,
      _configBloc.repo,
      _username,
      _password,
    );
    _userBloc = UserBloc(
      UserRepository(
        userService,
        connectivity: connectivity,
      ),
      configBloc,
    );
  }

  void _buildIncidentBloc({UserRole role = UserRole.commander, String passcode = 'T123'}) {
    assert(_withUserBloc, 'IncidentBloc requires UserBloc');
    final IncidentService incidentService = IncidentServiceMock.build(
      _userBloc.repo,
      2,
      enumName(role),
      passcode,
    );
    _incidentBloc = IncidentBloc(IncidentRepository(incidentService), userBloc);
  }

  void _buildDeviceBloc({int tetraCount = 10, int appCount = 10}) {
    assert(_withIncidentBloc, 'DeviceBloc requires IncidentBloc');
    final DeviceService deviceService = DeviceServiceMock.build(
      _incidentBloc,
      tetraCount,
      appCount,
    );
    _deviceBloc = DeviceBloc(DeviceRepository(deviceService), _incidentBloc);
  }
}

class ConnectivityServiceMock extends Mock implements ConnectivityService {
  ConnectivityServiceMock({ConnectivityStatus status = ConnectivityStatus.cellular}) : _status = status;

  StreamController<ConnectivityStatus> _controller = StreamController();
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
