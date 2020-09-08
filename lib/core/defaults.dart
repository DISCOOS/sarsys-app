import 'package:SarSys/core/domain/models/BaseMap.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:latlong/latlong.dart';

class Defaults {
  static const String baseWsUrl = 'wss://sarsys.app';
  // static const String baseRestUrl = 'http://192.168.86.20/api';
//  static const String baseRestUrl = 'http://192.168.1.100/api';
  static const String baseRestUrl = 'https://sarsys.app/api';
  static const double zoom = 16.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;
  static const String talkGroupCatalog = "Nasjonal";
  static const int mapCacheTTL = 30;
  static const bool mapRetinaMode = false;
  static const int mapCacheCapacity = 15000;
  static const bool activityRecognition = false;
  static const bool locationStoreLocally = true;
  static const bool locationAllowSharing = true;
  static const String locationAccuracy = "automatic";
  static const int locationFastestInterval = 0;
  static const int locationSmallestDisplacement = 3;
  static const bool keepScreenOn = false;
  static const bool callsignReuse = true;
  static const List<String> idpHints = const ['rodekors'];
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
