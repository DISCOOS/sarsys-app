import 'dart:async';

import 'package:SarSys/models/User.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/mock/app_config.dart';
import 'package:SarSys/mock/devices.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/tracking.dart';
import 'package:SarSys/mock/units.dart';
import 'package:SarSys/mock/users.dart';

import 'package:SarSys/core/defaults.dart';

import 'package:SarSys/services/app_config_service.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:SarSys/services/user_service.dart';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';

import '../models/AppConfig.dart';

class ProviderController {
  final Client client;
  final DemoParams demo;

  BlocProvider<AppConfigBloc> _configProvider;
  BlocProvider<UserBloc> _userProvider;
  BlocProvider<IncidentBloc> _incidentProvider;
  BlocProvider<UnitBloc> _unitProvider;
  BlocProvider<DeviceBloc> _deviceProvider;
  BlocProvider<TrackingBloc> _trackingProvider;

  BlocProvider<AppConfigBloc> get configProvider => _configProvider;
  BlocProvider<UserBloc> get userProvider => _userProvider;
  BlocProvider<IncidentBloc> get incidentProvider => _incidentProvider;
  BlocProvider<UnitBloc> get unitProvider => _unitProvider;
  BlocProvider<DeviceBloc> get deviceProvider => _deviceProvider;
  BlocProvider<TrackingBloc> get trackingProvider => _trackingProvider;

  ProviderControllerState _state = ProviderControllerState.Empty;
  ProviderControllerState get state => _state;

  StreamSubscription _subscription;
  StreamController<ProviderControllerState> _controller = StreamController.broadcast();
  Stream<ProviderControllerState> get onChange => _controller.stream;

  List<BlocProvider> get all => [
        _configProvider,
        _userProvider,
        _incidentProvider,
        _unitProvider,
        _deviceProvider,
        _trackingProvider,
      ];

  ProviderController._internal(
    this.client,
    this.demo,
  );

  ProviderController link({
    @required AppConfigBloc configBloc,
    @required UserBloc userBloc,
    @required IncidentBloc incidentBloc,
    @required UnitBloc unitBloc,
    @required DeviceBloc deviceBloc,
    @required TrackingBloc trackingBloc,
  }) {
    _unset();

    _configProvider = BlocProvider<AppConfigBloc>(bloc: configBloc);
    _userProvider = BlocProvider<UserBloc>(bloc: userBloc);
    _incidentProvider = BlocProvider<IncidentBloc>(bloc: incidentBloc);
    _unitProvider = BlocProvider<UnitBloc>(bloc: unitBloc);
    _deviceProvider = BlocProvider<DeviceBloc>(bloc: deviceBloc);
    _trackingProvider = BlocProvider<TrackingBloc>(bloc: trackingBloc);

    // Rebuild providers when demo parameters changes
    _subscription = configBloc.state.listen(_handle);

    // Notify that providers are ready
    _controller.add(_state = ProviderControllerState.Built);

    return this;
  }

  void _handle(AppConfigState state) {
    if (state.isInit() || state.isLoaded() || state.isUpdated()) {
      rebuild(demo: (state.data as AppConfig).toDemoParams());
    }
  }

  /// Create providers for mocking
  factory ProviderController.build(
    Client client, {
    DemoParams demo = DemoParams.NONE,
  }) {
    return _build(ProviderController._internal(client, demo), demo, client);
  }

  static ProviderController _build(ProviderController providers, DemoParams demo, Client client) {
    final baseWsUrl = Defaults.baseWsUrl;
    final baseRestUrl = Defaults.baseRestUrl;
    final assetConfig = 'assets/config/app_config.json';
    final AppConfigService configService = !demo.active
        ? AppConfigService(assetConfig, '$baseRestUrl/api/app-config', client)
        : AppConfigServiceMock.build(assetConfig, '$baseRestUrl/api', client);
    final AppConfigBloc configBloc = AppConfigBloc(configService);

    // Configure user service
    final UserService userService =
        !demo.active ? UserService('$baseRestUrl/auth/login', client) : UserServiceMock.buildAny(demo.role);
    final UserBloc userBloc = UserBloc(userService);

    // Configure Incident service
    final IncidentService incidentService = !demo.active
        ? IncidentService('$baseRestUrl/api/incidents', client)
        : IncidentServiceMock.build(userService, 2, enumName(demo.role), "T123");
    final IncidentBloc incidentBloc = IncidentBloc(incidentService, userBloc);

    // Configure Unit service
    final UnitService unitService =
        !demo.active ? UnitService('$baseRestUrl/api/incidents', client) : UnitServiceMock.build(demo.unitCount);
    final UnitBloc unitBloc = UnitBloc(unitService, incidentBloc);

    // Configure Device service
    final DeviceService deviceService = !demo.active
        ? DeviceService('$baseRestUrl/api/incidents', '$baseWsUrl/api/incidents', client)
        : DeviceServiceMock.build(incidentBloc, demo.deviceCount);
    final DeviceBloc deviceBloc = DeviceBloc(deviceService, incidentBloc);

    // Configure Tracking service
    final TrackingService trackingService = !demo.active
        ? TrackingService('$baseRestUrl/api/incidents', '$baseWsUrl/api/incidents', client)
        : TrackingServiceMock.build(
            incidentBloc,
            unitService as UnitServiceMock,
            deviceService as DeviceServiceMock,
            demo.unitCount,
          );
    final TrackingBloc trackingBloc = TrackingBloc(trackingService, incidentBloc, unitBloc, deviceBloc);

    return providers.link(
      configBloc: configBloc,
      userBloc: userBloc,
      incidentBloc: incidentBloc,
      unitBloc: unitBloc,
      deviceBloc: deviceBloc,
      trackingBloc: trackingBloc,
    );
  }

  /// Rebuild providers with given demo parameters.
  ///
  /// Returns true if one or more providers was rebuilt
  bool rebuild({
    DemoParams demo = DemoParams.NONE,
  }) =>
      this.demo == demo ? false : _build(this, demo, client) != null;

  Future<ProviderController> init() async {
    if (ProviderControllerState.Built == _state) {
      await userProvider.bloc.load();
      await configProvider.bloc.fetch();
      _controller.add((_state = ProviderControllerState.Ready));
    }
    return this;
  }

  void dispose() {
    _unset();
    _controller.close();
  }

  void _unset() {
    if (_subscription != null) _subscription.cancel();

    _configProvider?.bloc?.dispose();
    _userProvider?.bloc?.dispose();
    _incidentProvider?.bloc?.dispose();
    _unitProvider?.bloc?.dispose();
    _deviceProvider?.bloc?.dispose();
    _trackingProvider?.bloc?.dispose();

    // Notify that provider is not ready
    _controller.add(_state = ProviderControllerState.Empty);
  }
}

enum ProviderControllerState {
  /// Controller is empty, no blocs available
  Empty,

  /// Blocs are built, not ready
  Built,

  /// Blocks are ready
  Ready,
}

class DemoParams {
  final bool active;
  final UserRole role;
  final int unitCount;
  final int deviceCount;

  static const NONE = const DemoParams(false);

  const DemoParams(
    this.active, {
    this.unitCount = 15,
    this.deviceCount = 30,
    this.role = UserRole.Commander,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoParams &&
          runtimeType == other.runtimeType &&
          active == other.active &&
          role == other.role &&
          unitCount == other.unitCount &&
          deviceCount == other.deviceCount;

  @override
  int get hashCode => active.hashCode ^ role.hashCode ^ unitCount.hashCode ^ deviceCount.hashCode;
}
