import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/features/mapping/data/services/base_map_service.dart';
import 'package:SarSys/features/activity/presentation/blocs/activity_bloc.dart';
import 'package:SarSys/features/affiliation/data/repositories/affiliation_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/department_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/division_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/organisation_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/repositories/person_repository_impl.dart';
import 'package:SarSys/features/affiliation/data/services/affiliation_service.dart';
import 'package:SarSys/features/affiliation/data/services/department_service.dart';
import 'package:SarSys/features/affiliation/data/services/division_service.dart';
import 'package:SarSys/features/affiliation/data/services/organisation_service.dart';
import 'package:SarSys/features/affiliation/data/services/person_service.dart';
import 'package:SarSys/features/affiliation/domain/repositories/affiliation_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/department_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/division_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/organisation_repository.dart';
import 'package:SarSys/features/affiliation/domain/repositories/person_repository.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/device/domain/repositories/device_repository.dart';
import 'package:SarSys/features/operation/domain/repositories/incident_repository.dart';
import 'package:SarSys/features/operation/domain/repositories/operation_repository.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/features/settings/domain/repositories/app_config_repository.dart';
import 'package:SarSys/features/tracking/data/repositories/tracking_repository_impl.dart';
import 'package:SarSys/features/unit/domain/repositories/unit_repository.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/data/streams.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/operation/data/repositories/operation_repository_impl.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/features/unit/data/repositories/unit_repository_impl.dart';
import 'package:SarSys/features/settings/data/repositories/app_config_repository_impl.dart';
import 'package:SarSys/features/device/data/repositories/device_repository_impl.dart';
import 'package:SarSys/features/operation/data/repositories/incident_repository_impl.dart';
import 'package:SarSys/features/personnel/data/repositories/personnel_repository_impl.dart';
import 'package:SarSys/features/user/domain/repositories/auth_token_repository.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/features/personnel/data/services/personnel_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/settings/data/services/app_config_service.dart';
import 'package:SarSys/features/device/data/services/device_service.dart';
import 'package:SarSys/features/operation/data/services/incident_service.dart';
import 'package:SarSys/features/tracking/data/services/tracking_service.dart';
import 'package:SarSys/features/unit/data/services/unit_service.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';

import 'data/services/navigation_service.dart';
import 'data/services/provider.dart';

class AppController {
  AppController._(
    this.client,
    DemoParams demo,
  ) : _demo = demo ?? DemoParams.NONE;

  final Client client;
  final AppBlocDelegate delegate = AppBlocDelegate(BlocEventBus());

  BlocEventBus get bus => delegate.bus;

  /// Get SARSys api implementation
  Api get api => _api;
  Api _api;

  /// Demo parameters. Is deprecated.
  @deprecated
  DemoParams get demo => _demo;
  DemoParams _demo;

  /// [MessageChannel] instance communicating
  /// with the backend using web-socket
  MessageChannel get channel => _channel;
  MessageChannel _channel;

  /// Get current [state] of [AppController]
  AppControllerState get state => _state;
  AppControllerState _state = AppControllerState.Empty;

  bool get isEmpty => state == AppControllerState.Empty;
  bool get isBuilt => state.index >= AppControllerState.Built.index;
  bool get isInitialized => state.index >= AppControllerState.Initialized.index;
  bool get isLocal => state == AppControllerState.Local;
  bool get isReady => state == AppControllerState.Ready;

  bool shouldInitialize(AppControllerState state) => state == AppControllerState.Built;
  bool shouldAuthenticate(AppControllerState state) => state == AppControllerState.Local;

  /// Subscriptions released on [close]
  final List<StreamSubscription> _subscriptions = [];
  List<StreamSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  StreamSubscription registerStreamSubscription(StreamSubscription subscription) {
    _subscriptions.add(
      subscription,
    );
    return subscription;
  }

  StreamController<AppControllerState> _controller = StreamController.broadcast();
  Stream<AppControllerState> get onChange => _controller.stream;

  /// Get [Bloc] instance of type [T]
  T bloc<T extends Bloc>() => _blocs[typeOf<T>()] as T;
  final _blocs = <Type, Bloc>{};

  /// Get [BlocProvider] instance for [Bloc] of type [T]
  BlocProvider<T> toBlocProvider<T extends Bloc>() => BlocProvider.value(
        value: _blocs[typeOf<T>()] as T,
      );

