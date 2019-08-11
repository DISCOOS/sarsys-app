import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'TalkGroup.g.dart';

@JsonSerializable()
class TalkGroup extends Equatable {
  final String name;
  final TalkGroupType type;

  TalkGroup({
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

enum TalkGroupType { Tetra, Marine, Analog }

String translateTalkGroupType(TalkGroupType type) {
  switch (type) {
    case TalkGroupType.Tetra:
      return "Nødnett";
    case TalkGroupType.Marine:
      return "Maritim";
    case TalkGroupType.Analog:
      return "Analog";
    default:
      return enumName(type);
  }
}
