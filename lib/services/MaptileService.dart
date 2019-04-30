import 'dart:io';
import 'package:path_provider/path_provider.dart';

class MaptileService {
  static final MaptileService _singleton = new MaptileService();

  factory MaptileService() {
    return _singleton;
  }

  downloadMap() {
    // TODO: Download from server
    // TODO: Unzip to filesystem
    // TODO: Store as available map
  }

  Future<List<Map>> fetchOnlineMaps() async {
    List<Map> _maps;

    // TODO: Get list off online maps from server instead (https://sporing.rodekors.no/api/appconfig loaded during startup?)
    _maps.add(Map(description: "Topografisk"));
    _maps.add(Map(description: "Topografisk (Norge 1:50 000 papirkart"));
    _maps.add(Map(description: "Flyfoto"));

    return _maps;
  }

  // Find folder on SDCard and installed maps
  Future<List> fetchStoredMaps() async {
    // SDCard is mounted on /storage/XXXX-XXXX (at least on Samsung), e.g. /storage/0123-4567
    // We have a file in map root directory that lists the installed maps and metadata
  }

  Future<List<Map>> fetchMaps() async {
    // Locally stored maps on SDCard only on Android - maybe downloadable maps in iOS later
    if (Platform.isAndroid) {
      print("platform is Android");
      var extStorage = await getExternalStorageDirectory();
      print("External storage: $extStorage");
    }
  }
}

class Map {
  // TODO: Enum types (topo, orto, ...)

  String type;
  String description;
  String url;
  double maxZoom;
  double minZoom;
  String attribution;

  Map(
      {String type,
      String description,
      String url,
      double maxZoom,
      double minZoom,
      String Atrribution}) {
    this.type;
  }
}
