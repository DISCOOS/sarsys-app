import 'dart:async';

import 'package:catcher/core/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:http/http.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/data/streams.dart';
import 'package:SarSys/core/presentation/screens/onboarding_screen.dart';
import 'package:SarSys/core/presentation/screens/splash_screen.dart';
import 'package:SarSys/features/tracking/data/repositories/position_list_repository_impl.dart';
import 'package:SarSys/features/mapping/presentation/screens/map_screen.dart';
import 'package:SarSys/features/settings/presentation/screens/first_setup_screen.dart';
import 'package:SarSys/features/tracking/data/services/tracking_source_service.dart';
import 'package:SarSys/features/tracking/data/services/position_list_service.dart';
import 'package:SarSys/features/tracking/domain/repositories/position_list_repository.dart';
import 'package:SarSys/features/user/presentation/screens/change_pin_screen.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
import 'package:SarSys/features/user/presentation/screens/unlock_screen.dart';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/core/presentation/blocs/mixins.dart';
import 'package:SarSys/core/data/services/service.dart';
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
import 'domain/repository.dart';
import 'domain/stateful_repository.dart';

class AppController {
  AppController._(
    this.client,
  );

  final Client client;
  final AppBlocDelegate delegate = AppBlocDelegate(BlocEventBus());

  BlocEventBus get bus => delegate.bus;

  /// Get SARSys api implementation
  Api get api => _api;
  Api _api;

  /// [MessageChannel] instance communicating
  /// with the backend using web-socket
  MessageChannel get channel => _channel;
  MessageChannel _channel;

  /// Get current [state] of [AppController]
  AppState get state => _state;
  AppState _state = AppState.Empty;

  bool get isOffline => !isOnline;
  bool get isOnline => ConnectivityService().isOnline;

  bool get isHeadless => !NavigationService.isReady;

  bool get isEmpty => state == AppState.Empty;
  bool get isBuilt => state.index >= AppState.Built.index;
  bool get isConfigured => state.index >= AppState.Configured.index;
  bool get isAnonymous => state.index <= AppState.Anonymous.index;
  bool get isAuthenticated => state.index >= AppState.Authenticated.index;
  bool get isSecured => isAuthenticated && bloc<UserBloc>().isSecured;
  bool get isLocked => !isSecured || bloc<UserBloc>().isLocked;
  bool get isLoading => isAuthenticated && !isReady || _state == AppState.Loading;
  bool get isReady => state == AppState.Ready;

  bool get isOnboarded => bloc<AppConfigBloc>()?.config?.onboarded ?? false;
  bool get isFirstSetup => bloc<AppConfigBloc>()?.config?.firstSetup ?? false;

  bool shouldConfigure(AppState state) => state == AppState.Built;
  bool shouldRoute(AppState state) => !isHeadless && state == AppState.Ready && !isLocked;
  bool shouldChangePin(AppState state) => !isHeadless && state == AppState.Authenticated && !isSecured;
  bool shouldUnlock(AppState state) => !isHeadless && state == AppState.Authenticated && isAuthenticated && isLocked;
  bool shouldLogin(AppState state) => !isHeadless && state == AppState.Anonymous && isConfigured && !isAuthenticated;

  /// Subscriptions released on [close]
  final List<StreamSubscription> _subscriptions = [];
  List<StreamSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  StreamSubscription registerStreamSubscription(StreamSubscription subscription) {
    _subscriptions.add(
      subscription,
    );
    return subscription;
  }

  StreamController<AppState> _controller = StreamController.broadcast();
  Stream<AppState> get onChanged => _controller.stream;

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
  factory AppController.build(Client client) {
    return _build(
      AppController._(client),
      client: client,
    );
  }

