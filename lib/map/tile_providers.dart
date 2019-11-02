import 'dart:io';

import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:SarSys/models/BaseMap.dart';

/// This class implements a managed network-based and managed tile cache
/// with a fallback error handling strategy. When more than [threshold]
/// number of tiles was not found or empty, the tile provider will
/// return [tileErrorImage] as tiles for all request until the number of
/// erroneous tiles are below the [threshold] again. This will minimise
/// UI "jank" by minimizing network timeouts.
class ManagedCacheTileProvider extends TileProvider {
  final ImageProvider tileErrorImage;
  final BaseCacheManager cacheManager;
  final TileErrorHandler tileErrorHandler;

  ManagedCacheTileProvider(
    this.cacheManager,
    this.tileErrorImage,
    TileErrorData data, {
    int threshold = TileErrorData.THRESHOLD,
    ValueChanged<TileErrorData> onFatal,
  })  : assert(data != null, "data can not be null"),
        this.tileErrorHandler = TileErrorHandler(
          onFatal: onFatal,
          threshold: threshold,
          data: data,
          onError: (error) => cacheManager.removeFile(error.key),
        );

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options) {
    final url = getTileUrl(coords, options);
    return tileErrorHandler.isFatal || tileErrorHandler.contains(url)
        ? _ensureImage(url)
        : ManagedCachedNetworkImageProvider(
            url,
            cacheManager,
            tileErrorHandler,
          );
  }

  ImageProvider _ensureImage(String url) {
    final info = cacheManager.getFileFromMemory(url);
    return info == null ? tileErrorImage : FileImage(info.file);
  }
}

/// [ManagedCacheTileProvider] companion class implementing image provider error handling
class ManagedCachedNetworkImageProvider extends CachedNetworkImageProvider {
  final TileErrorHandler handler;

  ManagedCachedNetworkImageProvider(
    String url,
    BaseCacheManager cacheManager,
    this.handler,
  ) : super(url, cacheManager: cacheManager);

  @override
  ImageStreamCompleter load(CachedNetworkImageProvider key) {
    return super.load(key)..addListener(handler.listen(key.url, (e) => TileError.toType(e)));
  }
}

/// This class implements a managed file-based [TileProvider] with
/// a fallback error handling strategy. When more than [threshold]
/// number of tiles was not found or empty, the tile provider will
/// return [tileErrorImage] as tiles for all request until the number of
/// erroneous tiles are below the [threshold] again. This will minimise
/// UI "jank" by file io exceptions.
class ManagedFileTileProvider extends TileProvider {
  final ImageProvider tileErrorImage;
  final TileErrorHandler tileErrorHandler;

  ManagedFileTileProvider(
    this.tileErrorImage,
    TileErrorData data, {
    int threshold = TileErrorData.THRESHOLD,
    ValueChanged<TileErrorData> onFatal,
  })  : assert(data != null, "data can not be null"),
        this.tileErrorHandler = TileErrorHandler(
          onFatal: onFatal,
          threshold: threshold,
          data: data,
        );

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options) {
    final url = getTileUrl(coords, options);
    return tileErrorHandler.isFatal || tileErrorHandler.contains(url) || File(url).existsSync() == false
        ? tileErrorImage
        : ManagedFileTileImageProvider(
            File(getTileUrl(coords, options)),
            tileErrorHandler,
          );
  }
}

/// [ManagedFileTileProvider] companion class implementing image provider error handling
class ManagedFileTileImageProvider extends FileImage {
  final TileErrorHandler handler;
  ManagedFileTileImageProvider(File file, this.handler) : super(file);

  @override
  ImageStreamCompleter load(FileImage key) {
    return super.load(key)..addListener(handler.listen(key.file.path, (e) => TileError.toType(e)));
  }
}

/// Type of tile errors handled by managed tile providers
enum TileErrorType { NotFound, CanNotOpen, IsEmpty, IsInvalid, Unknown }

String translateTileErrorType(TileErrorType type) {
  switch (type) {
    case TileErrorType.NotFound:
      return "ikke funnet";
    case TileErrorType.CanNotOpen:
      return "kan ikke åpnes";
    case TileErrorType.IsEmpty:
      return "er tom";
    case TileErrorType.IsInvalid:
      return "har feil dataformat";
    case TileErrorType.Unknown:
    default:
      return "feil ukjent";
  }
}

/// Tile error data object
class TileErrorData {
  static const int THRESHOLD = 3;

  final BaseMap map;
  final Map<String, TileError> keys = {};

  TileErrorData(this.map);

  bool isFatal({int threshold = THRESHOLD}) => threshold <= count();

  @override
  String toString() {
    return 'TileErrorData{map: $map, keys: $keys}';
  }

  Set<TileErrorType> explain({int threshold = THRESHOLD}) {
    Set<TileErrorType> seen = {};
    final result = TileErrorType.values.fold<Pair<Set<TileErrorType>, int>>(
      Pair.of(seen, 0),
      (combine, type) => _test(type, combine),
    );
    return threshold <= result.right ? result.left : {};
  }

  Pair<Set<TileErrorType>, int> _test(TileErrorType type, Pair<Set<TileErrorType>, int> state) {
    int count = this.count([type]);
    if (count > 0) state.left.add(type);
    return Pair.of(
      state.left,
      state.right + count,
    );
  }

  int count([
    List<TileErrorType> types = const [
      TileErrorType.NotFound,
      TileErrorType.CanNotOpen,
      TileErrorType.IsEmpty,
    ],
  ]) =>
      keys.values.fold(0, (count, error) => count + (types.contains(error.type) ? 1 : 0));
}

/// Tile error instance
class TileError implements Exception {
  final String key;
  final String message;
  final TileErrorType type;

  const TileError(this.key, this.message, this.type);

  @override
  String toString() {
    return 'TileError{key: $key, message: $message, type: $type}';
  }

  static const IS_EMPTY = "File was empty";
  static const NOT_FOUND = "Couldn't download or retrieve file";
  static const CANNOT_OPEN_FILE = "Cannot open file";
  static const IS_INVALID = "Could not instantiate image codec";

  static TileErrorType toType(exception) {
    String message = exception?.toString() ?? '';
    if (message.contains(NOT_FOUND)) return TileErrorType.NotFound;
    if (message.contains(CANNOT_OPEN_FILE)) return TileErrorType.CanNotOpen;
    if (message.contains(IS_EMPTY)) return TileErrorType.IsEmpty;
    if (message.contains(IS_INVALID)) return TileErrorType.IsInvalid;
    return TileErrorType.Unknown;
  }
}

/// This class implements a [TileError] handler using an [ImageStreamListener].
class TileErrorHandler {
  final int threshold;
  final TileErrorData data;
  final ValueChanged<TileError> onError;
  final ValueChanged<TileErrorData> onFatal;

  bool contains(String url) => data.keys.containsKey(url);

  bool get isFatal => data.isFatal(threshold: threshold);

  TileErrorHandler({
    @required this.data,
    @required this.onFatal,
    @required this.threshold,
    this.onError,
  });

  ImageStreamListener listen(String key, TileErrorType toType(exception)) {
    // Remove previous failure
    data.keys.remove(key);

    return ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {},
      onError: (dynamic exception, StackTrace stackTrace) {
        final type = toType(exception);
        final error = data.keys.putIfAbsent(key, () => TileError(key, "$exception", type));
        if (onError != null) onError(error);
        if (onFatal != null && data.count() == threshold) onFatal(data);
        if (kDebugMode) print(error);
      },
    );
  }
}
