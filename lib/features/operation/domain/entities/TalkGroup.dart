import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'TalkGroup.g.dart';

@JsonSerializable()
class TalkGroup extends Equatable {
  final String id;
  final String name;
  final TalkGroupType type;

  TalkGroup({
    @required this.id,
    @required this.name,
    @required this.type,
  }) : super([
          name,
          type,
        ]);

  /// Get searchable string
  get searchable => props.map((prop) => prop is TalkGroupType ? translateTalkGroupType(prop) : prop).join(' ');

  /// Factory constructor for creating a new `TalkGroup`  instance
  factory TalkGroup.fromJson(Map<String, dynamic> json) => _$TalkGroupFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TalkGroupToJson(this);
}

enum TalkGroupType { tetra, marine, analog }

String translateTalkGroupType(TalkGroupType type) {
  switch (type) {
    case TalkGroupType.tetra:
      return "Nødnett";
    case TalkGroupType.marine:
      return "Maritim";
    case TalkGroupType.analog:
      return "Analog";
    default:
      return enumName(type);
  }
}
