import 'dart:math';

import 'package:SarSys/models/core.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'Position.dart';
import 'Source.dart';

part 'Track.g.dart';

@JsonSerializable()
class Track extends EntityObject<Map<String, dynamic>> {
  Track({
    @required String id,
    @required this.status,
    @required this.source,
    @required this.positions,
  }) : super(id, fields: [
          status,
          source,
          positions,
        ]);

  final Source source;
  final TrackStatus status;
  final List<Position> positions;

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => positions?.isEmpty == true;

  /// Factory constructor for creating a new `Track`  instance
  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackToJson(this);

  Track cloneWith({
    String id,
    TrackStatus status,
    Source source,
    List<Position> positions,
  }) =>
      Track(
        id: id ?? this.id,
        status: status ?? this.status,
        source: source ?? this.source,
        positions: positions ?? this.positions,
      );

  /// Truncate to number of points and return new [Track] instance
  Track truncate(int count) => Track(
        id: id,
        status: status,
        source: source,
        positions: positions.skip(max(0, positions.length - count)).toList(),
      );
}

enum TrackStatus { attached, detached }

String translateTrackStatus(TrackStatus status) {
  switch (status) {
    case TrackStatus.attached:
      return "Tilknyttet";
    case TrackStatus.detached:
    default:
      return "Ikke tilknyttet";
  }
}
