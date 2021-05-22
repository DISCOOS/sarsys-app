import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';

/// ---------------------
/// Commands
/// ---------------------
abstract class TrackingCommand<D, R> extends BlocCommand<D, R> {
  TrackingCommand(
    D data, {
    props = const [],
  }) : super(data, props);
}

class LoadTrackings extends TrackingCommand<String, List<Tracking>> {
  LoadTrackings(String ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
}

class UpdateTracking extends TrackingCommand<Tracking, Tracking> {
  UpdateTracking(
    Tracking data,
    this.previous,
  ) : super(data);

  final Tracking previous;

  @override
  String toString() => '$runtimeType {data: $data}';
}

class DeleteTracking extends TrackingCommand<Tracking, void> {
  DeleteTracking(Tracking data) : super(data);

  @override
  String toString() => '$runtimeType {data: $data}';
}

class UnloadTrackings extends TrackingCommand<String, List<Tracking>> {
  UnloadTrackings(String ouuid) : super(ouuid);

  @override
  String toString() => '$runtimeType {ouuid: $data}';
}
