import 'package:SarSys/services/image_cache_service.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ManagedCacheTileProvider extends TileProvider {
  final FileCacheService cache;
  const ManagedCacheTileProvider(this.cache);

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options) {
    return CachedNetworkImageProvider(getTileUrl(coords, options), cacheManager: cache);
  }
}
