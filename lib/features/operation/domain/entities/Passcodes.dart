

import 'package:json_annotation/json_annotation.dart';
import 'package:random_string/random_string.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/core/domain/models/core.dart';

part 'Passcodes.g.dart';

@JsonSerializable()
class Passcodes extends ValueObject<Map<String, dynamic>> {
  final String? commander;
  final String? personnel;

  Passcodes({
    required this.commander,
    required this.personnel,
  }) : super([
          commander,
          personnel,
        ]);

  /// Factory constructor for random generated alpha-numeric command and personnel passcodes
  factory Passcodes.random(int length) {
    return Passcodes(
      commander: randomAlphaNumeric(length).toUpperCase(),
      personnel: randomAlphaNumeric(length).toUpperCase(),
    );
  }

  /// Factory constructor for creating a new `Passcodes`  instance
  factory Passcodes.fromJson(Map<String, dynamic> json) => _$PasscodesFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PasscodesToJson(this);
}
