import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Security.g.dart';

@JsonSerializable()
class Security extends Equatable {
  Security(this.pin, this.type, this.locked);
  final String pin;
  @JsonKey(nullable: false)
  final SecurityType type;
  @JsonKey(defaultValue: true)
  final bool locked;

  factory Security.fromPin(String pin) => Security(pin, SecurityType.pin, false);

  /// Factory constructor for creating a new `Security` instance from json data
  factory Security.fromJson(Map<String, dynamic> json) => _$SecurityFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$SecurityToJson(this);

  Security cloneWith({
    String pin,
    SecurityType type,
    bool locked,
  }) =>
      Security(
        pin ?? this.pin,
        type ?? this.type,
        locked ?? this.locked,
      );
}

enum SecurityType {
  pin,
  fingerprint,
}
