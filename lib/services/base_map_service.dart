import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/BaseMap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class BaseMapService {
  static const ASSET = "assets/config/base_map.json";

  static BaseMapService _instance;

  final List<BaseMap> _baseMaps = [Defaults.baseMap];

  List<dynamic> _assets = [];

  bool get isReady => _baseMaps.isNotEmpty;

  List<BaseMap> get baseMaps => _baseMaps.toList();

  factory BaseMapService() {
    if (_instance == null) {
      _instance = new BaseMapService._internal();
    }
    return _instance;
  }

  BaseMapService._internal();

  Future init() async {
    if (_assets.isEmpty) {
      _assets = json.decode(await rootBundle.loadString(ASSET));
    }
    _baseMaps.clear();
    _baseMaps.addAll(await fetchOnlineMaps());
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
    Set<BaseMap> baseMaps = {};
    final baseDirs = await _resolveDirs();

    if (kDebugMode) print(baseDirs);

    // Search roots
    for (Directory baseDir in baseDirs) {
      // Skip "emulated" and "self" directories
      for (FileSystemEntity root in _search(baseDir, (e) => _isRoot(e) && _isSearchable(e), recursive: false)) {
        // Search for "maps" directories
        for (FileSystemEntity maps in _search(root, (e) => _isMaps(e), recursive: false)) {
          // Search for map tiles metadata
          for (FileSystemEntity metadata in _search(maps, (e) => _isMetaData(e), recursive: true)) {
            if (kDebugMode) print(metadata);
            try {
              final map = BaseMap.fromJson(
                json.decode(File(metadata.path).readAsStringSync()),
              );
              baseMaps.add(
                map.cloneWith(
                  url: "${metadata.parent.path}/{z}/{x}/{y}.png",
                  previewFile: _toSafe(metadata.parent, map),
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

    return baseMaps.toList();
  }

  bool _isRoot(FileSystemEntity e) => basename(e.path) != "emulated" && basename(e.path) != "self";

  bool _isSearchable(FileSystemEntity e) => e is Directory && e.statSync().modeString().startsWith(RegExp(r'.{3}r'));

  bool _isMaps(FileSystemEntity e) => e is Directory && basename(e.path) == "maps";

  bool _isMetaData(FileSystemEntity e) => basename(e.path) == "metadata.json";

  List<FileSystemEntity> _search(
    Directory dir,
    bool match(FileSystemEntity entity), {
    bool recursive: true,
  }) {
    final matches = dir.listSync(recursive: recursive, followLinks: false).where((entity) => match(entity)).toList();
    if (match(dir)) matches.add(dir);
    return matches;
  }

  String _toSafe(Directory entity, BaseMap _baseMap) {
    final file = File("${entity.path}/${_baseMap.previewFile}");
    return file.existsSync() ? file.path : null;
  }

  Future<List<Directory>> _resolveDirs() async {
    return [
      await getApplicationDocumentsDirectory(),
      if (Platform.isAndroid) ...await getExternalStorageDirectories(),
      if (Platform.isAndroid) ...await getExternalStorageDirectories(type: StorageDirectory.pictures),
      if (Platform.isAndroid) ...await getExternalStorageDirectories(type: StorageDirectory.documents),
      if (Platform.isAndroid) ...await getExternalStorageDirectories(type: StorageDirectory.downloads),
    ];
  }
}
