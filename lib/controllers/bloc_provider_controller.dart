import 'dart:async';

import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/mock/personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/repositories/app_config_repository.dart';
import 'package:SarSys/repositories/device_repository.dart';
import 'package:SarSys/repositories/incident_repository.dart';
import 'package:SarSys/repositories/personnel_repository.dart';
import 'package:SarSys/repositories/unit_repository.dart';
import 'package:SarSys/repositories/user_repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
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

  final _blocs = <Type, Bloc>{};

  T bloc<T extends Bloc>() => _blocs[typeOf<T>()] as T;

  BlocProvider<T> toProvider<T extends Bloc>() => BlocProvider<T>(
        create: (_) => _blocs[typeOf<T>()] as T,
      );

  BlocProviderControllerState _state = BlocProviderControllerState.Empty;
  BlocProviderControllerState get state => _state;

  List<StreamSubscription> _subscriptions = [];
  StreamController<BlocProviderControllerState> _controller = StreamController.broadcast();
  Stream<BlocProviderControllerState> get onChange => _controller.stream;

  List<BlocProvider> get all => [
        toProvider<AppConfigBloc>(),
        toProvider<UserBloc>(),
        toProvider<IncidentBloc>(),
        toProvider<UnitBloc>(),
        toProvider<PersonnelBloc>(),
        toProvider<DeviceBloc>(),
        toProvider<TrackingBloc>(),
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

    final connectivityService = ConnectivityService();

    final AppConfigService configService = !demo.active
        ? AppConfigService(client: client, asset: assetConfig, baseUrl: '$baseRestUrl/api/app-config')
        : AppConfigServiceMock.build(assetConfig, '$baseRestUrl/api', client);
    // ignore: close_sinks
    final AppConfigBloc configBloc = AppConfigBloc(AppConfigRepository(
      APP_CONFIG_VERSION,
      configService,
      connectivity: connectivityService,
    ));

    // Configure user service and repo
    final userService = UserIdentityService(client);
    final userRepo = UserRepository(
      userService,
      connectivity: connectivityService,
    );
    // ignore: close_sinks
    final UserBloc userBloc = UserBloc(userRepo, configBloc);

    // Configure Incident service
    final IncidentService incidentService = !demo.active
        ? IncidentService('$baseRestUrl/api/incidents', client)
        : IncidentServiceMock.build(userRepo, 2, enumName(demo.role), "T123");
    final IncidentBloc incidentBloc = IncidentBloc(IncidentRepository(incidentService), userBloc);

    // Configure Personnel service
    final PersonnelService personnelService = !demo.active
        ? PersonnelService('$baseRestUrl/api/personnel', '$baseWsUrl/api/incidents', client)
        : PersonnelServiceMock.build(demo.personnelCount);
    // ignore: close_sinks
    final PersonnelBloc personnelBloc = PersonnelBloc(PersonnelRepository(personnelService), incidentBloc);

    // Configure Unit service
    final UnitService unitService =
        !demo.active ? UnitService('$baseRestUrl/api/incidents', client) : UnitServiceMock.build(demo.unitCount);
    // ignore: close_sinks
    final UnitBloc unitBloc = UnitBloc(UnitRepository(unitService), incidentBloc, personnelBloc);

    // Configure Device service
    final DeviceService deviceService = !demo.active
        ? DeviceService('$baseRestUrl/api/incidents', '$baseWsUrl/api/incidents', client)
        : DeviceServiceMock.build(incidentBloc, demo.tetraCount, demo.appCount);
    // ignore: close_sinks
    final DeviceBloc deviceBloc = DeviceBloc(DeviceRepository(deviceService), incidentBloc);

    // Configure Tracking service
    final TrackingService trackingService = !demo.active
        ? TrackingService('$baseRestUrl/api/incidents', '$baseWsUrl/api/incidents', client)
        : TrackingServiceMock.build(
            incidentBloc,
            deviceService as DeviceServiceMock,
            demo.personnelCount,
            demo.unitCount,
          );
    // ignore: close_sinks
    final TrackingBloc trackingBloc = TrackingBloc(
      service: trackingService,
      unitBloc: unitBloc,
      deviceBloc: deviceBloc,
      incidentBloc: incidentBloc,
      personnelBloc: personnelBloc,
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
        bloc<AppConfigBloc>().load(),
        bloc<UserBloc>().load(),
      ]).catchError(
        (e) => result.completeError(e, StackTrace.current),
      );
      if (!result.isCompleted) {
        // Override demo parameter from persisted config
        _demo = bloc<AppConfigBloc>().config.toDemoParams();

        // Allow _onUserChange to transition to next legal state
        _controller.add(BlocProviderControllerState.Initialized);

        // Set state depending on user state
        _onUserState(bloc<UserBloc>().state);

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

    _blocs[configBloc.runtimeType] = configBloc;
    _blocs[userBloc.runtimeType] = userBloc;
    _blocs[incidentBloc.runtimeType] = incidentBloc;
    _blocs[unitBloc.runtimeType] = unitBloc;
    _blocs[personnelBloc.runtimeType] = personnelBloc;
    _blocs[deviceBloc.runtimeType] = deviceBloc;
    _blocs[trackingBloc.runtimeType] = trackingBloc;

    // Rebuild providers when demo parameters changes
    _subscriptions..add(configBloc.listen(_onConfigState))..add(userBloc.listen(_onUserState));

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
      if (state.isInitialized() || state.isLoaded() || state.isUpdated()) {
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
    _blocs.values.forEach((bloc) => bloc.close());

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
