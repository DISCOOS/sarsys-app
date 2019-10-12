import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Organization.g.dart';

@JsonSerializable()
class Organization extends Equatable {
  final String name;
  final String alias;
  final String pattern;
  final Map<String, String> functions;
  final Map<String, Division> divisions;

  @JsonKey(name: "talk_groups")
  @FleetMapTalkGroupConverter()
  final Map<String, List<TalkGroup>> talkGroups;

  Organization({
    @required this.name,
    @required this.alias,
    @required this.pattern,
    @required this.functions,
    @required this.divisions,
    @required this.talkGroups,
  }) : super([name, alias, pattern, functions, divisions, talkGroups]);

  /// Factory constructor for creating a new `Organization` instance
  factory Organization.fromJson(Map<String, dynamic> json) => _$OrganizationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$OrganizationToJson(this);

  String toDistrict(String number) {
    String id = number?.isEmpty == false && number.length >= 5 ? number?.substring(2, 5) : null;
    return divisions?.entries
            ?.firstWhere(
              (entry) => number != null && entry.key == id,
              orElse: () => null,
            )
            ?.value
            ?.name ??
        "Ingen";
  }

  String toFunction(String number) {
    final match = functions?.entries
        ?.firstWhere(
          (entry) => number != null && RegExp(entry.key).hasMatch(number),
          orElse: () => null,
        )
        ?.value;
    return match ?? "Ingen";
  }
}

class FleetMapTalkGroupConverter implements JsonConverter<Map<String, List<TalkGroup>>, Map<String, dynamic>> {
  const FleetMapTalkGroupConverter();

  @override
  Map<String, List<TalkGroup>> fromJson(Map<String, dynamic> json) {
    Map<String, List<TalkGroup>> map = json.map(
      (key, list) => MapEntry(
        key,
        (list as List<dynamic>).map((name) => to(name as String)).toList(),
      ),
    );
    return map;
  }

  @override
  Map<String, List<String>> toJson(Map<String, List<TalkGroup>> items) {
    return items.map((key, list) => MapEntry(key, list.map((tg) => tg.name).toList()));
  }

  static TalkGroup to(String name) {
    return TalkGroup(name: name, type: TalkGroupType.Tetra);
  }

  static List<TalkGroup> toList(List<String> names) {
    return names.map((name) => to(name)).toList();
  }
}
