class MaptileService {
  static final MaptileService _singleton = new MaptileService._internal();
  List<BaseMap> _baseMaps = [];

  factory MaptileService() {
    return _singleton;
  }

  MaptileService._internal() {
    initMaps();
  }

  void initMaps() async {
    _baseMaps.addAll(await fetchOnlineMaps());
    _baseMaps.addAll(await fetchStoredMaps());
  }

  Future<List<BaseMap>> fetchOnlineMaps() async {
    List<BaseMap> _maps = [];

    // TODO: Get list off online maps from server instead (https://sporing.rodekors.no/api/appconfig loaded during startup?)
    _maps.add(BaseMap(
      name: "topo4",
      description: "Topografisk",
      previewFile: "topo4.png",
      minZoom: 5,
      maxZoom: 18,
      offline: false,
      url: "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}",
    ));
    _maps.add(BaseMap(
      name: 'toporaster3',
      description: "Topografisk (papirkart)",
      previewFile: "toporaster3.png",
      minZoom: 5,
      maxZoom: 18,
      offline: false,
      url: "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=toporaster3&zoom={z}&x={x}&y={y}",
    ));
    _maps.add(BaseMap(
      name: 'norortho',
      description: "Flyfoto",
      previewFile: "ortofoto.png",
      minZoom: 5,
      maxZoom: 18,
      offline: false,
      url: "https://maptiles1.finncdn.no/tileService/1.0.3/norortho/{z}/{x}/{y}.png",
    ));
    _maps.add(BaseMap(
      name: 'norhybrid',
      description: "Hybrid",
      previewFile: "hybrid.png",
      minZoom: 5,
      maxZoom: 18,
      offline: false,
      url: "https://maptiles1.finncdn.no/tileService/1.0.3/norhybrid/{z}/{x}/{y}.png",
    ));
    _maps.add(BaseMap(
      name: 'sjokart',
      description: "Sjøkart",
      previewFile: "sjokart.png",
      minZoom: 5,
      maxZoom: 18,
      offline: false,
      url: "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=sjokartraster&zoom={z}&x={x}&y={y}",
    ));

    return _maps;
  }

  // Find folder on SDCard and installed maps
  // SDCard is mounted on /storage/XXXX-XXXX (at least on Samsung), e.g. /storage/0123-4567
  // /storage/emulated and /storage/self is usually present and not searched
  // Other devices may mount under /mnt/media_rw
  // If we find a maps directory here (on the root of the sdcard) we check for metadata.json in subfolder
  // Each tileset is in separate subdirectory under maps and in slippy z/x/y structure
  Future<List<BaseMap>> fetchStoredMaps() async {
    List<BaseMap> _maps = [];

    /* TODO: Fix fetching stored maps. Plugin seems to fail on iOS, remove for now and investigate alternatives
    // Get permission
    Map<PermissionGroup, PermissionStatus> permissions =
        await PermissionHandler().requestPermissions([PermissionGroup.storage]);
//     Plugin seems to fail on iOS, remove for now and investigate alternatives

    if (true) {
      Directory baseDir =
          Platform.isIOS ? await getApplicationDocumentsDirectory() : await getExternalStorageDirectory();
      // Root
      await for (FileSystemEntity entity in baseDir.list(recursive: false, followLinks: false)) {
        if (basename(entity.path) != "emulated" && basename(entity.path) != "self" && entity is Directory) {
          // Second lenvel, search for folder containing "maps" folder
          await for (FileSystemEntity entity in entity.list(recursive: false, followLinks: false)) {
            if (entity is Directory && basename(entity.path).toLowerCase() == "maps") {
              // Search for subfolders in "maos" containing metadata file
              await for (FileSystemEntity entity in entity.list(recursive: false, followLinks: false)) {
                if (entity is Directory) {
                  final File metadataFile = File("${entity.path}/metadata.json");
                  final File previewFile = File("${entity.path}/preview.png");
                  if (metadataFile.existsSync()) {
                    try {
                      // TODO: Validate metadata (in class named constructor?)
                      var mapMetadata = jsonDecode(metadataFile.readAsStringSync());
                      BaseMap _baseMap = new BaseMap(
                          name: mapMetadata["name"],
                          description: mapMetadata["description"],
                          minZoom: mapMetadata["minzoom"].toDouble(),
                          maxZoom: mapMetadata["maxzoom"].toDouble(),
                          attribution: mapMetadata["attribution"],
                          url: entity.path,
                          offline: true);

                      if (metadataFile.existsSync()) {
                        _baseMap.previewFile = previewFile.path;
                      }
                      _maps.add(_baseMap);
                      print("");
                    } on FormatException catch (e) {
                      // Never mind, just don't import.
                      print("formatexception $e");
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    */
    return _maps;
  }

  Future<List<BaseMap>> fetchMaps() async {
//    List<BaseMap> _maps = [];
//    // Locally stored maps on SDCard only on Android - maybe downloadable maps in iOS later
//    if (Platform.isAndroid) {
//      _maps.addAll(await fetchStoredMaps());
//    }
//    _maps.addAll(await fetchOnlineMaps());
//    return _maps;
    return _baseMaps;
  }
}

class BaseMap {
  String name;
  String description;
  String url;
  double maxZoom;
  double minZoom;
  String attribution;
  bool offline;
  String previewFile;

  BaseMap(
      {this.name,
      this.description,
      this.url,
      this.maxZoom = 14,
      this.minZoom = 5,
      this.attribution = "",
      this.offline = false,
      this.previewFile});
}
