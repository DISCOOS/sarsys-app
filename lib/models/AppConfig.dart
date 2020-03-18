import 'package:SarSys/models/User.dart';
import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AppConfig.g.dart';

@JsonSerializable()
class AppConfig extends Equatable {
  static const DEMO = 'demo';
  static const DEMO_ROLE = 'demoRole';
  static const ONBOARDING = 'onboarding';
  static const TALK_GROUP_CATALOG = 'talkGroupCatalog';
  static const TALK_GROUPS = 'talkGroups';
  static const DIVISION = 'division';
  static const DEPARTMENT = 'department';
  static const LOCATION_WHEN_IN_USE = 'locationWhenInUse';
  static const STORAGE = 'storage';
  static const SENTRY_DNS = "sentryDns";
  static const MAP_CACHE_TTL = "mapCacheTTL";
  static const MAP_CACHE_CAPACITY = "mapCacheCapacity";
  static const LOCATION_ACCURACY = "locationAccuracy";
  static const LOCATION_FASTEST_INTERVAL = "locationFastestInterval";
  static const LOCATION_SMALLEST_DISPLACEMENT = "locationSmallestDisplacement";
  static const KEEP_SCREEN_ON = "keepScreenOn";
  static const CALLSIGN_REUSE = "callsignReuse";
  static const UNITS = "units";

  static const PARAMS = const {
    SENTRY_DNS: "string",
    DEMO: "bool",
    DEMO_ROLE: "string",
    ONBOARDING: "bool",
    DIVISION: "string",
    DEPARTMENT: "string",
    TALK_GROUPS: "stringlist",
    TALK_GROUP_CATALOG: "string",
    LOCATION_WHEN_IN_USE: "bool",
    STORAGE: "bool",
    MAP_CACHE_TTL: "int",
    MAP_CACHE_CAPACITY: "int",
    LOCATION_ACCURACY: "string",
    LOCATION_FASTEST_INTERVAL: "int",
    LOCATION_SMALLEST_DISPLACEMENT: "int",
    KEEP_SCREEN_ON: "bool",
    CALLSIGN_REUSE: "bool",
    UNITS: "stringlist",
  };

  final bool demo;
  final String demoRole;
  final String sentryDns;
  final bool onboarding;
  final String division;
  final String department;
  final List<String> talkGroups;
  final String talkGroupCatalog;
  final bool storage;
  final bool locationWhenInUse;
  final int mapCacheTTL;
  final int mapCacheCapacity;
  final String locationAccuracy;
  final int locationFastestInterval;
  final int locationSmallestDisplacement;
  final bool keepScreenOn;
  final bool callsignReuse;
  final List<String> units;

  AppConfig({
    @required this.sentryDns,
    this.demo,
    this.demoRole,
    this.onboarding = true,
    this.storage = false,
    this.locationWhenInUse = false,
    this.division = Defaults.division,
    this.department = Defaults.department,
    List<String> talkGroups = const <String>[],
    this.talkGroupCatalog = Defaults.talkGroupCatalog,
    this.mapCacheTTL = Defaults.mapCacheTTL,
    this.mapCacheCapacity = Defaults.mapCacheCapacity,
    this.locationAccuracy = Defaults.locationAccuracy,
    this.locationFastestInterval = Defaults.locationFastestInterval,
    this.locationSmallestDisplacement = Defaults.locationSmallestDisplacement,
    this.keepScreenOn = Defaults.keepScreenOn,
    this.callsignReuse = Defaults.callsignReuse,
    List<String> units = const <String>[],
  })  : this.talkGroups = talkGroups ?? const <String>[],
        this.units = units ?? const <String>[],
        super([
          sentryDns,
          demo,
          demoRole,
          onboarding,
          division,
          department,
          talkGroups ?? const <String>[],
          talkGroupCatalog,
          storage,
          locationWhenInUse,
          mapCacheTTL,
          mapCacheCapacity,
          locationAccuracy,
          locationFastestInterval,
          locationSmallestDisplacement,
          keepScreenOn,
          callsignReuse,
          units ?? const <String>[],
        ]);

  /// Factory constructor for creating a new `AppConfig` instance
  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);

  AppConfig copyWith({
    String sentry,
    bool demo,
    String demoRole,
    bool onboarding,
    String division,
    String department,
    List<String> talkGroups,
    String talkGroupCatalog,
    bool storage,
    bool locationWhenInUse,
    int mapCacheTTL,
    int mapCacheCapacity,
    String locationAccuracy,
    int locationFastestInterval,
    int locationSmallestDisplacement,
    bool keepScreenOn,
    bool callsignReuse,
    List<String> units,
  }) {
    return AppConfig(
      sentryDns: sentry ?? this.sentryDns,
      demo: demo ?? this.demo,
      demoRole: demoRole ?? this.demoRole,
      onboarding: onboarding ?? this.onboarding,
      division: division ?? this.division,
      department: department ?? this.department,
      talkGroups: talkGroups ?? this.talkGroups,
      talkGroupCatalog: talkGroupCatalog ?? this.talkGroupCatalog,
      storage: storage ?? this.storage,
      locationWhenInUse: locationWhenInUse ?? this.locationWhenInUse,
      mapCacheTTL: mapCacheTTL ?? this.mapCacheTTL,
      mapCacheCapacity: mapCacheCapacity ?? this.mapCacheCapacity,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      locationFastestInterval: locationFastestInterval ?? this.locationFastestInterval,
      locationSmallestDisplacement: locationSmallestDisplacement ?? this.locationSmallestDisplacement,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      callsignReuse: callsignReuse ?? this.callsignReuse,
      units: units ?? this.units,
    );
  }

  DemoParams toDemoParams() => DemoParams(demo, role: toRole());

  UserRole toRole({
    UserRole defaultValue: UserRole.commander,
  }) =>
      UserRole.values.firstWhere(
        (test) => enumName(test) == this.demoRole,
        orElse: () => defaultValue,
      );

  LocationAccuracy toLocationAccuracy({
    LocationAccuracy defaultValue: LocationAccuracy.high,
  }) =>
      LocationAccuracy.values.firstWhere(
        (test) => enumName(test) == this.locationAccuracy,
        orElse: () => defaultValue,
      );
}
