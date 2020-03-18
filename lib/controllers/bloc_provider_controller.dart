import 'dart:async';

import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/mock/personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/mock/app_config.dart';
import 'package:SarSys/mock/devices.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/tracking.dart';
import 'package:SarSys/mock/units.dart';

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

class BlocProviderController {
  final Client client;

  DemoParams _demo;
  DemoParams get demo => _demo;

  BlocProvider<AppConfigBloc> _configProvider;
  BlocProvider<UserBloc> _userProvider;
  BlocProvider<IncidentBloc> _incidentProvider;
  BlocProvider<UnitBloc> _unitProvider;
  BlocProvider<PersonnelBloc> _personnelProvider;
  BlocProvider<DeviceBloc> _deviceProvider;
  BlocProvider<TrackingBloc> _trackingProvider;

  BlocProvider<AppConfigBloc> get configProvider => _configProvider;
  BlocProvider<UserBloc> get userProvider => _userProvider;
  BlocProvider<IncidentBloc> get incidentProvider => _incidentProvider;
  BlocProvider<UnitBloc> get unitProvider => _unitProvider;
  BlocProvider<PersonnelBloc> get personnelProvider => _personnelProvider;
  BlocProvider<DeviceBloc> get deviceProvider => _deviceProvider;
  BlocProvider<TrackingBloc> get trackingProvider => _trackingProvider;

  BlocProviderControllerState _state = BlocProviderControllerState.Empty;
  BlocProviderControllerState get state => _state;

  List<StreamSubscription> _subscriptions = [];
  StreamController<BlocProviderControllerState> _controller = StreamController.broadcast();
  Stream<BlocProviderControllerState> get onChange => _controller.stream;

  List<BlocProvider> get all => [
        _configProvider,
        _userProvider,
        _incidentProvider,
        _unitProvider,
        _personnelProvider,
        _deviceProvider,
        _trackingProvider,
      ];

  BlocProviderController._internal(
    this.client,
    DemoParams demo,
  ) : _demo = demo ?? DemoParams.NONE;

  /// Create providers for mocking
  factory BlocProviderController.build(
    Client client, {
    DemoParams demo = DemoParams.NONE,
  }) {
    return _build(BlocProviderController._internal(client, demo), demo, client);
  }

  static BlocProviderController _build(BlocProviderController providers, DemoParams demo, Client client) {
    final baseWsUrl = Defaults.baseWsUrl;
    final baseRestUrl = Defaults.baseRestUrl;
    final assetConfig = 'assets/config/app_config.json';
    final AppConfigService configService = !demo.active
        ? AppConfigService(assetConfig, '$baseRestUrl/api/app-config', client)
        : AppConfigServiceMock.build(assetConfig, '$baseRestUrl/api', client);
    final AppConfigBloc configBloc = AppConfigBloc(configService);

    // Configure user service
    final userService = UserIdentityService();
    //!demo.active ? UserIdentityService() : UserServiceMock.buildAny(demo.role, configService);
    final UserBloc userBloc = UserBloc(userService);

    // Configure Incident service
    final IncidentService incidentService = !demo.active
        ? IncidentService('$baseRestUrl/api/incidents', client)
        : IncidentServiceMock.build(userService, 2, enumName(demo.role), "T123");
    final IncidentBloc incidentBloc = IncidentBloc(incidentService, userBloc);

    // Configure Personnel service
    final PersonnelService personnelService = !demo.active
        ? PersonnelService('$baseRestUrl/api/personnel', '$baseWsUrl/api/incidents', client)
        : PersonnelServiceMock.build(demo.personnelCount);
    final PersonnelBloc personnelBloc = PersonnelBloc(personnelService, incidentBloc);

    // Configure Unit service
    final UnitService unitService =
        !demo.active ? UnitService('$baseRestUrl/api/incidents', client) : UnitServiceMock.build(demo.unitCount);
    final UnitBloc unitBloc = UnitBloc(unitService, incidentBloc, personnelBloc);

    // Configure Device service
    final DeviceService deviceService = !demo.active
        ? DeviceService('$baseRestUrl/api/incidents', '$baseWsUrl/api/incidents', client)
        : DeviceServiceMock.build(incidentBloc, demo.tetraCount, demo.appCount);
    final DeviceBloc deviceBloc = DeviceBloc(deviceService, incidentBloc);

    // Configure Tracking service
    final TrackingService trackingService = !demo.active
        ? TrackingService('$baseRestUrl/api/incidents', '$baseWsUrl/api/incidents', client)
        : TrackingServiceMock.build(
            incidentBloc,
            deviceService as DeviceServiceMock,
            demo.personnelCount,
            demo.unitCount,
          );
    final TrackingBloc trackingBloc = TrackingBloc(
      service: trackingService,
      incidentBloc: incidentBloc,
      unitBloc: unitBloc,
      personnelBloc: personnelBloc,
      deviceBloc: deviceBloc,
    );

    return providers._set(
      demo: demo,
      configBloc: configBloc,
      userBloc: userBloc,
      incidentBloc: incidentBloc,
      unitBloc: unitBloc,
      personnelBloc: personnelBloc,
      deviceBloc: deviceBloc,
      trackingBloc: trackingBloc,
    );
  }

