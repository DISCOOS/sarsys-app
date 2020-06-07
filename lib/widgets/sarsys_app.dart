import 'dart:async';

import 'package:SarSys/features/app_config/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/incident/presentation/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/controllers/app_controller.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/page_state.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/map/models/map_widget_state_model.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/screens/change_pin_screen.dart';
import 'package:SarSys/features/device/presentation/screens/device_screen.dart';
import 'package:SarSys/screens/first_setup_screen.dart';
import 'package:SarSys/screens/personnel_screen.dart';
import 'package:SarSys/screens/splash_screen.dart';
import 'package:SarSys/screens/unit_screen.dart';
import 'package:SarSys/screens/map_screen.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:SarSys/features/app_config/presentation/screens/settings_screen.dart';
import 'package:SarSys/screens/unlock_screen.dart';
import 'package:SarSys/screens/user_screen.dart';
import 'package:SarSys/services/navigation_service.dart';
import 'package:SarSys/features/incident/domain/usecases/incident_user_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/widgets/access_checker.dart';
import 'package:SarSys/screens/command_screen.dart';
import 'package:SarSys/features/incident/presentation/screens/incidents_screen.dart';
import 'package:SarSys/screens/login_screen.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/cupertino.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:provider/provider.dart';

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
  final _checkerKey = UniqueKey();

  List<StreamSubscription> _subscriptions = [];

  UserBloc get userBloc => widget.controller.bloc<UserBloc>();
  AppConfigBloc get configBloc => widget.controller.bloc<AppConfigBloc>();
  IncidentBloc get incidentBloc => widget.controller.bloc<IncidentBloc>();
  PersonnelBloc get personnelBloc => widget.controller.bloc<PersonnelBloc>();
  bool get onboarded => configBloc?.config?.onboarded ?? false;
  bool get firstSetup => configBloc?.config?.firstSetup ?? false;
  int get securityLockAfter => configBloc?.config?.securityLockAfter ?? Defaults.securityLockAfter;
  bool get configured => widget.controller.state.index > BlocControllerState.Built.index;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelAll();
    super.dispose();
  }

  void _cancelAll() {
    _subscriptions.forEach((subscription) => subscription.cancel());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    readPageStorageBucket(widget.bucket, context: context);
    _cancelAll();
    _listenForBlocRebuilds();
    _listenForIncidentsLoaded();
  }

  /// Initialize blocs and restart app after blocs are rebuilt
  void _listenForBlocRebuilds() {
    // Cancelled by _cancelAll
    _subscriptions.add(widget.controller.onChange.listen(
      (state) async {
        if (widget.controller.shouldInitialize(state)) {
          // Initialize blocs after rebuild
          await widget.controller.init().catchError(Catcher.reportCheckedError);

          // Restart app to rehydrate with
          // blocs just built and initiated.
          // This will invalidate this
          // SarSysAppState instance
          Phoenix.rebirth(context);
        } else if (widget.controller.shouldAuthenticate(state)) {
          // When user is authenticated
          // IncidentBloc will load
          // incidents from repository
          _listenForIncidentsLoaded();

          // Prompt user to login
          NavigationService().pushReplacementNamed(LoginScreen.ROUTE);
        }
      },
    ));
  }

  /// Reselect incident if previous selected on first [IncidentsLoaded]
  void _listenForIncidentsLoaded() {
    final subscription = widget.controller
        .bloc<IncidentBloc>()
        .firstWhere((state) => state.isLoaded())
        .asStream()
        // User is authenticated (not null)
        // by convention when IncidentsLoaded
        // has been published by IncidentBloc
        .listen((value) => _selectOnLoad(userBloc.user));

    // Cancelled by _cancelAll
    _subscriptions.add(subscription);
  }

  void _selectOnLoad(User user) async {
    final iuuid = await Storage.readUserValue(
      user,
      suffix: IncidentBloc.SELECTED_IUUID_KEY_SUFFIX,
    );
    if (iuuid != null) {
      var route = getPageState<Map>(
        context,
        RouteWriter.STATE,
        defaultValue: {},
      );
      final result = await selectIncident(iuuid);
      if (result.isRight()) {
        route['incident'] = result.toIterable().firstOrNull;
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
      await _lockOnTimeout();
    }
  }

  Future _lockOnTimeout() async {
    if (userBloc.isReady) {
      final heartbeat = userBloc.security.heartbeat;
      if (heartbeat == null || DateTime.now().difference(heartbeat).inMinutes > securityLockAfter) {
        await userBloc.lock();
      }
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
            child: MultiBlocProvider(
              providers: widget.controller.all,
              child: child,
            ),
          ),
        ),
      );

  Route _toRoute(RouteSettings settings) {
    WidgetBuilder builder;

    debugPrint(
      "SarSysApp._toRoute {route: ${settings.name}, configured:$configured, state:${widget.controller.state}}",
    );

    if (!configured) {
      builder = _toUnchecked(SplashScreen());
    } else if (!onboarded) {
      builder = _toUnchecked(OnboardingScreen());
    } else if (!firstSetup) {
      builder = _toUnchecked(FirstSetupScreen());
    } else if (!userBloc.isAuthenticated) {
      builder = _toUnchecked(LoginScreen());
    } else if (!userBloc.isSecured) {
      builder = _toUnchecked(ChangePinScreen());
    } else if (userBloc.isLocked) {
      builder = _toUnchecked(UnlockScreen());
    } else if (userBloc.isReady) {
      builder = _toBuilder(
        settings,
        _toScreen(settings, false),
      );
    } else {
      throw StateError("Unexpected application state");
    }

    return MaterialPageRoute(
      builder: builder,
      settings: settings,
    );
  }

  WidgetBuilder _toBuilder(RouteSettings settings, Widget child) {
    WidgetBuilder builder;
    switch (settings.name) {
      case LoginScreen.ROUTE:
      case OnboardingScreen.ROUTE:
      case FirstSetupScreen.ROUTE:
        builder = _toUnchecked(child);
        break;
      default:
        builder = _toChecked(child);
        break;
    }
    return builder;
  }

  Widget _toScreen(RouteSettings settings, bool persisted) {
    Widget child;
    switch (settings.name) {
      case MapScreen.ROUTE:
        child = _toMapScreen(
          settings: settings,
          incident: widget.controller.bloc<IncidentBloc>().selected,
        );
        break;
      case LoginScreen.ROUTE:
        child = LoginScreen();
        break;
      case ChangePinScreen.ROUTE:
        child = ChangePinScreen(
          popOnClose: toArgument(
            settings,
            'popOnClose',
            defaultValue: false,
          ),
        );
        break;
      case UserScreen.ROUTE_INCIDENT:
        child = UserScreen(tabIndex: UserScreen.TAB_INCIDENT);
        break;
      case UnitScreen.ROUTE:
        child = _toUnitScreen(settings, persisted);
        break;
      case CommandScreen.ROUTE_UNIT_LIST:
        child = CommandScreen(tabIndex: CommandScreen.TAB_UNITS);
        break;
      case DeviceScreen.ROUTE:
        child = _toDeviceScreen(settings, persisted);
        break;
      case CommandScreen.ROUTE_MISSION_LIST:
        child = CommandScreen(tabIndex: CommandScreen.TAB_MISSIONS);
        break;
      case CommandScreen.ROUTE_DEVICE_LIST:
        child = CommandScreen(tabIndex: CommandScreen.TAB_DEVICES);
        break;
      case PersonnelScreen.ROUTE:
        child = _toPersonnelScreen(settings, persisted);
        break;
      case CommandScreen.ROUTE_PERSONNEL_LIST:
        child = CommandScreen(tabIndex: CommandScreen.TAB_PERSONNEL);
        break;
      case UserScreen.ROUTE_STATUS:
        child = UserScreen(tabIndex: UserScreen.TAB_STATUS);
        break;
      case UserScreen.ROUTE_UNIT:
        child = UserScreen(tabIndex: UserScreen.TAB_UNIT);
        break;
      case UserScreen.ROUTE_HISTORY:
        child = UserScreen(tabIndex: UserScreen.TAB_HISTORY);
        break;
      case SettingsScreen.ROUTE:
        child = SettingsScreen();
        break;
      case OnboardingScreen.ROUTE:
        child = OnboardingScreen();
        break;
      case FirstSetupScreen.ROUTE:
        child = FirstSetupScreen();
        break;
      case IncidentsScreen.ROUTE:
      default:
        child = IncidentsScreen();
        break;
    }
    return child;
  }

  T toArgument<T>(RouteSettings settings, String path, {T defaultValue}) {
    if (settings.arguments is Map) {
      final arguments = settings.arguments as Map<String, dynamic>;
      return arguments.hasPath(path) ? arguments.elementAt(path) as T : defaultValue;
    }
    return defaultValue;
  }

  WidgetBuilder _toChecked(Widget child) {
    return _toUnchecked(AccessChecker(
      key: _checkerKey,
      child: child,
      configBloc: widget.controller.bloc<AppConfigBloc>(),
    ));
  }

  WidgetBuilder _toUnchecked(Widget child) {
    return (context) => PageStorage(
        // widget.bucket will be uses
        // instead for of the PageStorageBucket
        // instance in each ModalRoute,
        // effectively sharing the bucket
        // across all pages shown with
        // modal routes
        bucket: widget.bucket,
        child: child);
  }

  Widget _toMapScreen({RouteSettings settings, Incident incident}) {
    final arguments = settings?.arguments;
    if (arguments is Map) {
      return MapScreen(
        center: arguments["center"],
        incident: arguments["incident"] ?? incident,
        fitBounds: arguments["fitBounds"],
        fitBoundOptions: arguments["fitBoundOptions"],
      );
    }
    if (incident != null) {
      var model = getPageState<MapWidgetStateModel>(
        widget.navigatorKey.currentState.context,
        MapWidgetState.STATE,
      );
      if (model?.incident != incident.uuid) {
        final ipp = incident.ipp != null ? toLatLng(incident.ipp.point) : null;
        final meetup = incident.meetup != null ? toLatLng(incident.meetup.point) : null;
        final fitBounds = LatLngBounds(ipp, meetup);
        return MapScreen(
          incident: incident,
          fitBounds: fitBounds,
        );
      }
    }
    return MapScreen();
  }

  Widget _toUnitScreen(RouteSettings settings, bool persisted) {
    var unit;
    if (settings?.arguments is Unit) {
      unit = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      unit = units[route['data']];
    }
    return unit == null || persisted ? CommandScreen(tabIndex: CommandScreen.TAB_UNITS) : UnitScreen(unit: unit);
  }

  Map<String, Unit> get units => widget.controller.bloc<UnitBloc>().units;

  Widget _toPersonnelScreen(RouteSettings settings, bool persisted) {
    var personnel;
    if (settings?.arguments is Personnel) {
      personnel = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      personnel = personnels[route['data']];
    }
    return personnel == null || persisted
        ? CommandScreen(tabIndex: CommandScreen.TAB_PERSONNEL)
        : PersonnelScreen(personnel: personnel);
  }

  Map<String, Personnel> get personnels => widget.controller.bloc<PersonnelBloc>().personnels;

  Widget _toDeviceScreen(RouteSettings settings, bool persisted) {
    var device;
    if (settings?.arguments is Device) {
      device = settings?.arguments;
    } else if (settings?.arguments is Map) {
      final Map<String, dynamic> route = Map.from(settings?.arguments);
      device = devices[route['data']];
    }
    return device == null || persisted
        ? CommandScreen(tabIndex: CommandScreen.TAB_DEVICES)
        : DeviceScreen(device: device);
  }

  Map<String, Device> get devices => widget.controller.bloc<DeviceBloc>().devices;

  Widget _toHome() {
    Widget child;

    debugPrint(
      "SarSysApp._toHome {configured:$configured, state:${widget.controller.state}}",
    );

    if (!configured) {
      child = SplashScreen();
    } else if (!onboarded) {
      child = OnboardingScreen();
    } else if (!firstSetup) {
      child = FirstSetupScreen();
    } else if (!userBloc.isAuthenticated) {
      child = LoginScreen();
    } else if (!userBloc.isSecured) {
      child = ChangePinScreen();
    } else if (userBloc.isLocked) {
      child = UnlockScreen();
    } else if (userBloc.isReady) {
      child = _toPreviousRoute(
          orElse: _toMapScreen(
        incident: incidentBloc.selected,
      ));
    } else {
      throw StateError("Unexpected state");
    }
    return PageStorage(
      child: child,
      bucket: widget.bucket,
    );
  }

  Widget _toPreviousRoute({@required Widget orElse}) {
    var child;
    var state = getPageState<Map>(context, RouteWriter.STATE);
    if (state != null) {
      bool isUnset = incidentBloc.isUnselected;
      child = _toScreen(
        RouteSettings(
          name: isUnset ? 'incidents' : state[RouteWriter.FIELD_NAME],
          arguments: isUnset ? null : state,
        ),
        true,
      );
    }
    child = AccessChecker(
      key: _checkerKey,
      child: child ?? orElse,
      configBloc: configBloc,
    );
    return child;
  }
}
