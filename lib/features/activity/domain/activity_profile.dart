// @dart=2.11

import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:flutter/foundation.dart';

class ActivityProfile {
  const ActivityProfile({
    @required this.name,
    @required this.options,
    @required this.isTrackable,
  });
  final String name;
  final bool isTrackable;
  final LocationOptions options;

  static const ActivityProfile PRIVATE = ActivityProfile(
    name: 'Privat',
    isTrackable: false,
    options: LocationOptions(
      timeInterval: 0,
      distanceFilter: 5,
      locationStoreLocally: false,
      locationAllowSharing: false,
      accuracy: LocationAccuracy.high,
    ),
  );

  static const ActivityProfile ALERTED = ActivityProfile(
    name: "Varslet",
    isTrackable: false,
    options: LocationOptions(
      timeInterval: 0,
      distanceFilter: 5,
      locationStoreLocally: false,
      locationAllowSharing: false,
      accuracy: LocationAccuracy.high,
    ),
  );

  static const ActivityProfile ENROUTE = ActivityProfile(
    name: 'På vei til aksjon',
    isTrackable: true,
    options: LocationOptions(
      timeInterval: 0,
      distanceFilter: 5,
      locationStoreLocally: true,
      locationAllowSharing: false,
      accuracy: LocationAccuracy.high,
    ),
  );

  static const ActivityProfile ONSCENE = ActivityProfile(
    name: 'Innsats',
    isTrackable: true,
    options: LocationOptions(
      timeInterval: 0,
      distanceFilter: 5,
      locationStoreLocally: true,
      locationAllowSharing: true,
      accuracy: LocationAccuracy.best,
    ),
  );

  static const ActivityProfile LEAVING = ActivityProfile(
    name: 'Demobilisering',
    isTrackable: false,
    options: LocationOptions(
      timeInterval: 0,
      distanceFilter: 5,
      locationStoreLocally: true,
      locationAllowSharing: false,
      accuracy: LocationAccuracy.high,
    ),
  );

  ActivityProfile copyWith({
    String name,
    bool isTrackable,
    LocationOptions options,
  }) =>
      ActivityProfile(
        name: name ?? this.name,
        options: options ?? this.options,
        isTrackable: isTrackable ?? this.isTrackable,
      );

  @override
  String toString() => '$runtimeType: {\n'
      '   name: $name\n'
      '   options: $options\n'
      '}';
}