  /// Rebuild providers with given demo parameters.
  ///
  /// Returns true if one or more providers was rebuilt
  bool _rebuild({
    DemoParams demo = DemoParams.NONE,
  }) =>
      this.demo == demo ? false : _build(this, demo, client) != null;

  /// Initialize required blocs (config and user)
  Future<BlocProviderController> init() async {
    final result = Completer<BlocProviderController>();
    if (BlocProviderControllerState.Built == _state) {
      // Fail fast on first error
      await Future.wait<dynamic>([
        configProvider.bloc.fetch(),
        userProvider.bloc.load(),
      ]).catchError(
        (e) => result.completeError(e, StackTrace.current),
      );
      if (!result.isCompleted) {
        // Override demo parameter from persisted config
        _demo = configProvider.bloc.config.toDemoParams();

        // Allow _onUserChange to transition to next legal state
        _controller.add(BlocProviderControllerState.Initialized);

        // Set state depending on user state
        _onUserState(userProvider.bloc.currentState);

        result.complete(this);
      }
    } else {
      result.complete(this);
    }
    return result.future;
  }

  BlocProviderController _set({
    @required DemoParams demo,
    @required AppConfigBloc configBloc,
    @required UserBloc userBloc,
    @required IncidentBloc incidentBloc,
    @required UnitBloc unitBloc,
    @required PersonnelBloc personnelBloc,
    @required DeviceBloc deviceBloc,
    @required TrackingBloc trackingBloc,
  }) {
    _unset();

    _demo = demo;

    _configProvider = BlocProvider<AppConfigBloc>(bloc: configBloc);
    _userProvider = BlocProvider<UserBloc>(bloc: userBloc);
    _incidentProvider = BlocProvider<IncidentBloc>(bloc: incidentBloc);
    _unitProvider = BlocProvider<UnitBloc>(bloc: unitBloc);
    _personnelProvider = BlocProvider<PersonnelBloc>(bloc: personnelBloc);
    _deviceProvider = BlocProvider<DeviceBloc>(bloc: deviceBloc);
    _trackingProvider = BlocProvider<TrackingBloc>(bloc: trackingBloc);

    // Rebuild providers when demo parameters changes
    _subscriptions..add(configBloc.state.listen(_onConfigState))..add(userBloc.state.listen(_onUserState));

    // Notify that providers are ready
    _controller.add(_state = BlocProviderControllerState.Built);

    return this;
  }

  void _onConfigState(AppConfigState state) {
    // Only rebuild when in local or ready state
    if ([
      BlocProviderControllerState.Local,
      BlocProviderControllerState.Ready,
    ].contains(_state)) {
      if (state.isInit() || state.isLoaded() || state.isUpdated()) {
        _rebuild(demo: (state.data as AppConfig).toDemoParams());
      }
    }
  }

  void _onUserState(UserState state) {
    // Handle legal transitions only
    // 1) Initialized -> Local
    // 2) Initialized -> Ready
    // 3) Local -> Ready
    // 4) Ready -> Local
    if ([
      BlocProviderControllerState.Initialized,
      BlocProviderControllerState.Local,
      BlocProviderControllerState.Ready,
    ].contains(_state)) {
      var next = state.isAuthenticated() ? BlocProviderControllerState.Ready : BlocProviderControllerState.Local;
      if (next != _state) {
        _state = next;
        _controller.add(_state);
      }
    }
  }

  void _unset() {
    // Cancel state change subscriptions on current blocs
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();

    // Dispose current blocs
    all.forEach((provider) => provider?.bloc?.dispose());

    // Notify that provider is not ready
    _controller.add(_state = BlocProviderControllerState.Empty);
  }

  void dispose() {
    _unset();
    _controller.close();
  }
}

enum BlocProviderControllerState {
  /// Controller is empty, no blocs available
  Empty,

  /// Controller is built, blocks not ready
  Built,

  /// Required blocs (user and config) are initialized
  Initialized,

  /// Local user (not authenticated), blocks are ready to receive commands
  Local,

  /// User authenticated, blocks are ready to receive commands
  Ready,
}

class DemoParams {
  final bool active;
  final UserRole role;
  final int unitCount;
  final int personnelCount;
  final int tetraCount;
  final int appCount;

  static const NONE = const DemoParams(false);

  const DemoParams(
    this.active, {
    this.unitCount = 10,
    this.personnelCount = 30,
    this.tetraCount = 15,
    this.appCount = 30,
    this.role = UserRole.commander,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoParams &&
          runtimeType == other.runtimeType &&
          active == other.active &&
          role == other.role &&
          unitCount == other.unitCount &&
          personnelCount == other.personnelCount &&
          tetraCount == other.tetraCount &&
          appCount == other.appCount;

  @override
  int get hashCode =>
      active.hashCode ^ role.hashCode ^ unitCount.hashCode ^ personnelCount.hashCode ^ tetraCount.hashCode;
}
