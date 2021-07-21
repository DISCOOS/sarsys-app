// @dart=2.11

import 'package:SarSys/core/domain/models/converters.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'TalkGroup.dart';

part 'TalkGroupCatalog.g.dart';

@JsonSerializable()
class TalkGroupCatalog extends Equatable {
  final String name;

  @FleetMapTalkGroupConverter()
  final List<TalkGroup> groups;

  TalkGroupCatalog({
    @required this.name,
    @required this.groups,
  });

  @override
  List<Object> get props => [
        name,
        groups,
      ];

  /// Factory constructor for creating a new `TalkGroupCatalog`  instance
  factory TalkGroupCatalog.fromJson(Map<String, dynamic> json) => _$TalkGroupCatalogFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TalkGroupCatalogToJson(this);
}
