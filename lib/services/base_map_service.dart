import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/BaseMap.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class BaseMapService {
  static const ASSET = "assets/config/base_map.json";

  static BaseMapService _instance;

  final AppConfigBloc _configBloc;
  final List<BaseMap> _baseMaps = [Defaults.baseMap];

  List<dynamic> _assets = [];

  bool get isReady => _baseMaps.isNotEmpty;

  List<BaseMap> get baseMaps => _baseMaps.toList();

  factory BaseMapService(AppConfigBloc bloc) {
    if (_instance == null) {
      _instance = new BaseMapService._internal(bloc);
    }
    return _instance;
  }

  BaseMapService._internal(AppConfigBloc bloc) : _configBloc = bloc {
    init();
  }

  void init() async {
    if (_assets.isEmpty) {
      _assets = json.decode(await rootBundle.loadString(ASSET));
    }
    _baseMaps.clear();
    _baseMaps.addAll(await fetchOnlineMaps());
    _baseMaps.addAll(await fetchStoredMaps());
  }

  Future<List<BaseMap>> fetchOnlineMaps() async {
    List<BaseMap> maps = [];

    // TODO: Get list off online maps from server instead
    maps.addAll(_assets.map((value) => BaseMap.fromJson(value)).toList());
//
//    maps.add(BaseMap(
//      name: "topo4",
//      description: "Topografisk",
//      previewFile: "topo4.png",
//      minZoom: Defaults.minZoom,
//      maxZoom: Defaults.maxZoom,
//      offline: false,
//      url: "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}",
//      subdomains: [
//        'opencache',
//        'opencache2',
//        'opencache3',
//      ],
//    ));
//    maps.add(BaseMap(
//      name: 'normaphd',
//      description: "Topogafisk HD",
//      previewFile: "normaphd.png",
//      minZoom: Defaults.minZoom,
//      maxZoom: Defaults.maxZoom,
//      offline: false,
//      url: "https://maptiles.finncdn.no/tileService/1.0.3/normaphd/{z}/{x}/{y}.png",
//    ));
//    maps.add(BaseMap(
//      name: 'norortho',
//      description: "Flyfoto",
//      previewFile: "ortofoto.png",
//      minZoom: Defaults.minZoom,
//      maxZoom: Defaults.maxZoom,
//      offline: false,
//      url: "https://maptiles.finncdn.no/tileService/1.0.3/norortho/{z}/{x}/{y}.png",
//    ));
//    maps.add(BaseMap(
//      name: 'norhybrid',
//      description: "Hybrid",
//      previewFile: "hybrid.png",
//      minZoom: Defaults.minZoom,
//      maxZoom: Defaults.maxZoom,
//      offline: false,
//      url: "https://maptiles.finncdn.no/tileService/1.0.3/norhybrid/{z}/{x}/{y}.png",
//    ));
//    maps.add(BaseMap(
//      name: 'toporaster3',
//      description: "Papirkart N50",
//      previewFile: "toporaster3.png",
//      minZoom: Defaults.minZoom,
//      maxZoom: Defaults.maxZoom,
//      offline: false,
//      url: "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=toporaster3&zoom={z}&x={x}&y={y}",
//      subdomains: [
//        'opencache',
//        'opencache2',
//        'opencache3',
//      ],
//    ));
//    maps.add(BaseMap(
//      name: 'sjokart',
//      description: "Sjøkart N50",
//      previewFile: "sjokart.png",
//      minZoom: Defaults.minZoom,
//      maxZoom: Defaults.maxZoom,
//      offline: false,
//      url: "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=sjokartraster&zoom={z}&x={x}&y={y}",
//      subdomains: [
//        'opencache',
//        'opencache2',
//        'opencache3',
//      ],
//    ));

    return maps;
  }

  // Find folder on SDCard and installed maps
  // SDCard is mounted on /storage/XXXX-XXXX (at least on Samsung), e.g. /storage/0123-4567
  // /storage/emulated and /storage/self is usually present and not searched
  // Other devices may mount under /mnt/media_rw
  // If we find a maps directory here (on the root of the sdcard) we check for metadata.json in subfolder
  // Each tileset is in separate subdirectory under maps and in slippy z/x/y structure
  Future<List<BaseMap>> fetchStoredMaps() async {
    final completer = Completer<List<BaseMap>>();
    // Ask for permission
    final controller = PermissionController(configBloc: _configBloc);
    controller.ask(
      controller.storageRequest.copyWith(onReady: () => completer.complete(_fetchStoredMaps())),
    );
    return completer.future;
  }

  Future<List<BaseMap>> _fetchStoredMaps() async {
    List<BaseMap> maps = [];
    Directory baseDir = await _resolveDir();
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
                if (metadataFile.existsSync()) {
                  try {
                    BaseMap _baseMap = BaseMap.fromJson(
                      json.decode(metadataFile.readAsStringSync()),
                    );
                    //                      if (metadataFile.existsSync()) {
                    //                        _baseMap.previewFile = previewFile.path;
                    //                      }
                    maps.add(_baseMap);
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
    return maps;
  }

  Future<Directory> _resolveDir() async {
    return Platform.isIOS ? await getApplicationDocumentsDirectory() : await getExternalStorageDirectory();
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