  /// Get [Repository] instance of type [T]
  T repository<T extends Repository>() => _repos[typeOf<T>()] as T;
  final _repos = <Type, Repository>{};

  /// Get [RepositoryProvider] instance for [Repository] of type [T]
  RepositoryProvider<T> toRepoProvider<T extends Repository>() => RepositoryProvider.value(
        value: _repos[typeOf<T>()] as T,
      );

  /// Get [Service] instance of type [T]
  T service<T extends Service>() => _services[typeOf<T>()] as T;
  final _services = <Type, Service>{};

  /// Get [ServiceProvider] instance for [Service] of type [T]
  ServiceProvider<T> toServiceProvider<T extends Service>() => ServiceProvider.value(
        value: _services[typeOf<T>()] as T,
      );

  /// Get all [BlocProvider]s as list
  List<BlocProvider> get blocs => [
        toBlocProvider<AppConfigBloc>(),
        toBlocProvider<AffiliationBloc>(),
        toBlocProvider<UserBloc>(),
        toBlocProvider<OperationBloc>(),
        toBlocProvider<UnitBloc>(),
        toBlocProvider<PersonnelBloc>(),
        toBlocProvider<DeviceBloc>(),
        toBlocProvider<TrackingBloc>(),
        toBlocProvider<ActivityBloc>(),
      ];

  /// Get all [RepositoryProvider]s as list
  List<RepositoryProvider> get repos => [
        toRepoProvider<AppConfigRepository>(),
        toRepoProvider<AffiliationRepository>(),
        toRepoProvider<PersonRepository>(),
        toRepoProvider<OrganisationRepository>(),
        toRepoProvider<DivisionRepository>(),
        toRepoProvider<DepartmentRepository>(),
        toRepoProvider<UserRepository>(),
        toRepoProvider<AuthTokenRepository>(),
        toRepoProvider<IncidentRepository>(),
        toRepoProvider<OperationRepository>(),
        toRepoProvider<UnitRepository>(),
        toRepoProvider<PersonnelRepository>(),
        toRepoProvider<DeviceRepository>(),
        toRepoProvider<TrackingRepository>(),
      ];

  /// Get all [ServiceProvider]s as list
  List<ServiceProvider> get services => [
        toServiceProvider<MessageChannel>(),
        toServiceProvider<BaseMapService>(),
        toServiceProvider<NavigationService>(),
        toServiceProvider<ConnectivityService>(),
        // Services that are initialized after each build
        ServiceProvider<LocationService>(
          create: (_) => LocationService(),
        ),
        ServiceProvider<MessageChannel>(
          create: (_) => _channel,
        ),
      ];

  /// Create providers for mocking
  factory AppController.build(
    Client client, {
    DemoParams demo = DemoParams.NONE,
  }) {
    return _build(
      AppController._(client, demo),
      demo: demo,
      client: client,
    );
  }

