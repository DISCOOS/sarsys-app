import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec, Codec;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:SarSys/models/BaseMap.dart';

/// This class implements a managed network-based and managed tile cache
/// with a fallback error handling strategy. When more than [threshold]
/// number of tiles was not found or empty, the tile provider will
/// return [errorImage] as tiles for all request until the number of
/// erroneous tiles are below the [threshold] again. This will minimise
/// UI "jank" by minimizing network timeouts.
class ManagedCacheTileProvider extends TileProvider {
  final bool offline;
  final TileErrorData data;
  final String offlineAsset;
  final ImageProvider offlineImage;
  final ImageProvider errorImage;
  final BaseCacheManager cacheManager;
  final TileErrorHandler errorHandler;

  ManagedCacheTileProvider(
    this.data, {
    @required this.offline,
    @required this.offlineAsset,
    @required this.offlineImage,
    @required this.errorImage,
    @required this.cacheManager,
    int threshold = TileErrorData.THRESHOLD,
    ValueChanged<TileErrorData> onFatal,
  })  : assert(data != null, "data can not be null"),
        this.errorHandler = TileErrorHandler(
          onFatal: onFatal,
          threshold: threshold,
          data: data,
          onError: (error) => cacheManager.removeFile(error.key),
        );

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options) {
    final url = getTileUrl(coords, options);
    return offline || errorHandler.contains(url) ? _ensureImage(url) : _refreshImage(url);
  }

  ImageProvider _refreshImage(String url) => ManagedCachedNetworkImageProvider(
        url: url,
        offline: offline,
        cacheManager: cacheManager,
        offlineAsset: offlineAsset,
        errorHandler: errorHandler,
        onPlaceholder: _addPlaceholder,
      );

  ImageProvider _ensureImage(String url) {
    final info = cacheManager.getFileFromMemory(url);
    return info == null ? (offline ? offlineImage : errorImage) : FileImage(info.file);
  }

  ImageProvider _addPlaceholder(ImageProvider key) {
    data.placeholders.add(key);
    return key;
  }
}

/// [ManagedCacheTileProvider] companion class implementing image provider error handling
class ManagedCachedNetworkImageProvider extends ImageProvider<CachedNetworkImageProvider>
    implements CachedNetworkImageProvider {
  ManagedCachedNetworkImageProvider({
    @required this.url,
    @required this.errorHandler,
    @required this.offline,
    @required this.offlineAsset,
    @required this.onPlaceholder,
    @required this.cacheManager,
    this.headers,
    this.errorListener,
    this.scale = 1.0,
  })  : assert(url != null),
        assert(scale != null);

  @override
  final BaseCacheManager cacheManager;

  /// Web url of the image to load
  @override
  final String url;

  /// Scale of the image
  @override
  final double scale;

  /// Listener to be called when images fails to load.
  @override
  final ErrorListener errorListener;

  /// Set headers for the image provider, for example for authentication
  @override
  final Map<String, String> headers;

  final bool offline;
  final String offlineAsset;
  final TileErrorHandler errorHandler;
  final ValueChanged<ImageProvider> onPlaceholder;

  ui.Codec placeholder;

  @override
  Future<CachedNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(CachedNetworkImageProvider key, DecoderCallback decode) {
    return (offline ? _loadFromCache(key) : _load(key, decode))
      ..addListener(errorHandler.listen(key, key.url, (e) => TileError.toType(e)));
  }

  ImageStreamCompleter _load(CachedNetworkImageProvider key, DecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode).first,
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'Image provider: $this \n Image key: $key',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        );
      },
    );
  }

  Stream<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) async* {
    assert(key == this);
    try {
      var mngr = cacheManager ?? DefaultCacheManager();
      await for (var result in mngr.getFileStream(key.url, withProgress: true, headers: headers)) {
        if (result is DownloadProgress) {
          chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: result.downloaded,
            expectedTotalBytes: result.totalSize,
          ));
        }
        if (result is FileInfo) {
          var file = result.file;
          var bytes = await file.readAsBytes();
          var decoded = await decode(bytes);
          yield decoded;
        }
      }
    } catch (e) {
      errorListener?.call();
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }

  /// Only called when offline
  ImageStreamCompleter _loadFromCache(key) => MultiFrameImageStreamCompleter(
        codec: _loadAsyncFromCache(key),
        scale: key.scale,
        informationCollector: () sync* {
          yield DiagnosticsProperty<ImageProvider>(
            'Image provider: $this \n Image key: $key',
            this,
            style: DiagnosticsTreeStyle.errorProperty,
          );
        },
      );

  /// Adapted from [CachedNetworkImageProvider]
  Future<ui.Codec> _loadAsyncFromCache(CachedNetworkImageProvider key) async {
    Uint8List bytes;
    ui.Codec codec = placeholder;
    final info = await cacheManager.getFileFromCache(url);
    if (info == null) {
      // Optimization
      if (placeholder == null) {
        final data = await rootBundle.load(offlineAsset);
        bytes = data.buffer.asUint8List();
        placeholder = await toCodec(bytes);
        onPlaceholder(key);
      }
    } else {
      final file = info.file;
      bytes = await file.readAsBytes();
      codec = await toCodec(bytes);
    }

    return codec;
  }

  Future<ui.Codec> toCodec(Uint8List bytes) async {
    if (bytes.lengthInBytes == 0) {
      if (errorListener != null) errorListener();
      throw new Exception(TileError.IS_EMPTY);
    }
    return ui.instantiateImageCodec(bytes);
  }

  @override
  bool operator ==(dynamic other) {
    if (other is CachedNetworkImageProvider) {
      return url == other.url && scale == other.scale;
    }
    return false;
  }

  @override
  int get hashCode => hashValues(url, scale);

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}

