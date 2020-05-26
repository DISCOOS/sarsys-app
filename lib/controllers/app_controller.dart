import 'dart:async';

import 'package:SarSys/blocs/core.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/core/streams.dart';
import 'package:SarSys/features/app_config/data/repositories/app_config_repository_impl.dart';
import 'package:SarSys/core/api.dart';
import 'package:SarSys/repositories/auth_token_repository.dart';
import 'package:SarSys/usecase/personnel_use_cases.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/mock/personnels.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/repositories/device_repository.dart';
import 'package:SarSys/repositories/incident_repository.dart';
import 'package:SarSys/repositories/personnel_repository.dart';
import 'package:SarSys/repositories/tracking_repository.dart';
import 'package:SarSys/repositories/unit_repository.dart';
import 'package:SarSys/repositories/user_repository.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/mock/app_config.dart';
import 'package:SarSys/mock/devices.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/trackings.dart';
import 'package:SarSys/mock/units.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/app_config/data/services/app_config_service.dart';
import 'package:SarSys/services/device_service.dart';
import 'package:SarSys/services/incident_service.dart';
import 'package:SarSys/services/tracking_service.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:SarSys/services/user_service.dart';
import 'package:SarSys/features/app_config/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';

import '../features/app_config/domain/entities/AppConfig.dart';

class AppController {
  AppController._(
    this.client,
    DemoParams demo,
  ) : _demo = demo ?? DemoParams.NONE;

  final Client client;
  final AppBlocDelegate delegate = AppBlocDelegate(BlocEventBus());

  BlocEventBus get bus => delegate.bus;

  Api get api => _api;
  Api _api;

  DemoParams get demo => _demo;
  DemoParams _demo;

  T bloc<T extends Bloc>() => _blocs[typeOf<T>()] as T;
  final _blocs = <Type, Bloc>{};

  BlocProvider<T> toProvider<T extends Bloc>() => BlocProvider.value(
        value: _blocs[typeOf<T>()] as T,
      );

  BlocControllerState _state = BlocControllerState.Empty;
  BlocControllerState get state => _state;
  bool get isEmpty => state == BlocControllerState.Empty;
  bool get isBuilt => state.index >= BlocControllerState.Built.index;
  bool get isInitialized => state.index >= BlocControllerState.Initialized.index;
  bool get isLocal => state == BlocControllerState.Local;
  bool get isReady => state == BlocControllerState.Ready;

  bool shouldInitialize(BlocControllerState state) => state == BlocControllerState.Built;
  bool shouldAuthenticate(BlocControllerState state) => state == BlocControllerState.Local;

  /// [BlocEventHandler]s released on [_unset]
  List<BlocEventHandler> _handlers = [];
  List<BlocEventHandler> get handlers => List.unmodifiable(_handlers);
  void registerEventHandler<T extends BlocEvent>(BlocEventHandler<T> handler) => _handlers.add(
        bus.subscribe<T>(handler),
      );

  /// Subscriptions released on [close]
  final List<StreamSubscription> _subscriptions = [];
  List<StreamSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  void registerStreamSubscription(StreamSubscription subscription) => _subscriptions.add(
        subscription,
      );
  StreamController<BlocControllerState> _controller = StreamController.broadcast();
  Stream<BlocControllerState> get onChange => _controller.stream;

  List<BlocProvider> get all => [
        toProvider<AppConfigBloc>(),
        toProvider<UserBloc>(),
        toProvider<IncidentBloc>(),
        toProvider<UnitBloc>(),
        toProvider<PersonnelBloc>(),
        toProvider<DeviceBloc>(),
        toProvider<TrackingBloc>(),
      ];

  /// Create providers for mocking
  factory AppController.build(
    Client client, {
    DemoParams demo = DemoParams.NONE,
  }) {
    return _build(AppController._(client, demo), demo, client);
  }

