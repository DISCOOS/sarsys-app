import 'dart:io';

import 'package:SarSys/features/app_config/domain/entities/AppConfig.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileCacheService extends BaseCacheManager {
  static const key = "libCachedImageTiles";

  static FileCacheService _instance;
  static int _mapCacheTTL;
  static int _mapCacheCapacity;

  factory FileCacheService(AppConfig config) {
    if (_instance == null || _mapCacheTTL != config.mapCacheTTL || _mapCacheCapacity != config.mapCacheCapacity) {
      _instance = new FileCacheService._(config.mapCacheTTL, config.mapCacheCapacity);
      _mapCacheTTL = config.mapCacheTTL;
      _mapCacheCapacity = config.mapCacheCapacity;
    }
    return _instance;
  }

  FileCacheService._(int ttl, int capacity)
      : super(
          key,
          maxAgeCacheObject: Duration(days: ttl),
          maxNrOfCacheObjects: capacity,
        );

  Future<String> getFilePath() async {
    Directory directory = await getApplicationSupportDirectory();
    return p.join(directory.path, key);
  }
}
