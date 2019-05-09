import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:random_string/random_string.dart';

import 'package:meta/meta.dart';

part 'Passcodes.g.dart';

@JsonSerializable()
class Passcodes extends Equatable {
  final String command;
  final String personnel;

  Passcodes({
    @required this.command,
    @required this.personnel,
  }) : super([
          command,
          personnel,
        ]);

  /// Factory constructor for random generated alpha-numeric command and personnel passcodes
  factory Passcodes.random(int length) {
    return Passcodes(
      command: randomAlphaNumeric(length),
      personnel: randomAlphaNumeric(length),
    );
  }

  /// Factory constructor for creating a new `Passcodes`  instance
  factory Passcodes.fromJson(Map<String, dynamic> json) => _$PasscodesFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PasscodesToJson(this);
}
