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
    //List<BaseMap> _offlineMaps = await fetchStoredMaps();
    _baseMaps.addAll(await fetchStoredMaps());
  }

  Future<List<BaseMap>> fetchOnlineMaps() async {
    // TODO: Get list off online maps from server instead
    return _assets.map((value) => BaseMap.fromJson(value)).toList();
  }

  // Find folder on SDCard and installed maps
  // SDCard is mounted on /storage/XXXX-XXXX (at least on Samsung), e.g. /storage/0123-4567
  // /storage/emulated and /storage/self is usually present and not searched
  // Other devices may mount under /mnt/media_rw
  // If we find a 'maps' directory here (on the root of the sdcard) we check for metadata.json in subfolder
  // Each tileset is in separate subdirectory under maps and in slippy z/x/y structure
  Future<List<BaseMap>> fetchStoredMaps() async {

      final completer = Completer<List<BaseMap>>();
      if(Platform.isAndroid) {
        // Ask for permission
        final controller = PermissionController(configBloc: _configBloc);
        controller.ask(
          controller.storageRequest.copyWith(onReady: () => completer.complete(_fetchStoredMaps())),
        );
      } else {
        completer.complete(_fetchStoredMaps());
      }
      return completer.future;


  }

  Future<List<BaseMap>> _fetchStoredMaps() async {
    List<BaseMap> maps = [];
    Directory baseDir = await _resolveDir();
    // Root
    await for (FileSystemEntity entity in baseDir.list(recursive: false, followLinks: false)) {
      if (basename(entity.path) != "emulated" && basename(entity.path) != "self" && entity is Directory) {
        // Second level, search for folder containing "maps" folder
        if (entity is Directory && basename(entity.path).toLowerCase() == "maps") {
          // Search for subfolders in "maps" containing metadata file
          await for (FileSystemEntity entity in entity.list(recursive: false, followLinks: false)) {
            if (entity is Directory) {
              final File metadataFile = File("${entity.path}/metadata.json");
              if (metadataFile.existsSync()) {
                try {
                  BaseMap map = BaseMap.fromJson(
                    json.decode(metadataFile.readAsStringSync()),
                  );
                  maps.add(
                    map.cloneWith(
                      url: "${entity.path}/{z}/{x}/{y}.png",
                      previewFile: _toSafe(entity, map),
                    ),
                  );
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
    return maps;
  }

  String _toSafe(Directory entity, BaseMap _baseMap) {
    final file = File("${entity.path}/${_baseMap.previewFile}");
    return file.existsSync() ? file.path : null;
  }

  Future<Directory> _resolveDir() async {
    return Platform.isIOS ? await getApplicationDocumentsDirectory() : await getExternalStorageDirectory();
  }
}
