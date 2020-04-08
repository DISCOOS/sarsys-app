import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:SarSys/models/converters.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Organization.g.dart';

@JsonSerializable()
class Organization extends Equatable {
  final String id;
  final String name;
  final String alias;
  final String pattern;
  final List<String> idpHints;
  final Map<String, String> functions;
  final Map<String, Division> divisions;

  @FleetMapTalkGroupConverter()
  @JsonKey(name: "talk_groups")
  final Map<String, List<TalkGroup>> talkGroups;

  Organization({
    @required this.id,
    @required this.name,
    @required this.alias,
    @required this.pattern,
    @required this.idpHints,
    @required this.functions,
    @required this.divisions,
    @required this.talkGroups,
  }) : super([
          id,
          name,
          alias,
          pattern,
          idpHints,
          functions,
          divisions,
          talkGroups,
        ]);

  /// Factory constructor for creating a new `Organization` instance
  factory Organization.fromJson(Map<String, dynamic> json) => _$OrganizationFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$OrganizationToJson(this);

  /// Get Affiliation from device number
  Affiliation toAffiliation(String number) {
    String id = emptyAsNull(number?.isEmpty == false && number.length >= 3 ? number?.substring(0, 2) : null);
    if (id == null || !id.startsWith(this.id)) return null;
    return Affiliation(
      organization: this.id,
      division: toDivision(number)?.name,
      department: toDepartment(number, empty: null),
    );
  }

  /// Get affiliation as comma-separated list of organization, division and department names
  String toAffiliationAsString(String number, {String empty = 'Ingen'}) {
    final names = [
      name,
      toDivision(number)?.name,
      toDepartment(number, empty: null),
    ]..removeWhere((name) => name == null);
    return names.isEmpty ? empty : names.join(', ');
  }

  /// Get Division from device number
  Division toDivision(String number) {
    String id = emptyAsNull(number?.isEmpty == false && number.length >= 5 ? number?.substring(2, 5) : null);
    if (id == null) return null;
    return divisions?.entries?.firstWhere((division) => division.key == id, orElse: () => null)?.value;
  }

  /// Get Department from device number
  String toDepartment(String number, {String empty = 'Ingen'}) {
    String id = emptyAsNull(number?.isEmpty == false && number.length >= 5 ? number?.substring(2, 5) : null);
    if (id == null) return null;
    return divisions?.entries
            ?.firstWhere((division) => division.key == id, orElse: () => null)
            ?.value
            ?.departments
            ?.values
            ?.firstWhere((department) => department == id, orElse: () => null) ??
        empty;
  }

  /// Get function from device number
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
