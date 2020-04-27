import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'AggregateRef.g.dart';

@JsonSerializable()
class AggregateRef<T> extends Equatable {
  final String type;
  final String uuid;

  AggregateRef({
    @required this.uuid,
  })  : type = typeOf<T>().toString(),
        super([uuid, typeOf<T>().toString()]);

  /// Factory constructor for creating a new `AggregateRef` instance
  factory AggregateRef.fromJson(Map<String, dynamic> json) => _$AggregateRefFromJson<T>(json);

  /// Get [AggregateRef] from given type
  static AggregateRef fromType<T>(String uuid) => AggregateRef<T>(uuid: uuid);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AggregateRefToJson(this);
}
