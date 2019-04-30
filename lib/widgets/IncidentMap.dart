import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class IncidentMap extends StatelessWidget {
  final String url;
  final MapController controller;
  final MapOptions options;
  final bool offline;

  IncidentMap({this.url, this.offline, this.options, this.controller});

  @override
  Widget build(BuildContext context) {
    print("url $url");
    return new FlutterMap(
      mapController: controller,
      options: options,
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
