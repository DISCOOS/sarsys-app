import 'dart:async';

import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:provider/provider.dart';

import 'package:SarSys/core/data/services/provider.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/core/app_controller.dart';
import 'package:SarSys/core/permission_controller.dart';
import 'package:SarSys/core/page_state.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/mapping/presentation/models/map_widget_state_model.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/presentation/screens/change_pin_screen.dart';
import 'package:SarSys/features/device/presentation/screens/device_screen.dart';
import 'package:SarSys/features/settings/presentation/screens/first_setup_screen.dart';
import 'package:SarSys/features/personnel/presentation/screens/personnel_screen.dart';
import 'package:SarSys/core/presentation/screens/splash_screen.dart';
import 'package:SarSys/features/unit/presentation/screens/unit_screen.dart';
import 'package:SarSys/features/mapping/presentation/screens/map_screen.dart';
import 'package:SarSys/core/presentation/screens/onboarding_screen.dart';
import 'package:SarSys/features/settings/presentation/screens/settings_screen.dart';
import 'package:SarSys/features/user/presentation/screens/unlock_screen.dart';
import 'package:SarSys/features/user/presentation/screens/user_screen.dart';
import 'package:SarSys/core/data/services/navigation_service.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/presentation/screens/screen.dart';
import 'package:SarSys/features/operation/presentation/screens/command_screen.dart';
import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
import 'package:SarSys/core/extensions.dart';

class SarSysApp extends StatefulWidget {
  final PageStorageBucket bucket;
  final AppController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  const SarSysApp({
    Key key,
    @required this.navigatorKey,
    @required this.controller,
    @required this.bucket,
  }) : super(key: key);

  @override
  _SarSysAppState createState() => _SarSysAppState();
}

class _SarSysAppState extends State<SarSysApp> with WidgetsBindingObserver {
  List<StreamSubscription> _subscriptions = [];

  AppConfigBloc get configBloc => widget.controller.bloc<AppConfigBloc>();
  OperationBloc get operationBloc => widget.controller.bloc<OperationBloc>();
  PersonnelBloc get personnelBloc => widget.controller.bloc<PersonnelBloc>();

  bool get isConfigured => widget.controller.isConfigured;
  bool get isAnonymous => widget.controller.isAnonymous;
  bool get isAuthenticated => widget.controller.isAuthenticated;
  bool get isSecured => widget.controller.isSecured;
  bool get isLocked => widget.controller.isLocked;
  bool get isLoading => widget.controller.isLoading;

  bool get isReady => widget.controller.isReady;

  bool get isOnboarded => configBloc?.config?.onboarded ?? false;
  bool get isFirstSetup => configBloc?.config?.firstSetup ?? false;

