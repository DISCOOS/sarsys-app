import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class IncidentMap extends StatelessWidget {
  final String url;
  final double zoom;
  final bool offline;

  IncidentMap({this.url, this.offline, this.zoom});

  @override
  Widget build(BuildContext context) {
    print("url $url");
    print("zoom $zoom");
    return new FlutterMap(
      options: new MapOptions(
        center: new LatLng(59.5, 10.09),
        zoom: zoom,
      ),
      layers: [
        new TileLayerOptions(
          urlTemplate: url,
          offlineMode: offline,
          fromAssets: false,
        ),
      ],
    );
  }
}
