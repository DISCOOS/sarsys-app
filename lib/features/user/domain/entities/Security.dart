import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Security.g.dart';

@JsonSerializable()
class Security extends Equatable {
  Security({
    this.pin,
    this.type,
    this.locked,
    this.trusted,
    this.mode,
    DateTime heartbeat,
  })  : heartbeat = heartbeat ?? DateTime.now(),
        super([
          pin,
          type,
          locked,
          trusted,
          heartbeat,
        ]);

  final String pin;
  final SecurityType type;

  @JsonKey(defaultValue: true)
  final bool locked;
  final bool trusted;
  final DateTime heartbeat;
  final SecurityMode mode;

  factory Security.fromPin(
    String pin, {
    SecurityMode mode = SecurityMode.personal,
    bool locked = false,
    bool trusted = false,
  }) =>
      Security(
        pin: pin,
        type: SecurityType.pin,
        mode: mode,
        locked: locked,
        trusted: trusted,
      );

  /// Factory constructor for creating a new `Security` instance from json data
  factory Security.fromJson(Map<String, dynamic> json) => _$SecurityFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$SecurityToJson(this);

  Security renew() => cloneWith(heartbeat: DateTime.now());

  Security cloneWith({
    String pin,
    bool locked,
    bool trusted,
    SecurityType type,
    SecurityMode mode,
    DateTime heartbeat,
  }) =>
      Security(
        pin: pin ?? this.pin,
        type: type ?? this.type,
        mode: mode ?? this.mode,
        locked: locked ?? this.locked,
        trusted: trusted ?? this.trusted,
        heartbeat: heartbeat ?? this.heartbeat,
      );
}

enum SecurityType { pin, fingerprint }

String translateSecurityType(SecurityType type) {
  switch (type) {
    case SecurityType.pin:
      return "Pinkode";
    case SecurityType.fingerprint:
      return "Fingermønster";
    default:
      return enumName(type);
  }
}

enum SecurityMode { personal, shared }

String translateSecurityMode(SecurityMode mode) {
  switch (mode) {
    case SecurityMode.personal:
      return "Personlig";
    case SecurityMode.shared:
      return "Delt";
    default:
      return enumName(mode);
  }
}
