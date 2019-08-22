import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

class ManagedCacheTileProvider extends TileProvider {
  final BaseCacheManager cacheManager;

  ManagedCacheTileProvider(this.cacheManager);

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options) {
    return CachedNetworkImageProvider(getTileUrl(coords, options), cacheManager: this.cacheManager);
  }
}