  static AppController _build(
    AppController controller, {
    @required Client client,
  }) {
    final baseRestUrl = Defaults.baseRestUrl;
    final assetConfig = 'assets/config/app_config.json';

    // --------------
    // Build services
    // --------------

    final configService = AppConfigService();
    final connectivityService = ConnectivityService();
    final userService = UserIdentityService(client, connectivityService);

    // ------------------
    // Build repositories
    // ------------------
    final authRepo = AuthTokenRepository();
    final userRepo = UserRepository(
      service: userService,
      tokens: authRepo,
    );
    final configRepo = AppConfigRepositoryImpl(
      APP_CONFIG_VERSION,
      assets: assetConfig,
      service: configService,
      connectivity: connectivityService,
    );

    // ---------------------
    // Build message channel
    // ---------------------
    final channel = MessageChannel(userRepo);

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

    // Configure Tracking services and repos
    final TrackingService trackingService = TrackingService(TrackingSourceService());
    final PositionListService positionListService = PositionListService();
    final PositionListRepository trackRepo = PositionListRepositoryImpl(
      positionListService,
      connectivity: connectivityService,
    );

    // ignore: close_sinks
    final TrackingBloc trackingBloc = TrackingBloc(
      TrackingRepositoryImpl(
        trackingService,
        tracks: trackRepo,
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
    final repoServices = blocs
        .whereType<ConnectionAwareBloc>()
        .map((bloc) => bloc.repos.whereType<StatefulRepository>())
        .fold<Iterable<JsonService>>(
      [positionListService.delegate],
      (services, repos) => List.from(services)
        ..addAll(
          repos.map((repo) => repo.service.delegate),
        ),
    ).toList();
    final apiServices = repoServices.whereType<JsonService>().toList();

    final api = Api(
      httpClient: client,
      baseRestUrl: baseRestUrl,
      users: userRepo,
      services: apiServices,
    );

    return controller._set(
      api: api,
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

  /// Initialize application state
  Future<AppController> configure() async {
    if (isBuilt) {
      await _configure();
    }
    return this;
  }

  Future<void> _configure() async {
    try {
      if (!isConfigured) {
        //
        // If 'current_user_id' in
        // secure storage exists in bloc
        // and access token is valid, this
        // will load operations for given
        // user. If any operation matches
        // 'selected_ouuid' in secure storage
        // it will be selected as current
        // operation.
        //
        await bloc<UserBloc>().load();

        // Wait for config to become available
        await waitThroughStateWithData<AppConfigState, AppConfig>(
          bus,
          fail: true,
          map: (state) => state.data,
          timeout: Duration(minutes: 1),
          test: (state) => state.data is AppConfig,
        );

        // Allow _onUserChange to transition to next legal state
        _setState(AppState.Configured);

        // Set app state from user state
        _onUserState(bloc<UserBloc>().state);

        // Toggles between Anonymous and Authenticated states
        registerStreamSubscription(bloc<UserBloc>().listen(_onUserState));

        // Toggles between loading and ready state
        registerStreamSubscription(bloc<AffiliationBloc>().listen(_onModalState));
      }
    } catch (e, stackTrace) {
      Catcher.reportCheckedError(e, stackTrace);
    }
  }

  void _setState(AppState state) {
    if (_state != state) {
      _controller.add(state);
      final init = _state == AppState.Empty;
      _handle(_state = state, init);
    }
  }

  Future _handle(AppState state, bool init) async {
    try {
      debugPrint('AppController._handle(state: $state)');
      if (shouldLogin(state)) {
        // Prompt user to login
        NavigationService().pushReplacementNamed(
          LoginScreen.ROUTE,
        );
      } else if (shouldChangePin(state)) {
        // Prompt user to unload
        NavigationService().pushReplacementNamed(
          ChangePinScreen.ROUTE,
        );
      } else if (shouldUnlock(state)) {
        // Prompt user to unload
        NavigationService().pushReplacementNamed(
          UnlockScreen.ROUTE,
        );
      } else if (shouldRoute(state)) {
        final route = inferRouteName(
          defaultName: MapScreen.ROUTE,
        );
        NavigationService().pushReplacementNamed(route);
      }
    } catch (e, stackTrace) {
      Catcher.reportCheckedError(e, stackTrace);
    }
  }

  String inferRouteName({RouteSettings settings, String defaultName}) {
    var route;
    if (!isConfigured) {
      route = SplashScreen.ROUTE;
    } else if (!isOnboarded) {
      route = OnboardingScreen.ROUTE;
    } else if (!isFirstSetup) {
      route = FirstSetupScreen.ROUTE;
    } else if (!isAuthenticated) {
      route = LoginScreen.ROUTE;
    } else if (!isSecured) {
      route = ChangePinScreen.ROUTE;
    } else if (isLocked) {
      route = UnlockScreen.ROUTE;
    } else if (isLoading) {
      route = SplashScreen.ROUTE;
    } else if (isReady) {
      route = settings?.name ?? defaultName;
    } else {
      throw StateError("Unexpected application state");
    }
    return route;
  }

  /// Reset application
  Future<void> reset() async {
    if (!isHeadless) {
      NavigationService().pushReplacementNamed(
        SplashScreen.ROUTE,
        arguments: 'Nullstiller...',
      );
    }

    // Initialize logout and delete user
    await bloc<UserBloc>().logout(delete: true);

    // Close
    _unset();

    // Destroy all data
    await Storage.destroy(reinitialize: true);

    // Rebuild blocs
    _build(this, client: client);

    // Configure blocs after rebuild
    await configure();

    // Restart app to rehydrate with
    // blocs just built and initiated.
    // This will invalidate this
    // SarSysAppState instance
    Phoenix.rebirth(
      NavigationService().context,
    );
  }

  AppController _set({
    @required Api api,
    @required Iterable<Bloc> blocs,
    @required MessageChannel channel,
    @required Iterable<Repository> repos,
    @required Iterable<Service> services,
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

    // Notify that blocs are built and ready for commands
    _setState(AppState.Built);

    return this;
  }

  void _onUserState(UserState state) {
    if (state.isPending()) {
      return;
    }
    debugPrint('AppController._onUserState(state: ${state.runtimeType})');
    // Handle legal transitions only
    // 1) Configured -> Anonymous (not authenticated)
    // 2) Anonymous -> Authenticated (when user is authenticated or token is refreshed)
    // 3) Authenticated -> Anonymous (when token expires or user is logged out)
    if (isConfigured) {
      _setState(bloc<UserBloc>().isAuthenticated
          // Application require new pin
          ? (isReady ? AppState.Ready : AppState.Authenticated)
          // Application require login
          : AppState.Anonymous);
    }
    if (isAuthenticated) {
      if (state.shouldLoad()) {
        _configureServices(state);
      }
    } else {
      _disposeServices(state);
    }
  }

  void _onModalState(AffiliationState state) async {
    debugPrint('AppController._onModalState(state: ${state.runtimeType}{isRemote: ${state.isRemote}})');
    if (isAuthenticated) {
      switch (state.runtimeType) {
        case AffiliationsLoaded:
        case AffiliationsFetched:
          if (isOnline) {
            await bloc<AffiliationBloc>().onLoadedAsync();
          }
          _setState(AppState.Ready);
          break;
        case AffiliationsUnloaded:
          _setState(AppState.Loading);
          break;
      }
    }
  }

  void _configureServices(UserState state) {
    _channel.open(
      appId: bloc<AppConfigBloc>().config.udid,
      url: '${Defaults.baseWsUrl}/api/messages/connect',
    );
    // Ensure that token is updated
    if (!LocationService.exists || state.isTokenRefreshed()) {
      LocationService(
        options: bloc<ActivityBloc>().profile.options,
      ).configure(
        token: bloc<UserBloc>().repo.token,
        duuid: bloc<DeviceBloc>().findThisApp()?.uuid,
        debug: bloc<AppConfigBloc>().config?.locationDebug,
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
    _setState(AppState.Empty);

    // Cancel state change subscriptions on current blocs
    _subscriptions.forEach(
      (subscription) => subscription.cancel(),
    );
    _subscriptions.clear();

    // Dispose current blocs
    _blocs.values.forEach((bloc) => bloc.close());
    _blocs.clear();

    // Repos are managed by blocs
    _repos.clear();

    // It is assumed that services are not managed by app-controller
    _services.clear();
  }

  int get securityLockAfter => bloc<AppConfigBloc>()?.config?.securityLockAfter ?? Defaults.securityLockAfter;

  Future<void> setLockTimeout() async {
    if (bloc<UserBloc>().isReady) {
      final heartbeat = bloc<UserBloc>().security.heartbeat;
      if (heartbeat == null || DateTime.now().difference(heartbeat).inMinutes > securityLockAfter) {
        await bloc<UserBloc>().lock();
      }
    }
  }

  void dispose() {
    _unset();
    _controller.close();
  }

  @override
  String toString() {
    return '$runtimeType{\n'
        '  state: $_state,\n'
        '  isEmpty: $isEmpty,\n'
        '  isBuilt: $isBuilt,\n'
        '  isReady: $isReady,\n'
        '  isLocked: $isLocked,\n'
        '  isLoading: $isLoading,\n'
        '  isSecured: $isSecured,\n'
        '  isAnonymous: $isAnonymous,\n'
        '  isConfigured: $isConfigured,\n'
        '  isAuthenticated: $isAuthenticated\n'
        '}';
  }
}

enum AppState {
  /// Controller is empty, no blocs available
  Empty,

  /// Controller is built, blocks not ready
  Built,

  /// Required blocs (user, config and affiliations) are initialized
  Configured,

  /// No user (not authenticated).
  ///
  /// > Application should force login
  ///
  /// Blocks are ready to receive commands
  Anonymous,

  /// User authenticated
  ///
  /// > Application should check if user is secured
  ///
  /// Blocks are ready to receive commands
  Authenticated,

  /// Loading required blocs (user, config and affiliations)
  ///
  /// > Application should block user interaction
  ///
  /// Blocks are ready to receive commands
  Loading,

  /// Application is ready for user interaction
  ///
  /// Blocks are ready to receive commands
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