  static AppController _build(AppController controller, DemoParams demo, Client client) {
    final baseWsUrl = Defaults.baseWsUrl;
    final baseRestUrl = Defaults.baseRestUrl;
    final assetConfig = 'assets/config/app_config.json';

    // --------------
    // Build services
    // --------------
    final connectivityService = ConnectivityService();

    final AppConfigService configService = !demo.active
        ? AppConfigService(client: client, baseUrl: '$baseRestUrl/api/app-config')
        : AppConfigServiceMock.build(assetConfig, '$baseRestUrl/api', client);

    final userService = UserIdentityService(client);

    // ------------------
    // Build repositories
    // ------------------
    final authRepo = AuthTokenRepository();
    final userRepo = UserRepository(
      service: userService,
      auth: authRepo,
      connectivity: connectivityService,
    );
    final configRepo = AppConfigRepositoryImpl(
      APP_CONFIG_VERSION,
      assets: assetConfig,
      service: configService,
      connectivity: connectivityService,
    );

    // -----------
    // Build blocs
    // -----------

    // ignore: close_sinks
    final AppConfigBloc configBloc = AppConfigBloc(configRepo);

    // ignore: close_sinks
    final UserBloc userBloc = UserBloc(userRepo, configBloc);

    // Configure Incident service
    final IncidentService incidentService = !(demo.active || true)
        ? IncidentService('$baseRestUrl/api/incidents', client)
        : IncidentServiceMock.build(userRepo, count: 2, role: demo.role, passcode: "T123");
    final IncidentBloc incidentBloc = IncidentBloc(
        IncidentRepository(
          incidentService,
          connectivity: connectivityService,
        ),
        controller.bus,
        userBloc);

    // Configure Personnel service
    final PersonnelService personnelService = !(demo.active || true)
        ? PersonnelService('$baseRestUrl/api/personnel', '$baseWsUrl/api/incidents', client)
        : PersonnelServiceMock.build(
            demo.personnelCount,
            iuuids: incidentBloc.repo.keys,
          );
    // ignore: close_sinks
    final PersonnelBloc personnelBloc = PersonnelBloc(
        PersonnelRepository(
          personnelService,
          connectivity: connectivityService,
        ),
        controller.bus,
        incidentBloc);

    // Configure Unit service
    final UnitService unitService = !(demo.active || true)
        ? UnitService('$baseRestUrl/api/incidents', client)
        : UnitServiceMock.build(
            demo.unitCount,
            iuuids: incidentBloc.repo.keys,
          );
    // ignore: close_sinks
    final UnitBloc unitBloc = UnitBloc(
        UnitRepository(
          unitService,
          connectivity: connectivityService,
        ),
        controller.bus,
        incidentBloc,
        personnelBloc);

    // Configure Device service
    final DeviceService deviceService = !(demo.active || true)
        ? DeviceService('$baseRestUrl/api/incidents', '$baseWsUrl/api/incidents', client)
        : DeviceServiceMock.build(
            incidentBloc,
            tetraCount: demo.tetraCount,
            appCount: demo.appCount,
            simulate: true,
            iuuids: incidentBloc.repo.keys,
          );

    // ignore: close_sinks
    final DeviceBloc deviceBloc = DeviceBloc(
      DeviceRepository(
        deviceService,
        connectivity: connectivityService,
      ),
      incidentBloc,
    );

    // Configure Tracking service
    final TrackingService trackingService = !(demo.active || true)
        ? TrackingService('$baseRestUrl/api/incidents', '$baseWsUrl/api/incidents', client)
        : TrackingServiceMock.build(
            deviceService,
            personnelCount: demo.personnelCount,
            unitCount: demo.unitCount,
            iuuids: incidentBloc.repo.keys,
            simulate: demo.simulate,
          );

    // ignore: close_sinks
    final TrackingBloc trackingBloc = TrackingBloc(
      TrackingRepository(
        trackingService,
        connectivity: connectivityService,
      ),
      unitBloc: unitBloc,
      deviceBloc: deviceBloc,
      incidentBloc: incidentBloc,
      personnelBloc: personnelBloc,
    );

    final api = Api(
      httpClient: client,
      baseRestUrl: baseRestUrl,
      users: userRepo,
      services: [
//        unitService.delegate,
        if (configService.delegate != null)
          configService.delegate,
//        deviceService.delegate,
//        incidentService.delegate,
//        trackingService.delegate,
//        personnelService.delegate,
      ],
    );

    return controller._set(
      api: api,
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
  Future<bool> _rebuild({
    bool force = false,
    DemoParams demo = DemoParams.NONE,
  }) async {
    if (force || _demo != demo) {
      _unset();
      return _build(this, demo, client) != null;
    }
    return false;
  }

  /// Initialize application state
  Future<AppController> init() async {
    if (BlocControllerState.Built == _state) {
      await _init();
    }
    return this;
  }

  Future _init() async {
    // If 'current_user_id' in
    // secure storage exists in bloc
    // and access token is valid, this
    // will load incidents for given
    // user. If any incident matches
    // 'selected_iuuid' in secure storage
    // it will be selected as current
    // incident.
    await bloc<UserBloc>().load();

    // Wait for config to become available
    final config = await waitThroughStateWithData<AppConfigState, AppConfig>(
      bloc<AppConfigBloc>(),
      map: (state) => state.data,
      test: (state) => state.data is AppConfig,
      timeout: Duration(hours: 1),
      fail: true,
    );

    // Override demo parameter from persisted config
    _demo = config.toDemoParams();

    // Allow _onUserChange to transition to next legal state
    _controller.add(_state = BlocControllerState.Initialized);

    // Set state depending on user state
    _onUserState(bloc<UserBloc>().state);
  }

  /// Reset application
  Future<void> reset() async {
    // Notify blocs not ready, will show splash screen.
    _controller.add(_state = BlocControllerState.Empty);

    // Initialize logout and delete user
    await bloc<UserBloc>().logout(delete: true);

    // Close
    _unset();

    // Destroy all data
    await Storage.destroy(reinitialize: true);

    // Rebuild blocs, will show onboarding screen
    _rebuild(demo: _demo, force: true);
  }

  AppController _set({
    @required Api api,
    @required DemoParams demo,
    @required AppConfigBloc configBloc,
    @required UserBloc userBloc,
    @required IncidentBloc incidentBloc,
    @required UnitBloc unitBloc,
    @required PersonnelBloc personnelBloc,
    @required DeviceBloc deviceBloc,
    @required TrackingBloc trackingBloc,
  }) {
    assert(
      _blocs.isEmpty,
      "Should be empty, forgot to call _unset?",
    );

    _demo = demo;

    _blocs[configBloc.runtimeType] = configBloc;
    _blocs[userBloc.runtimeType] = userBloc;
    _blocs[incidentBloc.runtimeType] = incidentBloc;
    _blocs[unitBloc.runtimeType] = unitBloc;
    _blocs[personnelBloc.runtimeType] = personnelBloc;
    _blocs[deviceBloc.runtimeType] = deviceBloc;
    _blocs[trackingBloc.runtimeType] = trackingBloc;

    // Rebuild providers when demo parameters changes
    registerStreamSubscription(configBloc.listen(_onConfigState));

    // Handle changes in user state
    registerStreamSubscription(userBloc.listen(_onUserState));

    // Ensure user is mobilized
    registerEventHandler<PersonnelsLoaded>(MobilizeUser());

    // Notify that providers are ready
    _controller.add(_state = BlocControllerState.Built);

    return this;
  }

  void _onConfigState(AppConfigState state) async {
    // Only rebuild when in local or ready state
    if (const [
      BlocControllerState.Local,
      BlocControllerState.Ready,
    ].contains(_state)) {
      if (state.isInitialized() || state.isLoaded() || state.isUpdated()) {
        _rebuild(demo: (state.data as AppConfig).toDemoParams());
      }
    }
  }

  void _onUserState(UserState state) {
    if (state.isPending()) {
      return;
    }
    // Handle legal transitions only
    // 1) Initialized -> Local User (not authenticated), blocks are ready to receive commands
    // 2) Initialized -> Ready User (authenticated), blocks are ready to receive commands
    // 3) Local -> Ready
    // 4) Ready -> Local
    if (const [
      BlocControllerState.Initialized,
      BlocControllerState.Local,
      BlocControllerState.Ready,
    ].contains(_state)) {
      final isReady = state.isAuthenticated() || state.isUnlocked();
      var next = isReady ? BlocControllerState.Ready : BlocControllerState.Local;
      if (next != _state) {
        _state = next;
        _controller.add(_state);
      }
    }
  }

  void _unset() {
    // Unsubscribe all event handlers
    bus.unsubscribeAll();

    // Notify blocs not ready, will show splash screen
    _controller.add(_state = BlocControllerState.Empty);

    // Unsubscribe handlers
    _handlers.forEach((handler) => bus.unsubscribe(handler));
    _handlers.clear();

    // Cancel state change subscriptions on current blocs
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();

    // Dispose current blocs
    _blocs.values.forEach((bloc) => bloc.close());
    _blocs.clear();
  }

  void dispose() {
    _unset();
    _controller.close();
  }
}

enum BlocControllerState {
  /// Controller is empty, no blocs available
  Empty,

  /// Controller is built, blocks not ready
  Built,

  /// Required blocs (user and config) are initialized
  Initialized,

  /// Local User (not authenticated), blocks are ready to receive commands
  Local,

  /// Ready User (authenticated), blocks are ready to receive commands
  Ready,
}

class DemoParams {
  final bool active;
  final UserRole role;
  final int unitCount;
  final int personnelCount;
  final int tetraCount;
  final int appCount;
  final bool simulate;

  static const NONE = const DemoParams(false);

  const DemoParams(
    this.active, {
    this.unitCount = 10,
    this.personnelCount = 30,
    this.tetraCount = 15,
    this.appCount = 30,
    this.role = UserRole.commander,
    this.simulate = true,
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
          appCount == other.appCount &&
          simulate == other.simulate;

  @override
  int get hashCode =>
      active.hashCode ^
      role.hashCode ^
      unitCount.hashCode ^
      personnelCount.hashCode ^
      tetraCount.hashCode ^
      appCount.hashCode ^
      simulate.hashCode;
}
