import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AppConfig.g.dart';

@JsonSerializable()
class AppConfig extends Equatable {
  static const ONBOARDING = 'onboarding';
  static const TALK_GROUPS = 'talk_groups';
  static const DISTRICT = 'district';
  static const DEPARTMENT = 'department';
  static const LOCATION_WHEN_IN_USE = 'locationWhenInUse';
  static const SENTRY_DNS = "sentryDns";
  static const PARAMS = const {
    SENTRY_DNS: "string",
    ONBOARDING: "bool",
    DISTRICT: "string",
    DEPARTMENT: "string",
    TALK_GROUPS: "string",
    LOCATION_WHEN_IN_USE: "bool",
  };

  final String sentryDns;
  final bool onboarding;
  final String division;
  final String department;
  final String talkGroups;
  final bool locationWhenInUse;

  AppConfig({
    @required this.sentryDns,
    @required this.onboarding,
    @required this.division,
    @required this.department,
    @required this.talkGroups,
    @required this.locationWhenInUse,
  }) : super([
          onboarding,
          division,
          department,
          talkGroups,
          locationWhenInUse,
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
    String talkGroups,
    bool locationWhenInUse,
  }) {
    return AppConfig(
      sentryDns: sentry ?? this.sentryDns,
      onboarding: onboarding ?? this.onboarding,
      division: district ?? this.division,
      department: department ?? this.department,
      talkGroups: talkGroups ?? this.talkGroups,
      locationWhenInUse: locationWhenInUse ?? this.locationWhenInUse,
    );
  }
}
