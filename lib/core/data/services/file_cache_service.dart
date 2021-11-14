

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/src/storage/file_system/file_system.dart' as c;

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';

class FileCacheService extends CacheManager implements Service {
  static const key = "libCachedImageTiles";

  static FileCacheService? _instance;
  static int? _mapCacheTTL;
  static int? _mapCacheCapacity;

  factory FileCacheService(AppConfig config) {
    if (_instance == null || _mapCacheTTL != config!.mapCacheTTL || _mapCacheCapacity != config.mapCacheCapacity) {
      _instance = new FileCacheService._(config!.mapCacheTTL, config.mapCacheCapacity);
      _mapCacheTTL = config.mapCacheTTL;
      _mapCacheCapacity = config.mapCacheCapacity;
    }
    return _instance!;
  }

  FileCacheService._(int ttl, int capacity)
      : super(
          Config(
            key,
            maxNrOfCacheObjects: capacity,
            stalePeriod: Duration(days: ttl),
            repo: JsonCacheInfoRepository(databaseName: key),
            fileSystem: IOFileSystem(key),
          ),
        );

  Future<String> getFilePath() async {
    final root = await getApplicationSupportDirectory();
    return p.join(root.path, key);
  }
}

class IOFileSystem extends c.FileSystem {
  IOFileSystem(this.key) : _dir = createDirectory(key);

  final Future<Directory> _dir;
  final String key;

  static Future<Directory> createDirectory(String key) async {
    var baseDir = await getApplicationSupportDirectory();
    var path = p.join(baseDir.path, key);

    var fs = const LocalFileSystem();
    var directory = fs.directory((path));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<File> createFile(String name) async {
    assert(name != null);
    var directory = (await _dir);
    if (!(await directory.exists())) {
      await createDirectory(key);
    }
    return directory.childFile(name);
  }
}
