

import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/data/models/tracking_source_model.dart';
import 'package:SarSys/features/tracking/data/models/tracking_track_model.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingSource.dart';
import 'package:SarSys/features/tracking/domain/entities/TrackingTrack.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'tracking_model.g.dart';

@JsonSerializable()
class TrackingModel extends Tracking {
  TrackingModel({
    /// Tracking id
    required String uuid,

    /// Tracking status
    required TrackingStatus? status,

    /// Last known position
    Position? position,

    /// Total distance in meter
    double? distance,

    /// Average speed in m/s
    double? speed,

    /// Total effort in milliseconds
    Duration? effort,

    /// Map from track id to list of positions
    List<TrackingTrackModel>? tracks = const [],

    /// List of tracked sources
    List<TrackingSourceModel>? sources = const [],

    /// List of historical positions aggregated from temporally and spatially related positions in tracks
    List<Position?>? history = const [],
  })  : tracks = tracks ?? [],
        sources = sources ?? [],
        super(
          uuid: uuid,
          speed: speed,
          effort: effort,
          status: status,
          position: position,
          distance: distance,
          tracks: tracks ?? [],
          sources: sources ?? [],
          history: history ?? [],
        );

  @override
  final List<TrackingSourceModel> sources;

  @override
  final List<TrackingTrackModel> tracks;

  /// Factory constructor for creating a new `Tracking` instance
  factory TrackingModel.fromJson(Map<String, dynamic> json) => _$TrackingModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$TrackingModelToJson(this);

  /// Clone with given devices and state
  Tracking copyWith({
    double? speed,
    double? distance,
    Duration? effort,
    Position? position,
    List<TrackingSource?>? sources,
    List<Position?>? history,
    TrackingStatus? status,
    List<TrackingTrack>? tracks,
  }) {
    return TrackingModel(
      uuid: this.uuid,
      speed: speed ?? this.speed,
      effort: effort ?? this.effort,
      status: status ?? this.status,
      history: history ?? this.history,
      position: position ?? this.position,
      distance: distance ?? this.distance,
      tracks: (tracks ?? this.tracks).cast<TrackingTrackModel>(),
      sources: (sources ?? this.sources).cast<TrackingSourceModel>(),
    );
  }

  /// Clone with json
  Tracking withJson(Map<String, dynamic> json) {
    var clone = TrackingModel.fromJson(json);
    return copyWith(
      status: clone.status ?? status,
      position: clone.position ?? position,
      distance: clone.distance ?? distance,
      speed: clone.speed ?? speed,
      effort: clone.effort ?? effort,
      history: clone.history,
      tracks: clone.tracks,
    );
  }
}
