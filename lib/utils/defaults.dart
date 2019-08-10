import 'package:latlong/latlong.dart';

class Defaults {
  static final String baseWsUrl = 'wss://sporing.rodekors.no';
  static final String baseRestUrl = 'https://sporing.rodekors.no';
  static final double zoom = 13.0;
  static final double maxZoom = 20.0;
  static final double minZoom = 3.0;
  static final LatLng origo = LatLng(59.5, 10.09);
  static final String orgId = "61";
  static final String district = "Oslo";
  static final String department = "Oslo";
  static final String talkGroups = "Nasjonal";
}
