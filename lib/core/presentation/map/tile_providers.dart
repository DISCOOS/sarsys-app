import 'dart:async';

import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/data/services/image_cache_service.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ManagedCacheTileProvider extends TileProvider {
  ManagedCacheTileProvider(
    this.cache, {
    @required this.connectivity,
  }) : _offline = connectivity.isOffline {
    connectivity.changes.listen((status) {
      _offline = status == ConnectivityStatus.offline;
    });
  }

  final StreamController<Null> _controller = StreamController.broadcast();
  Stream<Null> get onEvicted => _controller.stream;

  @override
  void dispose() {
    _controller?.close();
    _subscription?.cancel();
  }

  final FileCacheService cache;
  final ConnectivityService connectivity;
  final Map<ImageProvider, Tile> errorTiles = {};

  StreamSubscription _subscription;

  bool _offline;
  bool get offline => _offline;

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options) {
    return CachedNetworkImageProvider(getTileUrl(coords, options), cacheManager: cache);
  }

  void evictErrorTiles() {
    for (var key in errorTiles.keys) {
      _evict(key);
    }
    if (errorTiles.isNotEmpty) {
      _controller.add(null);
      errorTiles.clear();
    }
  }

  void _evict(ImageProvider key) {
    key.evict();
    if (key is CachedNetworkImageProvider) {
      cache.removeFile(key.url);
    }
  }

  void onError(Tile tile, dynamic error) {
    if (offline) {
      errorTiles[tile.imageProvider] = tile;
    } else {
      _evict(tile.imageProvider);
    }
  }
}
