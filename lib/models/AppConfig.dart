import 'package:SarSys/models/Security.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/controllers/bloc_provider_controller.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:geolocator/geolocator.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AppConfig.g.dart';

@JsonSerializable()
class AppConfig extends Aggregate {
  AppConfig({
    @required String uuid,
    @required this.udid,
    @required this.sentryDns,
    @required this.version,
    this.demo,
    this.demoRole,
    this.onboarded = false,
    this.firstSetup = false,
    this.storage = false,
    this.locationWhenInUse = false,
    this.orgId = Defaults.orgId,
    this.divId = Defaults.divId,
    this.depId = Defaults.depId,
    List<String> talkGroups = const <String>[],
    this.talkGroupCatalog = Defaults.talkGroupCatalog,
    this.mapCacheTTL = Defaults.mapCacheTTL,
    this.mapCacheCapacity = Defaults.mapCacheCapacity,
    this.locationAccuracy = Defaults.locationAccuracy,
    this.locationFastestInterval = Defaults.locationFastestInterval,
    this.locationSmallestDisplacement = Defaults.locationSmallestDisplacement,
    List<String> units = const <String>[],
    this.keepScreenOn = Defaults.keepScreenOn,
    this.callsignReuse = Defaults.callsignReuse,
    this.securityType = Defaults.securityType,
    this.securityMode = Defaults.securityMode,
    this.trustedDomains = Defaults.trustedDomains,
    this.securityLockAfter = Defaults.securityLockAfter,
  })  : this.talkGroups = talkGroups ?? const <String>[],
        this.units = units ?? const <String>[],
        super(uuid);
  final String udid;
  final int version;
  final bool demo;
  final String demoRole;
  final String sentryDns;
  final bool onboarded;
  final bool firstSetup;
  final String orgId;
  final String divId;
  final String depId;
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
  final SecurityType securityType;
  final SecurityMode securityMode;
  final List<String> trustedDomains;
  final int securityLockAfter;

  /// Factory constructor for creating a new `AppConfig` instance
  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);

  AppConfig copyWith({
    String uuid,
    String udid,
    int version,
    bool demo,
    String sentry,
    String demoRole,
    bool onboarded,
    bool firstSetup,
    String orgId,
    String divId,
    String depId,
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
    SecurityType securityType,
    SecurityMode securityMode,
    List<String> trustedDomains,
    int securityLockAfter,
  }) {
    return AppConfig(
      uuid: uuid ?? this.uuid,
      udid: udid ?? this.udid,
      version: version ?? this.version,
      sentryDns: sentry ?? this.sentryDns,
      demo: demo ?? this.demo,
      demoRole: demoRole ?? this.demoRole,
      onboarded: onboarded ?? this.onboarded,
      firstSetup: firstSetup ?? this.firstSetup,
      orgId: orgId ?? this.orgId,
      divId: divId ?? this.divId,
      depId: depId ?? this.depId,
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
      securityType: securityType ?? this.securityType,
      securityMode: securityMode ?? this.securityMode,
      trustedDomains: trustedDomains ?? this.trustedDomains,
      securityLockAfter: securityLockAfter ?? this.securityLockAfter,
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

  Security toSecurity(String orgId) => Security(
        type: securityType,
        mode: securityMode,
        heartbeat: DateTime.now(),
        trusted: this.orgId == orgId,
      );
}
