import 'package:SarSys/core/domain/models/core.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'FleetMapNumber.dart';
import 'OperationalFunction.dart';
import 'TalkGroupCatalog.dart';

part 'FleetMap.g.dart';

@JsonSerializable()
class FleetMap extends JsonObject {
  FleetMap({
    @required this.name,
    @required this.alias,
    @required this.prefix,
    @required this.pattern,
    @required this.numbers,
    @required this.catalogs,
    @required this.functions,
  }) : super([name, alias, prefix, pattern, numbers, catalogs, functions]);

  @override
  List<Object> get props => [
        name,
        alias,
        prefix,
        pattern,
        numbers,
        catalogs,
        functions,
      ];

  /// FleetMap name
  final String name;

  /// Organisation prefix number
  final String prefix;

  /// Organisation alias
  final String alias;

  /// Organisation fleet map number pattern
  final String pattern;

  /// List of [FleetMapNumber]
  final List<FleetMapNumber> numbers;

  /// List of [TalkGroup] catalogs
  final List<TalkGroupCatalog> catalogs;

  /// Operational function number patterns
  final List<OperationalFunction> functions;

  /// Factory constructor for creating a new `FleetMap` instance
  factory FleetMap.fromJson(Map<String, dynamic> json) => _$FleetMapFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$FleetMapToJson(this);
}
