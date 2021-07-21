// @dart=2.11

import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/app_controller.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:meta/meta.dart';

abstract class AppConfig extends Aggregate<Map<String, dynamic>> {
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
    this.locationAlways = false,
    this.locationWhenInUse = false,
    this.activityRecognition = false,
    List<String> talkGroups = const <String>[],
    this.talkGroupCatalog = Defaults.talkGroupCatalog,
    this.mapCacheTTL = Defaults.mapCacheTTL,
    this.mapRetinaMode = Defaults.mapRetinaMode,
    this.mapCacheCapacity = Defaults.mapCacheCapacity,
    this.locationStoreLocally = Defaults.locationStoreLocally,
    this.locationAllowSharing = Defaults.locationAllowSharing,
    this.locationAccuracy = Defaults.locationAccuracy,
    this.locationFastestInterval = Defaults.locationFastestInterval,
    this.locationSmallestDisplacement = Defaults.locationSmallestDisplacement,
    List<String> units = const <String>[],
    this.keepScreenOn = Defaults.keepScreenOn,
    this.callsignReuse = Defaults.callsignReuse,
    this.idpHints = Defaults.idpHints,
    this.securityType = Defaults.securityType,
    this.securityMode = Defaults.securityMode,
    this.trustedDomains = Defaults.trustedDomains,
    this.securityLockAfter = Defaults.securityLockAfter,
    this.locationDebug = Defaults.locationDebug,
  })  : this.talkGroups = talkGroups ?? const <String>[],
        this.units = units ?? const <String>[],
        super(uuid, fields: [
          udid,
          sentryDns,
          version,
          demo,
          demoRole,
          onboarded,
          firstSetup,
          storage,
          locationAlways,
          locationWhenInUse,
          activityRecognition,
          talkGroups ?? const <String>[],
          talkGroupCatalog,
          mapCacheTTL,
          mapRetinaMode,
          mapCacheCapacity,
          locationAccuracy,
          locationStoreLocally,
          locationAllowSharing,
          locationFastestInterval,
          locationSmallestDisplacement,
          units ?? const <String>[],
          keepScreenOn,
          callsignReuse,
          idpHints,
          securityType,
          securityMode,
          trustedDomains,
          securityLockAfter,
          locationDebug,
        ]);
  final String udid;
  final int version;
  final bool demo;
  final String demoRole;
  final String sentryDns;
  final bool onboarded;
  final bool firstSetup;
  final List<String> talkGroups;
  final String talkGroupCatalog;
  final bool storage;
  final bool locationAlways;
  final bool locationWhenInUse;
  final bool activityRecognition;
  final int mapCacheTTL;
  final bool mapRetinaMode;
  final int mapCacheCapacity;
  final bool locationAllowSharing;
  final bool locationStoreLocally;
  final String locationAccuracy;
  final int locationFastestInterval;
  final int locationSmallestDisplacement;
  final bool keepScreenOn;
  final bool callsignReuse;
  final List<String> units;
  final List<String> idpHints;
  final SecurityType securityType;
  final SecurityMode securityMode;
  final List<String> trustedDomains;
  final int securityLockAfter;
  final bool locationDebug;

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
    bool locationAlways,
    bool locationWhenInUse,
    bool activityRecognition,
    int mapCacheTTL,
    bool mapRetinaMode,
    int mapCacheCapacity,
    bool locationAllowSharing,
    bool locationStoreLocally,
    String locationAccuracy,
    int locationFastestInterval,
    int locationSmallestDisplacement,
    bool keepScreenOn,
    bool callsignReuse,
    List<String> units,
    List<String> idpHints,
    SecurityType securityType,
    SecurityMode securityMode,
    List<String> trustedDomains,
    int securityLockAfter,
    bool locationDebug,
  });

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

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}
