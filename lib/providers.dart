import 'package:http/http.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/mock/app_config.dart';
import 'package:SarSys/mock/devices.dart';
import 'package:SarSys/mock/incidents.dart';
import 'package:SarSys/mock/tracking.dart';
import 'package:SarSys/mock/units.dart';
import 'package:SarSys/mock/users.dart';

import 'package:SarSys/utils/defaults.dart';

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

class Providers {
  final BlocProvider<AppConfigBloc> configProvider;
  final BlocProvider<UserBloc> userProvider;
  final BlocProvider<IncidentBloc> incidentProvider;
  final BlocProvider<UnitBloc> unitProvider;
  final BlocProvider<DeviceBloc> deviceProvider;
  final BlocProvider<TrackingBloc> trackingProvider;

  List<BlocProvider> get all => [
        configProvider,
        userProvider,
        incidentProvider,
        unitProvider,
        deviceProvider,
        trackingProvider,
      ];

  Providers._internal(
    AppConfigBloc configBloc,
    UserBloc userBloc,
    IncidentBloc incidentBloc,
    UnitBloc unitBloc,
    DeviceBloc deviceBloc,
    TrackingBloc trackingBloc,
  )   : this.configProvider = BlocProvider<AppConfigBloc>(bloc: configBloc),
        this.userProvider = BlocProvider<UserBloc>(bloc: userBloc),
        this.incidentProvider = BlocProvider<IncidentBloc>(bloc: incidentBloc),
        this.unitProvider = BlocProvider<UnitBloc>(bloc: unitBloc),
        this.deviceProvider = BlocProvider<DeviceBloc>(bloc: deviceBloc),
        this.trackingProvider = BlocProvider<TrackingBloc>(bloc: trackingBloc);

  /// Create providers for mocking
  factory Providers.build(Client client, {bool mock = false}) {
    final baseUrl = Defaults.baseUrl;
    final assetConfig = 'assets/config/app_config.json';
    final AppConfigService configService = !mock
        ? AppConfigService(assetConfig, '$baseUrl/api/app-config', client)
        : AppConfigServiceMock.build(assetConfig, '$baseUrl/api', client);
    final AppConfigBloc configBloc = AppConfigBloc(configService);

    // Configure user service
    final UserService userService = !mock ? UserService('$baseUrl/auth/login', client) : UserServiceMock.buildAny();
    final UserBloc userBloc = UserBloc(userService);

    // Configure Incident service
    final IncidentService incidentService =
        !mock ? IncidentService('$baseUrl/api/incidents', client) : IncidentServiceMock.build(userService, 2, "T123");
    final IncidentBloc incidentBloc = IncidentBloc(incidentService);

    // Configure Unit service
    final UnitService unitService = !mock ? UnitService('$baseUrl/api/units', client) : UnitServiceMock.build(15);
    final UnitBloc unitBloc = UnitBloc(unitService);

    // Configure Device service
    final DeviceService deviceService =
        !mock ? DeviceService('$baseUrl/api/devices') : DeviceServiceMock.build(incidentBloc, 30);
    final DeviceBloc deviceBloc = DeviceBloc(deviceService);

    // Configure Tracking service
    final TrackingService trackingService =
        !mock ? TrackingService('$baseUrl/api/tracking', client) : TrackingServiceMock.build(incidentBloc, 30);
    final TrackingBloc trackingBloc = TrackingBloc(trackingService);

    return Providers._internal(
      configBloc,
      userBloc,
      incidentBloc,
      unitBloc,
      deviceBloc,
      trackingBloc,
    );
  }
}