import 'package:equatable/equatable.dart';
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
  static const MAP_CACHE_TTL = "map_cache_ttl";
  static const PARAMS = const {
    SENTRY_DNS: "string",
    ONBOARDING: "bool",
    DISTRICT: "string",
    DEPARTMENT: "string",
    TALK_GROUPS_CATALOG: "string",
    LOCATION_WHEN_IN_USE: "bool",
    MAP_CACHE_TTL: "int",
  };

  final String sentryDns;
  final bool onboarding;
  final String division;
  final String department;
  final String tgCatalog;
  final bool locationWhenInUse;
  final int mapCacheTTL;

  AppConfig({
    @required this.sentryDns,
    @required this.onboarding,
    @required this.division,
    @required this.department,
    @required this.tgCatalog,
    @required this.locationWhenInUse,
    @required this.mapCacheTTL,
  }) : super([
          onboarding,
          division,
          department,
          tgCatalog,
          locationWhenInUse,
          mapCacheTTL,
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
  }) {
    return AppConfig(
      sentryDns: sentry ?? this.sentryDns,
      onboarding: onboarding ?? this.onboarding,
      division: district ?? this.division,
      department: department ?? this.department,
      tgCatalog: tgCatalog ?? this.tgCatalog,
      locationWhenInUse: locationWhenInUse ?? this.locationWhenInUse,
      mapCacheTTL: mapCacheTTL ?? this.mapCacheTTL,
    );
  }
}
