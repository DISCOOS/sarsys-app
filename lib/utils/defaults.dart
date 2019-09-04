import 'package:latlong/latlong.dart';

class Defaults {
  static const String baseWsUrl = 'wss://sporing.rodekors.no';
  static const String baseRestUrl = 'https://sporing.rodekors.no';
  static const double zoom = 13.0;
  static const double maxZoom = 20.0;
  static const double minZoom = 3.0;
  static const String orgId = "61"; // Røde Kors Hjelpekorps
  static const String division = "140"; // Oslo
  static const String department = "141"; // Oslo
  static const String talkGroups = "Nasjonal";
  static const int mapCacheTTL = 30;
  static const int mapCacheCapacity = 15000;
  static const String locationAccuracy = "high";
  static const int locationFastestInterval = 1000;
  static const int locationSmallestDisplacement = 3;

  static final LatLng origo = LatLng(59.5, 10.09);
}
