import 'dart:math';

import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/data/models/source_model.dart';
import 'package:SarSys/features/tracking/domain/entities/Source.dart';
import 'package:SarSys/features/tracking/domain/entities/Track.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'track_model.g.dart';

@JsonSerializable()
class TrackModel extends Track {
  TrackModel({
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
  final SourceModel source;

  /// Factory constructor for creating a new `TrackModel`  instance
  factory TrackModel.fromJson(Map<String, dynamic> json) => _$TrackModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackModelToJson(this);

  Track cloneWith({
    String id,
    TrackStatus status,
    Source source,
    List<Position> positions,
  }) =>
      TrackModel(
        id: id ?? this.id,
        status: status ?? this.status,
        source: source ?? this.source,
        positions: positions ?? this.positions,
      );

  /// Truncate to number of points and return new [TrackModel] instance
  TrackModel truncate(int count) => TrackModel(
        id: id,
        status: status,
        source: source,
        positions: positions.skip(max(0, positions.length - count)).toList(),
      );
}
