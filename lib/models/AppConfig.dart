import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AppConfig.g.dart';

@JsonSerializable()
class AppConfig extends Equatable {
  static const ONBOARDING = 'onboarding';
  static const AFFILIATION = 'affiliation';
  static const LOCATION_WHEN_IN_USE = 'locationWhenInUse';
  static const PARAMS = const {
    ONBOARDING: "bool",
    AFFILIATION: "bool",
    LOCATION_WHEN_IN_USE: "bool",
  };

  final bool onboarding;
  final String affiliation;
  final bool locationWhenInUse;

  AppConfig({
    @required this.onboarding,
    @required this.affiliation,
    @required this.locationWhenInUse,
  }) : super([
          onboarding,
          affiliation,
          locationWhenInUse,
        ]);

  /// Factory constructor for creating a new `AppConfig` instance
  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);

  AppConfig copyWith({
    bool onboarding,
    String affiliation,
    bool locationWhenInUse,
  }) {
    return AppConfig(
      onboarding: onboarding ?? this.onboarding,
      affiliation: affiliation ?? this.affiliation,
      locationWhenInUse: locationWhenInUse ?? this.locationWhenInUse,
    );
  }
}
