// @dart=2.11

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_config_model.g.dart';

@JsonSerializable()
class AppConfigModel extends AppConfig implements JsonObject<Map<String, dynamic>> {
  AppConfigModel({
    @required String uuid,
    @required String udid,
    @required String sentryDns,
    @required int version,
    bool demo,
    String demoRole,
    bool onboarded = false,
    bool firstSetup = false,
    bool storage = false,
    bool locationAlways = false,
    bool locationWhenInUse = false,
    bool activityRecognition = false,
    List<String> talkGroups = const <String>[],
    String talkGroupCatalog = Defaults.talkGroupCatalog,
    int mapCacheTTL = Defaults.mapCacheTTL,
    bool mapRetinaMode = Defaults.mapRetinaMode,
    int mapCacheCapacity = Defaults.mapCacheCapacity,
    bool locationStoreLocally = Defaults.locationStoreLocally,
    bool locationAllowSharing = Defaults.locationAllowSharing,
    String locationAccuracy = Defaults.locationAccuracy,
    int locationFastestInterval = Defaults.locationFastestInterval,
    int locationSmallestDisplacement = Defaults.locationSmallestDisplacement,
    List<String> units = const <String>[],
    List<String> idpHints = Defaults.idpHints,
    bool keepScreenOn = Defaults.keepScreenOn,
    bool callsignReuse = Defaults.callsignReuse,
    SecurityType securityType = Defaults.securityType,
    SecurityMode securityMode = Defaults.securityMode,
    List<String> trustedDomains = Defaults.trustedDomains,
    int securityLockAfter = Defaults.securityLockAfter,
    bool locationDebug = Defaults.locationDebug,
  }) : super(
          uuid: uuid,
          udid: udid,
          demo: demo,
          units: units,
          version: version,
          demoRole: demoRole,
          storage: storage ?? false,
          sentryDns: sentryDns ?? false,
          onboarded: onboarded ?? false,
          firstSetup: firstSetup ?? false,
          talkGroups: talkGroups ?? <String>[],
          locationDebug: locationDebug ?? Defaults.locationDebug,
          locationAlways: locationAlways ?? false,
          idpHints: idpHints ?? Defaults.idpHints,
          locationWhenInUse: locationWhenInUse ?? false,
          mapCacheTTL: mapCacheTTL ?? Defaults.mapCacheTTL,
          activityRecognition: activityRecognition ?? false,
          securityType: securityType ?? Defaults.securityType,
          securityMode: securityMode ?? Defaults.securityMode,
          keepScreenOn: keepScreenOn ?? Defaults.keepScreenOn,
          mapRetinaMode: mapRetinaMode ?? Defaults.mapRetinaMode,
          callsignReuse: callsignReuse ?? Defaults.callsignReuse,
          trustedDomains: trustedDomains ?? Defaults.trustedDomains,
          talkGroupCatalog: talkGroupCatalog ?? Defaults.talkGroupCatalog,
          mapCacheCapacity: mapCacheCapacity ?? Defaults.mapCacheCapacity,
          locationAccuracy: locationAccuracy ?? Defaults.locationAccuracy,
          securityLockAfter: securityLockAfter ?? Defaults.securityLockAfter,
          locationStoreLocally: locationStoreLocally ?? Defaults.locationStoreLocally,
          locationAllowSharing: locationAllowSharing ?? Defaults.locationAllowSharing,
          locationFastestInterval: locationFastestInterval ?? Defaults.locationFastestInterval,
          locationSmallestDisplacement: locationSmallestDisplacement ?? Defaults.locationSmallestDisplacement,
        );

  @override
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
  }) {
    return AppConfigModel(
      uuid: uuid ?? this.uuid,
      udid: udid ?? this.udid,
      version: version ?? this.version,
      sentryDns: sentry ?? this.sentryDns,
      demo: demo ?? this.demo,
      demoRole: demoRole ?? this.demoRole,
      onboarded: onboarded ?? this.onboarded,
      firstSetup: firstSetup ?? this.firstSetup,
      talkGroups: talkGroups ?? this.talkGroups,
      talkGroupCatalog: talkGroupCatalog ?? this.talkGroupCatalog,
      storage: storage ?? this.storage,
      locationAlways: locationAlways ?? this.locationAlways,
      locationWhenInUse: locationWhenInUse ?? this.locationWhenInUse,
      activityRecognition: activityRecognition ?? this.activityRecognition,
      locationStoreLocally: locationStoreLocally ?? this.locationStoreLocally,
      locationAllowSharing: locationAllowSharing ?? this.locationAllowSharing,
      mapCacheTTL: mapCacheTTL ?? this.mapCacheTTL,
      mapRetinaMode: mapRetinaMode ?? this.mapRetinaMode,
      mapCacheCapacity: mapCacheCapacity ?? this.mapCacheCapacity,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      locationFastestInterval: locationFastestInterval ?? this.locationFastestInterval,
      locationSmallestDisplacement: locationSmallestDisplacement ?? this.locationSmallestDisplacement,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      callsignReuse: callsignReuse ?? this.callsignReuse,
      units: units ?? this.units,
      idpHints: idpHints ?? this.idpHints,
      securityType: securityType ?? this.securityType,
      securityMode: securityMode ?? this.securityMode,
      trustedDomains: trustedDomains ?? this.trustedDomains,
      securityLockAfter: securityLockAfter ?? this.securityLockAfter,
      locationDebug: locationDebug ?? this.locationDebug,
    );
  }

  /// Factory constructor for creating a new `AppConfigModel` instance
  factory AppConfigModel.fromJson(Map<String, dynamic> json) => _$AppConfigModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AppConfigModelToJson(this);
}