/// This class implements a managed file-based [TileProvider] with
/// a fallback error handling strategy. When more than [threshold]
/// number of tiles was not found or empty, the tile provider will
/// return [errorImage] as tiles for all request until the number of
/// erroneous tiles are below the [threshold] again. This will minimise
/// UI "jank" by file io exceptions.
class ManagedFileTileProvider extends TileProvider {
  final ImageProvider errorImage;
  final TileErrorHandler errorHandler;
  static Map<String, ImageProvider> images = {};

  ManagedFileTileProvider(
    TileErrorData data, {
    @required this.errorImage,
    int threshold = TileErrorData.THRESHOLD,
    ValueChanged<TileErrorData> onFatal,
  })  : assert(data != null, "data can not be null"),
        this.errorHandler = TileErrorHandler(
          onFatal: onFatal,
          threshold: threshold,
          data: data,
          onError: (error) => images.remove(error.key),
        );

  @override
  ImageProvider getImage(Coords<num> coords, TileLayerOptions options) {
    final url = getTileUrl(coords, options);
    final file = File(url);
    return errorHandler.contains(file.path) ? _ensureImage(file) : _refreshImage(file);
  }

  ManagedFileTileImageProvider _refreshImage(File file) {
    final key = ManagedFileTileImageProvider(
      file,
      errorHandler,
    );
    images.putIfAbsent(file.path, () => key);
    return key;
  }

  ImageProvider _ensureImage(File file) {
    final image = images[file.path];
    return image == null ? errorImage : image;
  }
}

/// [ManagedFileTileProvider] companion class implementing image provider error handling
class ManagedFileTileImageProvider extends FileImage {
  final TileErrorHandler handler;
  ManagedFileTileImageProvider(File file, this.handler) : super(file);

  @override
  ImageStreamCompleter load(FileImage key, DecoderCallback decode) {
    return super.load(key, decode)
      ..addListener(
        handler.listen(key, key.file.path, (e) => TileError.toType(e)),
      );
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
  static const int THRESHOLD = 48;

  final BaseMap map;
  final Map<String, TileError> errors = {};
  final Set<ImageProvider> placeholders = {};

  TileErrorData(this.map);

  bool isFatal({int threshold = THRESHOLD}) => threshold <= count();

  @override
  String toString() {
    return 'TileErrorData{map: $map, errors: $errors}';
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
      errors.values.fold(0, (count, error) => count + (types.contains(error.type) ? 1 : 0));
}

/// Tile error instance
class TileError implements Exception {
  final String key;
  final String message;
  final TileErrorType type;
  final ImageProvider image;

  const TileError(
    this.key,
    this.image,
    this.message,
    this.type,
  );

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

  bool contains(String url) => data.errors.containsKey(url);

  bool get isFatal => data.isFatal(threshold: threshold);

  TileErrorHandler({
    @required this.data,
    @required this.onFatal,
    @required this.threshold,
    this.onError,
  });

  ImageStreamListener listen(ImageProvider image, String key, TileErrorType toType(exception)) {
    // Remove previous failure
    data.errors.remove(key);

    return ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {},
      onError: (dynamic exception, StackTrace stackTrace) {
        final type = toType(exception);
        final error = data.errors.putIfAbsent(key, () => TileError(key, image, "$exception", type));
        data.placeholders.add(image);
        if (onError != null) onError(error);
        if (onFatal != null && data.count() == threshold) onFatal(data);
        if (kDebugMode) print(error);
      },
    );
  }
}
