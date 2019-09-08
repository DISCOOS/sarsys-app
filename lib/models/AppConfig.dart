import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AppConfig.g.dart';

@JsonSerializable()
class AppConfig extends Equatable {
  static const ONBOARDING = 'onboarding';
  static const TALK_GROUPS_CATALOG = 'talk_groups_catalog';
  static const DISTRICT = 'district';
  static const DEPARTMENT = 'department';
  static const LOCATION_WHEN_IN_USE = 'locationWhenInUse';
  static const SENTRY_DNS = "sentryDns";
  static const MAP_CACHE_TTL = "mapCacheTTL";
  static const MAP_CACHE_CAPACITY = "mapCacheCapacity";
  static const LOCATION_ACCURACY = "locationAccuracy";
  static const LOCATION_FASTEST_INTERVAL = "locationFastestInterval";
  static const LOCATION_SMALLEST_DISPLACEMENT = "locationSmallestDisplacement";

  static const PARAMS = const {
    SENTRY_DNS: "string",
    ONBOARDING: "bool",
    DISTRICT: "string",
    DEPARTMENT: "string",
    TALK_GROUPS_CATALOG: "string",
    LOCATION_WHEN_IN_USE: "bool",
    MAP_CACHE_TTL: "int",
    MAP_CACHE_CAPACITY: "int",
    LOCATION_ACCURACY: "string",
    LOCATION_FASTEST_INTERVAL: "int",
    LOCATION_SMALLEST_DISPLACEMENT: "int",
  };

  final String sentryDns;
  final bool onboarding;
  final String division;
  final String department;
  final String talkGroups;
  final bool locationWhenInUse;
  final int mapCacheTTL;
  final int mapCacheCapacity;
  final String locationAccuracy;
  final int locationFastestInterval;
  final int locationSmallestDisplacement;

  AppConfig({
    @required this.sentryDns,
    this.onboarding = true,
    this.locationWhenInUse = false,
    this.division = Defaults.division,
    this.department = Defaults.department,
    this.talkGroups = Defaults.talkGroups,
    this.mapCacheTTL = Defaults.mapCacheTTL,
    this.mapCacheCapacity = Defaults.mapCacheCapacity,
    this.locationAccuracy = Defaults.locationAccuracy,
    this.locationFastestInterval = Defaults.locationFastestInterval,
    this.locationSmallestDisplacement = Defaults.locationSmallestDisplacement,
  }) : super([
          onboarding,
          division,
          department,
          talkGroups,
          locationWhenInUse,
          mapCacheTTL,
          mapCacheCapacity,
          locationAccuracy,
          locationFastestInterval,
          locationSmallestDisplacement
        ]);

  /// Factory constructor for creating a new `AppConfig` instance
  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);

  AppConfig copyWith({
    String sentry,
    bool onboarding,
    String district,
    String department,
    String tgCatalog,
    bool locationWhenInUse,
    int mapCacheTTL,
    int mapCacheCapacity,
    String locationAccuracy,
    int locationFastestInterval,
    int locationSmallestDisplacement,
  }) {
    return AppConfig(
      sentryDns: sentry ?? this.sentryDns,
      onboarding: onboarding ?? this.onboarding,
      division: district ?? this.division,
      department: department ?? this.department,
      talkGroups: tgCatalog ?? this.talkGroups,
      locationWhenInUse: locationWhenInUse ?? this.locationWhenInUse,
      mapCacheTTL: mapCacheTTL ?? this.mapCacheTTL,
      mapCacheCapacity: mapCacheCapacity ?? this.mapCacheCapacity,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      locationFastestInterval: locationFastestInterval ?? this.locationFastestInterval,
      locationSmallestDisplacement: locationSmallestDisplacement ?? this.locationSmallestDisplacement,
    );
  }

  LocationAccuracy toLocationAccuracy({
    LocationAccuracy defaultValue: LocationAccuracy.high,
  }) =>
      LocationAccuracy.values.firstWhere(
        (test) => enumName(test) == this.locationAccuracy,
        orElse: () => defaultValue,
      );
}
