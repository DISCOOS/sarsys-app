

import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingSource.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'tracking_source_model.g.dart';

@JsonSerializable()
class TrackingSourceModel extends TrackingSource {
  TrackingSourceModel({
    required String? uuid,
    required SourceType? type,
  }) : super(
          uuid: uuid!,
          type: type,
        );

  /// Factory constructor for creating a new `SourceModel` instance
  factory TrackingSourceModel.fromJson(Map<String, dynamic> json) => _$TrackingSourceModelFromJson(json);

  /// Get [TrackingSourceModel] from given [aggregate].
  /// Only [Device] and [Tracking] is supported.
  /// An [ArgumentError] in
  static TrackingSourceModel fromType<T extends Aggregate>(T aggregate) => TrackingSourceModel(
        uuid: aggregate.uuid,
        type: TrackingSource.toSourceType<T>(),
      );

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackingSourceModelToJson(this);
}
