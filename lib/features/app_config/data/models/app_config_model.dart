import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/app_config/domain/entities/AppConfig.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/models/core.dart';
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
    bool locationWhenInUse = false,
    String orgId = Defaults.orgId,
    String divId = Defaults.divId,
    String depId = Defaults.depId,
    List<String> talkGroups = const <String>[],
    String talkGroupCatalog = Defaults.talkGroupCatalog,
    int mapCacheTTL = Defaults.mapCacheTTL,
    int mapCacheCapacity = Defaults.mapCacheCapacity,
    String locationAccuracy = Defaults.locationAccuracy,
    int locationFastestInterval = Defaults.locationFastestInterval,
    int locationSmallestDisplacement = Defaults.locationSmallestDisplacement,
    List<String> units = const <String>[],
    bool keepScreenOn = Defaults.keepScreenOn,
    bool callsignReuse = Defaults.callsignReuse,
    SecurityType securityType = Defaults.securityType,
    SecurityMode securityMode = Defaults.securityMode,
    List<String> trustedDomains = Defaults.trustedDomains,
    int securityLockAfter = Defaults.securityLockAfter,
  }) : super(
          uuid: uuid,
          udid: udid,
          sentryDns: sentryDns,
          version: version,
          demo: demo,
          demoRole: demoRole,
          onboarded: onboarded,
          firstSetup: firstSetup,
          storage: storage,
          locationWhenInUse: locationWhenInUse,
          orgId: orgId,
          divId: divId,
          depId: depId,
          talkGroups: talkGroups,
          talkGroupCatalog: talkGroupCatalog,
          mapCacheTTL: mapCacheTTL,
          mapCacheCapacity: mapCacheCapacity,
          locationAccuracy: locationAccuracy,
          locationFastestInterval: locationFastestInterval,
          locationSmallestDisplacement: locationSmallestDisplacement,
          units: units,
          keepScreenOn: keepScreenOn,
          callsignReuse: callsignReuse,
          securityType: securityType,
          securityMode: securityMode,
          trustedDomains: trustedDomains,
          securityLockAfter: securityLockAfter,
        );

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
    return AppConfigModel(
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

  /// Factory constructor for creating a new `AppConfigModel` instance
  factory AppConfigModel.fromJson(Map<String, dynamic> json) => _$AppConfigModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AppConfigModelToJson(this);
}
