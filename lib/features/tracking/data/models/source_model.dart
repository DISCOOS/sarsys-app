import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/tracking/domain/entities/Source.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'source_model.g.dart';

@JsonSerializable()
class SourceModel extends Source {
  SourceModel({
    @required String uuid,
    @required SourceType type,
  }) : super(
          uuid: uuid,
          type: type,
        );

  /// Factory constructor for creating a new `SourceModel` instance
  factory SourceModel.fromJson(Map<String, dynamic> json) => _$SourceModelFromJson(json);

  /// Get [SourceModel] from given [aggregate].
  /// Only [Device] and [Tracking] is supported.
  /// An [ArgumentError] in
  static SourceModel fromType<T extends Aggregate>(T aggregate) => SourceModel(
        uuid: aggregate.uuid,
        type: Source.toSourceType<T>(),
      );

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$SourceModelToJson(this);
}