  int get securityLockAfter => configBloc?.config?.securityLockAfter ?? Defaults.securityLockAfter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForBlocRebuilds();
    _listenForOperationsLoaded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelAll();
    super.dispose();
  }

  void _cancelAll() {
    _subscriptions.forEach(
      (subscription) => subscription.cancel(),
    );
    _subscriptions.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    readPageStorageBucket(widget.bucket, context: context);
  }

  /// Initialize blocs and restart app after blocs are rebuilt
  void _listenForBlocRebuilds() {
    // Cancelled by _cancelAll
    _subscriptions.add(
      widget.controller.onChanged.listen(_handle),
    );
  }

  Future _handle(AppState state) async {
    if (widget.controller.shouldConfigure(state)) {
      // Configure blocs after rebuild
      await widget.controller.configure().catchError(Catcher.reportCheckedError);

      // Restart app to rehydrate with
      // blocs just built and initiated.
      // This will invalidate this
      // SarSysAppState instance
      Phoenix.rebirth(context);
    } else if (widget.controller.shouldLogin(state)) {
      _listenForOperationsLoaded();

      // Prompt user to login
      NavigationService().pushReplacementNamed(
        LoginScreen.ROUTE,
      );
    } else if (widget.controller.shouldChangePin(state)) {
      _listenForOperationsLoaded();

      // Prompt user to unload
      NavigationService().pushReplacementNamed(
        ChangePinScreen.ROUTE,
      );
    } else if (widget.controller.shouldUnlock(state)) {
      _listenForOperationsLoaded();

      // Prompt user to unload
      NavigationService().pushReplacementNamed(
        UnlockScreen.ROUTE,
      );
    } else if (widget.controller.shouldRoute(state)) {
      final route = _inferRouteName(
        defaultName: MapScreen.ROUTE,
      );
      NavigationService().pushReplacementNamed(route);
    }
  }

  /// Reselect [Operation] if previous selected
  /// on first [OperationsLoaded].
  void _listenForOperationsLoaded() {
    final subscription = widget.controller
        .bloc<OperationBloc>()
        .firstWhere((state) => state.isLoaded())
        .asStream()
        // User is authenticated (not null)
        // by convention when OperationsLoaded
        // has been published by OperationBloc
        .listen(
          (value) => _selectOnLoad(widget.controller.bloc<UserBloc>().user),
        );

    // Cancelled by _cancelAll
    _subscriptions.add(subscription);
  }

  void _selectOnLoad(User user) async {
    final ouuid = user != null
        ? await Storage.readUserValue(
            user,
            suffix: OperationBloc.SELECTED_KEY_SUFFIX,
          )
        : null;
    if (ouuid != null) {
      var route = getPageState<Map>(
        context,
        RouteWriter.STATE,
        defaultValue: {},
      );
      final result = await selectOperation(ouuid);
      if (result.isRight()) {
        route[UserScreen.ROUTE_OPERATION] = result.toIterable().firstOrNull;
        NavigationService().pushReplacementNamed(
          route.elementAt(RouteWriter.FIELD_NAME) ?? MapScreen.ROUTE,
          arguments: route,
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      writePageStorageBucket(widget.bucket);
    } else if (state == AppLifecycleState.resumed) {
      readPageStorageBucket(widget.bucket);
      await widget.controller.setLockTimeout();
    }
  }

  @override
  Widget build(BuildContext context) {
    // We need to build with providers
    // above material app for Navigator.push
    // to work appropriately together with
    // BlocProvider which descendants
    // depends on.
    //
    // See https://stackoverflow.com/a/58370561
    //
    return _buildWithProviders(
        context: context,
        child: MaterialApp(
          navigatorKey: widget.navigatorKey,
          navigatorObservers: [RouteWriter.observer],
          debugShowCheckedModeBanner: false,
          title: 'SarSys',
          theme: ThemeData(
            primaryColor: Color(0xFF0d2149),
            buttonTheme: ButtonThemeData(
              height: 36.0,
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          home: _toHome(),
          onGenerateRoute: (settings) => _toRoute(
            settings,
          ),
          localizationsDelegates: [
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            const Locale('en', 'US'), // English
            const Locale('nb', 'NO'), // Norwegian Bokmål
          ],
        ));
  }

  Widget _buildWithProviders({
    @required BuildContext context,
    @required Widget child,
  }) =>
      Provider<PermissionController>(
        // Lazily create when first asked for it
        create: (BuildContext context) => PermissionController(
          configBloc: configBloc,
        ),
        child: Provider.value(
          value: widget.controller.client,
          child: Provider.value(
            value: widget.controller,
            child: MultiServiceProvider(
              providers: widget.controller.services,
              child: MultiRepositoryProvider(
                providers: widget.controller.repos,
                child: MultiBlocProvider(
                  providers: widget.controller.blocs,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _toHome() {
    debugPrint(
      "SarSysApp._toHome(controller:${widget.controller})",
    );
    final route = _inferRouteName();
    final screen = route != null
        ? _toScreen(route, persisted: true)
        : _toPreviousRoute(
            orElse: _toMapScreen(
              operation: operationBloc.selected,
            ),
          );
    return PageStorage(
      child: screen,
      bucket: widget.bucket,
    );
  }

  Route _toRoute(RouteSettings settings) {
    String route;

    debugPrint(
      "SarSysApp._toRoute(route: ${settings.name}, controller: ${widget.controller.state})",
    );

    route = _inferRouteName(settings: settings);

    final screen = _toScreen(
      route,
      persisted: true,
      arguments: settings.arguments,
    );
    return MaterialPageRoute(
      settings: settings,
      builder: _buildWithStorage(screen),
    );
  }

  String _inferRouteName({RouteSettings settings, String defaultName}) {
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
      route = settings?.name ?? defaultName ?? _toPreviousRouteName();
    } else {
      throw StateError("Unexpected application state");
    }
    return route;
  }

  Widget _toScreen(
    String name, {
    Object arguments,
    bool persisted = false,
  }) {
    Widget screen;

    switch (name) {
      case SplashScreen.ROUTE:
        screen = SplashScreen(
          message: arguments is String ? arguments : (isConfigured ? 'Laster data...' : 'Konfigurerer...'),
        );
        break;
      case LoginScreen.ROUTE:
        screen = LoginScreen(
          returnTo: _toPreviousRouteName(),
        );
        break;
      case UnlockScreen.ROUTE:
        screen = UnlockScreen(
          popOnClose: toArgument(
            arguments,
            'popOnClose',
            defaultValue: false,
          ),
          returnTo: _toPreviousRouteName(),
        );
        break;
      case ChangePinScreen.ROUTE:
        screen = ChangePinScreen(
          popOnClose: toArgument(
            arguments,
            'popOnClose',
            defaultValue: false,
          ),
          returnTo: _toPreviousRouteName(),
        );
        break;
      case MapScreen.ROUTE:
        screen = _toMapScreen(
          arguments: arguments,
          operation: widget.controller.bloc<OperationBloc>().selected,
        );
        break;
      case UserScreen.ROUTE_OPERATION:
        screen = UserScreen(tabIndex: UserScreen.TAB_OPERATION);
        break;
      case UnitScreen.ROUTE:
        screen = _toUnitScreen(arguments, persisted);
        break;
      case CommandScreen.ROUTE_UNIT_LIST:
        screen = CommandScreen(tabIndex: CommandScreen.TAB_UNITS);
        break;
      case DeviceScreen.ROUTE:
        screen = _toDeviceScreen(arguments, persisted);
        break;
      case CommandScreen.ROUTE_MISSION_LIST:
        screen = CommandScreen(tabIndex: CommandScreen.TAB_MISSIONS);
        break;
      case CommandScreen.ROUTE_DEVICE_LIST:
        screen = CommandScreen(tabIndex: CommandScreen.TAB_DEVICES);
        break;
      case PersonnelScreen.ROUTE:
        screen = _toPersonnelScreen(arguments, persisted);
        break;
      case CommandScreen.ROUTE_PERSONNEL_LIST:
        screen = CommandScreen(tabIndex: CommandScreen.TAB_PERSONNEL);
        break;
      case UserScreen.ROUTE_PROFILE:
        screen = UserScreen(tabIndex: UserScreen.TAB_PROFILE);
        break;
      case UserScreen.ROUTE_UNIT:
        screen = UserScreen(tabIndex: UserScreen.TAB_UNIT);
        break;
      case UserScreen.ROUTE_OPERATION:
        screen = UserScreen(tabIndex: UserScreen.TAB_OPERATION);
        break;
      case UserScreen.ROUTE_HISTORY:
        screen = UserScreen(tabIndex: UserScreen.TAB_HISTORY);
        break;
      case SettingsScreen.ROUTE:
        screen = SettingsScreen();
        break;
      case OnboardingScreen.ROUTE:
        screen = OnboardingScreen();
        break;
      case FirstSetupScreen.ROUTE:
        screen = FirstSetupScreen();
        break;
      case OperationsScreen.ROUTE:
      default:
        screen = OperationsScreen();
        break;
    }
    return screen;
  }

  T toArgument<T>(Object arguments, String path, {T defaultValue}) {
    if (arguments is Map) {
      final map = arguments as Map<String, dynamic>;
      return map.hasPath(path) ? arguments.elementAt<T>(path) : defaultValue;
    }
    return defaultValue;
  }

  WidgetBuilder _buildWithStorage(Widget child) {
    return (context) => PageStorage(
          // widget.bucket will be uses
          // instead for of the PageStorageBucket
          // instance in each ModalRoute,
          // effectively sharing the bucket
          // across all pages shown with
          // modal routes
          bucket: widget.bucket,
          child: child,
        );
  }

  Widget _toMapScreen({Object arguments, Operation operation}) {
    if (arguments is Map) {
      return MapScreen(
        center: arguments["center"],
        operation: arguments["operation"] ?? operation,
        fitBounds: arguments["fitBounds"],
        fitBoundOptions: arguments["fitBoundOptions"],
      );
    }
    if (operation != null) {
      var model = getPageState<MapWidgetStateModel>(
        widget.navigatorKey.currentState.context,
        MapWidgetState.STATE,
      );
      if (model?.ouuid != operation.uuid) {
        final ipp = operation.ipp != null ? toLatLng(operation.ipp.point) : null;
        final meetup = operation.meetup != null ? toLatLng(operation.meetup.point) : null;
        final fitBounds = LatLngBounds(ipp, meetup);
        return MapScreen(
          operation: operation,
          fitBounds: fitBounds,
        );
      }
    }
    return MapScreen();
  }

  Widget _toUnitScreen(Object arguments, bool persisted) {
    var unit;
    if (arguments is Unit) {
      unit = arguments;
    } else if (arguments is Map) {
      final Map<String, dynamic> route = Map.from(arguments);
      unit = units[route['data']];
    }
    return unit == null || persisted ? CommandScreen(tabIndex: CommandScreen.TAB_UNITS) : UnitScreen(unit: unit);
  }

  Map<String, Unit> get units => widget.controller.bloc<UnitBloc>().units;

  Widget _toPersonnelScreen(Object arguments, bool persisted) {
    var personnel;
    if (arguments is Personnel) {
      personnel = arguments;
    } else if (arguments is Map) {
      final Map<String, dynamic> route = Map.from(arguments);
      personnel = personnels[route['data']];
    }
    return personnel == null || persisted
        ? CommandScreen(tabIndex: CommandScreen.TAB_PERSONNEL)
        : PersonnelScreen(personnel: personnel);
  }

  Map<String, Personnel> get personnels => widget.controller.bloc<PersonnelBloc>().repo.map;

  Widget _toDeviceScreen(Object arguments, bool persisted) {
    var device;
    if (arguments is Device) {
      device = arguments;
    } else if (arguments is Map) {
      final Map<String, dynamic> route = Map.from(arguments);
      device = devices[route['data']];
    }
    return device == null || persisted
        ? CommandScreen(tabIndex: CommandScreen.TAB_DEVICES)
        : DeviceScreen(device: device);
  }

  Map<String, Device> get devices => widget.controller.bloc<DeviceBloc>().repo.map;

  Widget _toPreviousRoute({@required Widget orElse}) {
    var child;
    var state = getPageState<Map>(context, RouteWriter.STATE);
    if (state != null) {
      bool isUnset = operationBloc.isUnselected || personnelBloc.findUser().isEmpty;
      child = _toScreen(
        isUnset ? OperationsScreen.ROUTE : state[RouteWriter.FIELD_NAME],
        arguments: isUnset ? null : state,
        persisted: true,
      );
    }
    return child ?? orElse;
  }

  String _toPreviousRouteName() {
    var state = getPageState<Map>(context, RouteWriter.STATE);
    return _toDefaultRouteName(state?.elementAt(RouteWriter.FIELD_NAME));
  }

  String _toDefaultRouteName(String name) => name ?? OperationsScreen.ROUTE;
}
