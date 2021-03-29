import 'dart:math';

import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/data/models/tracking_source_model.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingSource.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'tracking_track_model.g.dart';

@JsonSerializable()
class TrackingTrackModel extends TrackingTrack {
  TrackingTrackModel({
    @required String id,
    @required TrackStatus status,
    @required this.source,
    @required List<Position> positions,
  }) : super(
          id: id,
          status: status,
          source: source,
          positions: positions,
        );

  @override
  List<Object> get props => [
        id,
        status,
        source,
        positions,
      ];

  @override
  final TrackingSourceModel source;

  /// Factory constructor for creating a new `TrackModel`  instance
  factory TrackingTrackModel.fromJson(Map<String, dynamic> json) => _$TrackingTrackModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackingTrackModelToJson(this);

  TrackingTrack cloneWith({
    String id,
    TrackStatus status,
    TrackingSource source,
    List<Position> positions,
  }) =>
      TrackingTrackModel(
        id: id ?? this.id,
        status: status ?? this.status,
        source: source ?? this.source,
        positions: positions ?? this.positions,
      );

  /// Truncate to number of points and return new [TrackingTrackModel] instance
  TrackingTrackModel truncate(int count) => TrackingTrackModel(
        id: id,
        status: status,
        source: source,
        positions: positions.skip(max(0, positions.length - count)).toList(),
      );
}