  static AppController _build(
    AppController controller, {
    @required DemoParams demo,
    @required Client client,
  }) {
    final baseRestUrl = Defaults.baseRestUrl;
    final assetConfig = 'assets/config/app_config.json';

    // ---------------------
    // Build message channel
    // ---------------------
    final channel = MessageChannel();

    // --------------
    // Build services
    // --------------

    final configService = AppConfigService();
    final userService = UserIdentityService(client);
    final connectivityService = ConnectivityService();

    // ------------------
    // Build repositories
    // ------------------
    final authRepo = AuthTokenRepository();
    final userRepo = UserRepository(
      service: userService,
      tokens: authRepo,
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
    final configBloc = AppConfigBloc(configRepo, controller.bus);

    // ignore: close_sinks
    final UserBloc userBloc = UserBloc(userRepo, configBloc, controller.bus);

    // Configure affiliation services
    final orgService = OrganisationService();
    final divService = DivisionService();
    final depService = DepartmentService();
    final personService = PersonService();
    final affiliationService = AffiliationService();

    // ignore: close_sinks
    final affiliationBloc = AffiliationBloc(
      repo: AffiliationRepositoryImpl(
        affiliationService,
        orgs: OrganisationRepositoryImpl(
          orgService,
          connectivity: connectivityService,
        ),
        divs: DivisionRepositoryImpl(
          divService,
          connectivity: connectivityService,
        ),
        deps: DepartmentRepositoryImpl(
          depService,
          connectivity: connectivityService,
        ),
        persons: PersonRepositoryImpl(
          personService,
          connectivity: connectivityService,
        ),
        connectivity: connectivityService,
      ),
      users: userBloc,
      bus: controller.bus,
    );

    // Configure Operation
    final IncidentService incidentService = IncidentService();
    final OperationService operationService = OperationService();

    // ignore: close_sinks
    final OperationBloc operationBloc = OperationBloc(
      OperationRepositoryImpl(
        operationService,
        connectivity: connectivityService,
        incidents: IncidentRepositoryImpl(
          incidentService,
          connectivity: connectivityService,
        ),
      ),
      userBloc,
      controller.bus,
    );

    // Configure Unit service
    final UnitService unitService = UnitService();

    // ignore: close_sinks
    final UnitBloc unitBloc = UnitBloc(
      UnitRepositoryImpl(
        unitService,
        connectivity: connectivityService,
      ),
      operationBloc,
      controller.bus,
    );

    // Configure Personnel service
    final PersonnelService personnelService = PersonnelService();

    // ignore: close_sinks
    final PersonnelBloc personnelBloc = PersonnelBloc(
      PersonnelRepositoryImpl(
        personnelService,
        units: unitBloc.repo,
        affiliations: affiliationBloc.repo,
        connectivity: connectivityService,
      ),
      affiliationBloc,
      operationBloc,
      controller.bus,
    );

    // Configure Device service
    final DeviceService deviceService = DeviceService(channel);

    // ignore: close_sinks
    final DeviceBloc deviceBloc = DeviceBloc(
      DeviceRepositoryImpl(
        deviceService,
        connectivity: connectivityService,
      ),
      userBloc,
      controller.bus,
    );

    // Configure Tracking service
    final TrackingService trackingService = TrackingService();

    // ignore: close_sinks
    final TrackingBloc trackingBloc = TrackingBloc(
      TrackingRepositoryImpl(
        trackingService,
        connectivity: connectivityService,
      ),
      unitBloc: unitBloc,
      deviceBloc: deviceBloc,
      operationBloc: operationBloc,
      personnelBloc: personnelBloc,
      bus: controller.bus,
    );

    // ignore: close_sinks
    final activityBloc = ActivityBloc(bus: controller.bus);

    final blocs = <Bloc>[
      configBloc,
      userBloc,
      affiliationBloc,
      operationBloc,
      unitBloc,
      personnelBloc,
      deviceBloc,
      trackingBloc,
      activityBloc,
    ];

    // Get all services
    final repoServices = blocs.whereType<ConnectionAwareBloc>().map((bloc) => bloc.repos).fold<Iterable<Service>>(
      <Service>[],
      (services, repos) => List.from(services)
        ..addAll(
          repos.map((repo) => repo.service),
        ),
    ).toList();
    final apiServices = repoServices
        .whereType<ServiceDelegate>()
        .map((service) => service.delegate)
        .whereType<ChopperService>()
        .toList();

    final api = Api(
      httpClient: client,
      baseRestUrl: baseRestUrl,
      users: userRepo,
      services: apiServices,
    );

    return controller._set(
      api: api,
      demo: demo,
      blocs: blocs,
      channel: channel,
      services: [
        ...repoServices,
        // Singletons
        BaseMapService(),
        NavigationService(),
        ConnectivityService(),
      ],
      repos: [
        // Resolve from config
        ...blocs
            .whereType<ConnectionAwareBloc>()
            .map((bloc) => bloc.repos)
            .fold<Iterable<Repository>>(<Repository>[], (all, repos) => List.from(all)..addAll(repos)),
        // Add special cases
        userBloc.repo,
        userBloc.repo.tokens,
      ],
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
      return _build(
            this,
            demo: demo,
            client: client,
          ) !=
          null;
    }
    return false;
  }

  /// Initialize application state
  Future<AppController> init() async {
    if (AppControllerState.Built == _state) {
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
    // 'selected_ouuid' in secure storage
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
    _controller.add(_state = AppControllerState.Initialized);

    // Set app state from user state
    _onUserState(bloc<UserBloc>().state);
  }

  /// Reset application
  Future<void> reset() async {
    // Notify blocs not ready, will show splash screen.
    _controller.add(_state = AppControllerState.Empty);

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
    @required Iterable<Bloc> blocs,
    @required MessageChannel channel,
    @required Iterable<Service> services,
    @required Iterable<Repository> repos,
  }) {
    assert(
      _blocs.isEmpty,
      "_blocs should be empty, forgot to call _unset?",
    );
    assert(
      _repos.isEmpty,
      "_repos should be empty, forgot to call _unset?",
    );
    assert(
      _services.isEmpty,
      "_services should be empty, forgot to call _unset?",
    );

    _demo = demo;
    _channel = channel;

    // Prepare providers
    blocs.forEach((bloc) {
      _blocs[bloc.runtimeType] = bloc;
    });
    repos.forEach((repo) {
      _repos[repo.runtimeType] = repo;
    });
    services.forEach((service) {
      _services[service.runtimeType] = service;
    });

    // Rebuild providers when demo parameters changes
    registerStreamSubscription(bloc<AppConfigBloc>().listen(_onConfigState));

    // Handle changes in user state
    registerStreamSubscription(bloc<UserBloc>().listen(_onUserState));

    // Notify that providers are ready
    _controller.add(_state = AppControllerState.Built);

    return this;
  }

  void _onConfigState(AppConfigState state) async {
    // Only rebuild when in local or ready state
    if (const [
      AppControllerState.Local,
      AppControllerState.Ready,
    ].contains(_state)) {
      if (state.isInitialized() || state.isLoaded() || state.isUpdated()) {
        _rebuild(demo: (state.data as AppConfig).toDemoParams());
      }
    }
  }

  /// List of [AppControllerState]s with [User] data
  List<AppControllerState> get userStates => const [
        AppControllerState.Initialized,
        AppControllerState.Local,
        AppControllerState.Ready,
      ];

  void _onUserState(UserState state) {
    if (state.isPending()) {
      return;
    }
    // Handle legal transitions only
    // 1) Initialized -> Local User (not authenticated), blocks are ready to receive commands
    // 2) Initialized -> Ready User (authenticated), blocks are ready to receive commands
    // 3) Local -> Ready
    // 4) Ready -> Local
    if (userStates.contains(_state)) {
      final isReady = state.isAuthenticated() || state.isUnlocked();
      var next = isReady ? AppControllerState.Ready : AppControllerState.Local;
      if (next != _state) {
        _state = next;
        _controller.add(_state);
      }
    }
    if (isReady) {
      _configureServices(state);
    } else {
      _disposeServices(state);
    }
  }

  void _configureServices(UserState state) {
    _channel.open(
      token: bloc<UserBloc>().repo.token,
      appId: bloc<AppConfigBloc>().config.udid,
      onExpired: () => bloc<UserBloc>().repo.refresh(),
      url: '${Defaults.baseWsUrl}/api/messages/connect',
    );
    // Ensure that token is updated
    if (!LocationService.exists || state.isTokenChanged()) {
      LocationService(
        options: bloc<ActivityBloc>().profile.options,
      ).configure(
        token: bloc<UserBloc>().repo.token,
        duuid: bloc<DeviceBloc>().findThisApp()?.uuid,
      );
    }
  }

  bool get isShared => SecurityMode.shared == bloc<AppConfigBloc>().config?.securityMode;

  void _disposeServices(UserState state) async {
    if (LocationService.exists && state.isUnset()) {
      // Did user share device with other users?
      if (isShared) {
        await LocationService().clear();
      }
      await LocationService().dispose();
    }
    if (_channel?.isOpen == true) {
      _channel?.close();
    }
  }

  void _unset() {
    // Unsubscribe all handlers
    bus.unsubscribeAll();
    channel.unsubscribeAll();

    // Dispose message channel
    channel.dispose();

    // Notify blocs not ready, will show splash screen
    _controller.add(_state = AppControllerState.Empty);

    // Cancel state change subscriptions on current blocs
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();

    // Dispose current blocs
    _blocs.values.forEach((bloc) => bloc.close());
    _blocs.clear();

    // Repos are managed by blocs
    _repos.clear();

    // It is assumed that services are not managed by app-controller
    _services.clear();
  }

  void dispose() {
    _unset();
    _controller.close();
  }
}

enum AppControllerState {
  /// Controller is empty, no blocs available
  Empty,

  /// Controller is built, blocks not ready
  Built,

  /// Required blocs (user, config and affiliations) are initialized
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
