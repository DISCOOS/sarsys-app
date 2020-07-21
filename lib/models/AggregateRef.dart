import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AggregateRef.g.dart';

@JsonSerializable()
class AggregateRef<T extends Aggregate> extends Equatable {
  AggregateRef({
    @required this.uuid,
  }) : super([uuid, typeOf<T>()]);

  final String uuid;

  @JsonKey(ignore: true)
  Type get type => typeOf<T>();

  /// Factory constructor for creating a new `AggregateRef` instance
  factory AggregateRef.fromJson(dynamic json) =>
      json is Map ? _$AggregateRefFromJson<T>(Map<String, dynamic>.from(json)) : null;

  /// Get [AggregateRef] from given type
  static AggregateRef<T> fromType<T extends Aggregate>(String uuid) => AggregateRef<T>(uuid: uuid);

  /// Cast this to given type [T], optionally replacing uuid with given
  AggregateRef<T> cast<T extends Aggregate>({String uuid}) => AggregateRef<T>(uuid: uuid ?? this.uuid);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AggregateRefToJson(this);
}
