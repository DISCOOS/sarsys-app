import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AggregateRef.g.dart';

@JsonSerializable()
class AggregateRef<T extends Aggregate> extends Equatable {
  final String type;
  final String uuid;

  AggregateRef({
    @required this.uuid,
  })  : type = typeOf<T>().toString(),
        super([uuid]);

  /// Factory constructor for creating a new `AggregateRef` instance
  factory AggregateRef.fromJson(Map<String, dynamic> json) => _$AggregateRefFromJson<T>(json);

  /// Get [AggregateRef] from given type
  static AggregateRef<T> fromType<T extends Aggregate>(String uuid) => AggregateRef<T>(uuid: uuid);

  /// Cast this to given type [T], optionally replacing uuid with given
  AggregateRef<T> cast<T extends Aggregate>({String uuid}) => AggregateRef<T>(uuid: uuid ?? this.uuid);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AggregateRefToJson(this);
}
