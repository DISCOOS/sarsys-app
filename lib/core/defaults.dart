import 'package:SarSys/models/BaseMap.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:latlong/latlong.dart';

class Defaults {
  static const String baseWsUrl = 'wss://sarsys.app';
  static const String baseRestUrl = 'https://sarsys.app/api';
  static const double zoom = 16.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;
  static const String orgId = "61"; // Røde Kors Hjelpekorps
  static const String divId = "140"; // Oslo
  static const String depId = "141"; // Oslo
  static const String talkGroupCatalog = "Nasjonal";
  static const int mapCacheTTL = 30;
  static const int mapCacheCapacity = 15000;
  static const String locationAccuracy = "high";
  static const int locationFastestInterval = 1000;
  static const int locationSmallestDisplacement = 3;
  static const bool keepScreenOn = false;
  static const bool callsignReuse = true;
  static final BaseMap baseMap = BaseMap(
    name: "topo4",
    minZoom: 3.0,
    maxZoom: 20.0,
    description: "Topografisk",
    url: "https://{s}.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}",
    subdomains: ["opencache", "opencache2", "opencache3"],
  );
  static const int securityLockAfter = 2700;
  static const SecurityType securityType = SecurityType.pin;
  static const SecurityMode securityMode = SecurityMode.personal;
  static const List<String> trustedDomains = const ['rodekors.org'];

  static final LatLng origo = LatLng(59.5, 10.09);
}
