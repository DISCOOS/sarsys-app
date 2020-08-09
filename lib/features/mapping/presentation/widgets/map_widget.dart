import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:latlong/latlong.dart';
import 'package:wakelock/wakelock.dart';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/permission_controller.dart';
import 'package:SarSys/core/page_state.dart';
import 'package:SarSys/features/mapping/presentation/widgets/basemap_card.dart';
import 'package:SarSys/features/mapping/presentation/layers/coordate_layer.dart';
import 'package:SarSys/features/mapping/presentation/layers/device_layer.dart';
import 'package:SarSys/features/mapping/presentation/layers/measure_layer.dart';
import 'package:SarSys/features/mapping/presentation/layers/personnel_layer.dart';
import 'package:SarSys/features/mapping/presentation/map_controls.dart';
import 'package:SarSys/features/mapping/presentation/painters.dart';
import 'package:SarSys/features/mapping/presentation/my_location_controller.dart';
import 'package:SarSys/features/mapping/presentation/tile_providers.dart';
import 'package:SarSys/features/mapping/presentation/layers/scalebar.dart';
import 'package:SarSys/features/mapping/presentation/tools/position_tool.dart';
import 'package:SarSys/features/mapping/presentation/tools/device_tool.dart';
import 'package:SarSys/features/mapping/presentation/tools/map_tools.dart';
import 'package:SarSys/features/mapping/presentation/tools/measure_tool.dart';
import 'package:SarSys/features/mapping/presentation/tools/personnel_tool.dart';
import 'package:SarSys/features/mapping/presentation/tools/poi_tool.dart';
import 'package:SarSys/features/mapping/presentation/tools/unit_tool.dart';
import 'package:SarSys/features/mapping/presentation/layers/unit_layer.dart';
import 'package:SarSys/core/domain/models/BaseMap.dart';
import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/data/services/image_cache_service.dart';
import 'package:SarSys/features/mapping/data/services/base_map_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/mapping/presentation/layers/poi_layer.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_search.dart';
import 'package:SarSys/features/mapping/presentation/layers/my_location.dart';
import 'package:SarSys/core/presentation/widgets/filter_sheet.dart';

import '../models/map_widget_state_model.dart';

typedef ToolCallback = void Function(MapTool tool);

class MapWidget extends StatefulWidget {
  final bool interactive;
  final bool withSearch;
  final bool withControls;
  final bool withControlsZoom;
  final bool withControlsTool;
  final bool withControlsLayer;
  final bool withControlsBaseMap;
  final bool withControlsLocateMe;
  final bool withScaleBar;
  final bool withCoordsPanel;

  final bool withPOIs;
  final bool withUnits;
  final bool withPersonnel;
  final bool withDevices;
  final bool withTracking;

  final bool withRead;
  final bool withWrite;
  final bool readZoom;
  final bool readCenter;
  final bool readLayers;

  final String writeKeySuffix;

  final TapCallback onTap;
  final Operation operation;
  final ActionCallback onMessage;
  final ToolCallback onToolChange;
  final PositionCallback onPositionChanged;
  final MapWidgetController mapController;

  final GestureTapCallback onOpenDrawer;

  /// Zoom map on given
  final double zoom;

  /// Center map on given point [center]. If [fitBounds] is given [center] is overridden
  final LatLng center;

  /// Fit map to given bounds. If [fitBounds] is given [center] is overridden
  final LatLngBounds fitBounds;

  /// If [fitBounds] is given, control who bounds is fitted with [fitBoundOptions]
  final FitBoundsOptions fitBoundOptions;

  /// Show retired units and personnel
  final bool showRetired;

  /// List of map layers to show
  final List<String> showLayers;

  /// Control offset from top of map canvas
  final double withControlsOffset;

  /// [GlobalKey] for sharing map state between parent widgets
  final GlobalKey sharedKey;

  MapWidget({
    Key key,
    this.zoom,
    this.center,
    this.operation,
    this.fitBounds,
    this.sharedKey,
    this.fitBoundOptions = FIT_BOUNDS_OPTIONS,
    this.interactive = true,
    this.withPOIs = true,
    this.withUnits = true,
    this.withPersonnel = true,
    this.withDevices = true,
    this.withSearch = false,
    this.withControls = false,
    this.withControlsZoom = false,
    this.withControlsTool = false,
    this.withControlsLayer = false,
    this.withControlsBaseMap = false,
    this.withControlsOffset = 100.0,
    this.withControlsLocateMe = false,
    this.withScaleBar = false,
    this.withTracking = true,
    this.withCoordsPanel = false,
    this.withRead = false,
    this.withWrite = false,
    this.readZoom = false,
    this.readCenter = false,
    this.readLayers = false,
    this.showRetired = false,
    this.writeKeySuffix,
    this.showLayers = MapWidgetState.ALL_LAYERS,
    this.onTap,
    this.onMessage,
    this.onPositionChanged,
    this.onToolChange,
    this.onOpenDrawer,
    Image placeholder,
    MapController mapController,
  })  : this.mapController = mapController ?? MapWidgetController(),
        super(key: key);

  @override
  MapWidgetState createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> with TickerProviderStateMixin {
  static const STATE = "incident_map";
  static const STATE_FILTERS = "filters";
  static const STATE_ZOOM = "zoom";
  static const STATE_CENTER = "center";
  static const STATE_BASE_MAP = "baseMap";
  static const STATE_FOLLOWING = "following";
  static const LAYER_POI = "Interessepunkt";
  static const LAYER_UNIT = "Enheter";
  static const LAYER_PERSONNEL = "Mannskap";
  static const LAYER_DEVICE = "Apparater";
  static const LAYER_TRACKING = "Sporing";
  static const LAYER_COORDS = "Koordinater";
  static const LAYER_SCALE = "Målestokk";

  /// All layers available
  static const ALL_LAYERS = [
    LAYER_POI,
    LAYER_UNIT,
    LAYER_PERSONNEL,
    LAYER_TRACKING,
    LAYER_DEVICE,
    LAYER_SCALE,
    LAYER_COORDS,
  ];

  /// Layers enabled by default
  static const DEFAULT_LAYERS_ENABLED = [
    LAYER_POI,
    LAYER_UNIT,
    LAYER_SCALE,
  ];

  final _uniqueMapKey = UniqueKey();
  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  BaseMap _currentBaseMap;
  BaseMapService _baseMapService;

  LatLng _center;
  LatLng _searchMatch;
  double _zoom = Defaults.zoom;

  MapControls _mapControls;
  MapWidgetController _mapController;
  MapToolController _mapToolController;
  MyLocationController _locationController;
  PermissionController _permissionController;

  /// Conditionally set during initialization
  Future<LatLng> _locationRequest;

  ValueNotifier<MapControlState> _isLocating = ValueNotifier(MapControlState());
  ValueNotifier<MapControlState> _isMeasuring = ValueNotifier(MapControlState());

  Set<String> _useLayers;
  List<LayerOptions> _layerOptions = [];

  // Prevent location updates after dispose
  bool _disposed = false;

  bool _wakeLockWasOn;
  bool _hasFitToBounds = false;
  bool _attemptRestore = true;

  /// Placeholder shown when a tile fails to load
  final ImageProvider _tileErrorImage = Image.asset("assets/error_tile.png").image;

  /// Placeholder shown while loading images
  final ImageProvider _tilePendingImage = Image.asset("assets/pending_tile.png").image;

  /// Placeholder shown when tiles are not found in offline mode
  final ImageProvider _tileOfflineImage = Image.asset("assets/offline_tile.png").image;

  /// Flag indicating that network connection is offline
  bool _offline = false;

  /// Tile provider
  ManagedCacheTileProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _disposed = true;
    _mapController.cancel();
    _mapController.progress.removeListener(_onMoveProgress);
    _mapToolController?.dispose();
    _locationController?.dispose();
    _isLocating?.dispose();
    _isMeasuring?.dispose();
    _permissionController?.dispose();
    _isLocating = null;
    _isMeasuring = null;
    _mapController = null;
    _mapToolController = null;
    _locationController = null;
    _permissionController = null;

    _restoreWakeLock();

    super.dispose();
  }

  @override
  void didUpdateWidget(MapWidget old) {
    super.didUpdateWidget(old);
    // Assumes that 'equals'-method is up to date!
    if (!equals(widget, old)) {
      _setup(
        wasZoom: widget.zoom != old.zoom,
      );
    }
  }

  bool equals(MapWidget oldMap, MapWidget newMap) =>
      identical(oldMap, newMap) ||
      oldMap.interactive == newMap.interactive &&
          oldMap.withSearch == newMap.withSearch &&
          oldMap.withControls == newMap.withControls &&
          oldMap.withControlsZoom == newMap.withControlsZoom &&
          oldMap.withControlsTool == newMap.withControlsTool &&
          oldMap.withControlsLayer == newMap.withControlsLayer &&
          oldMap.withControlsBaseMap == newMap.withControlsBaseMap &&
          oldMap.withControlsOffset == newMap.withControlsOffset &&
          oldMap.withControlsLocateMe == newMap.withControlsLocateMe &&
          oldMap.withScaleBar == newMap.withScaleBar &&
          oldMap.withCoordsPanel == newMap.withCoordsPanel &&
          oldMap.withPOIs == newMap.withPOIs &&
          oldMap.withUnits == newMap.withUnits &&
          oldMap.withPersonnel == newMap.withPersonnel &&
          oldMap.withDevices == newMap.withDevices &&
          oldMap.withTracking == newMap.withTracking &&
          oldMap.withRead == newMap.withRead &&
          oldMap.withWrite == newMap.withWrite &&
          oldMap.readZoom == newMap.readZoom &&
          oldMap.readCenter == newMap.readCenter &&
          oldMap.readLayers == newMap.readLayers &&
          oldMap.operation == newMap.operation &&
          oldMap.onTap == newMap.onTap &&
          oldMap.onMessage == newMap.onMessage &&
          oldMap.onToolChange == newMap.onToolChange &&
          oldMap.mapController == newMap.mapController &&
          oldMap.onOpenDrawer == newMap.onOpenDrawer &&
          oldMap.zoom == newMap.zoom &&
          oldMap.center == newMap.center &&
          oldMap.fitBounds == newMap.fitBounds &&
          oldMap.fitBoundOptions == newMap.fitBoundOptions &&
          oldMap.showLayers == newMap.showLayers &&
          oldMap.showRetired == newMap.showRetired;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (mounted) {
      _initWakeLock();

      // Ensure all controllers are set
      _ensureMapToolController();
      _ensureLocationControllers();

      // Ensure base maps are loaded from storage
      _ensureBaseMaps();

      // Only ensure center if not set already
      _center ??= _ensureCenter();

      if (_attemptRestore) {
        _zoom = _readState(STATE_ZOOM, defaultValue: widget.zoom ?? Defaults.zoom, read: widget.readZoom);
        _center = _readState(STATE_CENTER, defaultValue: _ensureCenter(), read: widget.readCenter);
        _attemptRestore = false;
      }

      _tileProvider?.evictErrorTiles();
      _tileProvider = ManagedCacheTileProvider(
        FileCacheService(
          context.bloc<AppConfigBloc>().config,
        ),
        connectivity: ConnectivityService(),
      );
    }
  }

  Future _ensureBaseMaps() async {
    if (_baseMapService == null) {
      _baseMapService = BaseMapService();
      final controller = _ensurePermissionController();
      final used = await controller.ask(
        controller.storageRequest.copyWith(
          onReady: () async => await _asyncBaseMapLoad(true),
        ),
      );
      if (Platform.isIOS && used != PermissionStatus.granted) {
        await _asyncBaseMapLoad(true);
      }
      controller.dispose();
    }
  }

  void _initWakeLock() async {
    _wakeLockWasOn = await Wakelock.isEnabled;
    if (mounted) {
      await Wakelock.toggle(on: context.bloc<AppConfigBloc>().config.keepScreenOn);
    }
  }

  void _restoreWakeLock() async {
    final wakeLock = await Wakelock.isEnabled;
    if (wakeLock != _wakeLockWasOn) await Wakelock.toggle(on: _wakeLockWasOn);
  }

  Future _asyncBaseMapLoad(bool update) async {
    if (mounted) {
      await _baseMapService.init();
      if (mounted && update) setState(() {});
    }
  }

  void _setup({bool wasZoom = true}) {
    if (wasZoom)
      _zoom = _readState(
        STATE_ZOOM,
        read: widget.readZoom,
        orElse: _zoom,
        defaultValue: widget.zoom ?? Defaults.zoom,
      );
    _setBaseMap(
      _readState(STATE_BASE_MAP, defaultValue: Defaults.baseMap),
    );
    _useLayers = _resolveLayers();
    if (_mapController != null) {
      _mapController.progress.removeListener(_onMoveProgress);
    }
    _mapController = widget.mapController;
    _mapController.progress.addListener(_onMoveProgress);
  }

  void _update() {
    final status = Provider.of<ConnectivityStatus>(context);
    _offline = (status == null || ConnectivityStatus.offline == status);
  }

  void _setBaseMap(BaseMap map) {
    _currentBaseMap = map;
  }

  Set<String> _resolveLayers() {
    final layers = widget.withRead && widget.readLayers ? _readLayers() : _withLayers();
    return layers;
  }

  Set<String> _readLayers() => FilterSheet.read(
        context,
        STATE_FILTERS,
        defaultValue: _withLayers()..retainAll(DEFAULT_LAYERS_ENABLED),
      );

  void _ensureMapToolController() {
    if (widget.withControlsTool) {
      _mapToolController ??= MapToolController(
        tools: [
          MeasureTool(),
          POITool(
            context.bloc<OperationBloc>(),
            controller: _mapController,
            onMessage: widget.onMessage,
            active: () => _useLayers.contains(LAYER_POI),
          ),
          UnitTool(
            context.bloc<TrackingBloc>(),
            user: context.bloc<UserBloc>().user,
            controller: _mapController,
            onMessage: widget.onMessage,
            active: () => _useLayers.contains(LAYER_UNIT),
          ),
          PersonnelTool(
            context.bloc<TrackingBloc>(),
            user: context.bloc<UserBloc>().user,
            controller: _mapController,
            onMessage: widget.onMessage,
            active: () => _useLayers.contains(LAYER_PERSONNEL),
          ),
          DeviceTool(
            context.bloc<TrackingBloc>(),
            user: context.bloc<UserBloc>().user,
            controller: _mapController,
            onMessage: widget.onMessage,
            active: () => _useLayers.contains(LAYER_DEVICE),
          ),
          PositionTool(
            controller: _mapController,
            onMessage: widget.onMessage,
            onHide: () => setState(() => _searchMatch = null),
            onShow: (point) => setState(() => _searchMatch = point),
            onCopy: (value) => setState(() => _searchFieldKey.currentState.setQuery(value)),
          )
        ],
      );
    }
  }

  void _ensureLocationControllers() {
    // Configure location controller only once
    if (widget.withControlsLocateMe && _locationController == null) {
      _locationController = MyLocationController(
        tickerProvider: this,
        mapController: widget.mapController,
        onTrackingChanged: _onTrackingChanged,
        onLocationChanged: _onLocationChanged,
        permissionController: _ensurePermissionController(),
      );
      _scheduleInitLocation((_) {
        final following = _readState(STATE_FOLLOWING, defaultValue: false);
        if (following) {
          _locationController.goto(locked: true);
          _updateLocationToolState(force: true);
        }
      });
    }
  }

  void _scheduleInitLocation(ValueChanged<LatLng> callback) {
    if (_locationRequest == null) {
      _locationRequest = _locationController.configure();
      _locationRequest.then(callback);
    }
  }

  PermissionController _ensurePermissionController() {
    _permissionController ??= PermissionController(
      configBloc: context.bloc<AppConfigBloc>(),
      onMessage: widget.onMessage,
    );
    return _permissionController;
  }

  LatLng _ensureCenter() {
    Position current = _tryCenterOnMe();
    LatLng candidate = _centerFromIncident(current);
    /*
    if (_currentBaseMap?.bounds?.contains(candidate) == false) {
      // Use center in current map bounds
      _center = LatLng(
        _currentBaseMap.bounds.south + (_currentBaseMap.bounds.north - _currentBaseMap.bounds.south) / 2,
        _currentBaseMap.bounds.west + (_currentBaseMap.bounds.east - _currentBaseMap.bounds.west) / 2,
      );
    }
    */

    return candidate;
  }

  LatLng _centerFromIncident(Position current) {
    final candidate = widget.center ??
        (context.bloc<OperationBloc>()?.selected?.meetup != null
            ? toLatLng(context.bloc<OperationBloc>()?.selected?.meetup?.point)
            : null) ??
        (current != null ? LatLng(current.lat, current.lon) : Defaults.origo);
    return candidate;
  }

  Position _tryCenterOnMe() {
    final current = widget.withControlsLocateMe ? _locationController.current : null;
    if (widget.withControlsLocateMe && _center == null && current == null) {
      _scheduleInitLocation((location) => setState(() => _center = location));
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    _update();
    return Stack(
      overflow: Overflow.clip,
      children: [
        _buildMap(),
        if (widget.withControls) _buildControls(),
        if (widget.withSearch) _buildSearchBar(),
      ],
    );
  }

  Widget _buildMap() {
    _fitToBoundsOnce();
    return FlutterMap(
      key: _mapKey,
      mapController: _mapController,
      options: MapOptions(
        zoom: _zoom,
        center: _center,
        minZoom: _minZoom(),
        maxZoom: _maxZoom(),
        interactive: widget.interactive,
        /* Ensure _center is inside given bounds
        nePanBoundary: _currentBaseMap.bounds?.northEast,
        swPanBoundary: _currentBaseMap.bounds?.southWest,
        */
        onTap: (point) => _onTap(point),
        onLongPress: (point) => _onLongPress(point),
        onPositionChanged: _onPositionChanged,
        plugins: [
          MyLocation(),
          POILayer(),
          DeviceLayer(),
          PersonnelLayer(),
          UnitLayer(),
          CoordinateLayer(),
          ScaleBar(),
          MeasureLayer(),
        ],
      ),
      layers: _setLayerOptions(),
    );
  }

  /// Get actual key to FlutterMap
  ///
  /// If FlutterMap is
  /// located in same position
  /// in the widget tree FlutterMap
  /// state will be reused.
  ///
  /// If [widget.operation] is given,
  /// an ObjectKey based on it is
  /// returned.
  ///
  /// If [widget.sharedKey] is
  /// given, an this key is used,
  /// which allows for sharing the
  /// same state across parent widgets
  /// in the same location in the
  /// tree
  ///
  /// Else a [GlobalKey] will be used.
  ///
  Key get _mapKey => widget.operation == null ? widget.sharedKey ?? _uniqueMapKey : ObjectKey(widget.operation);

  bool get isFollowing => _isLocating.value.locked || _readState(STATE_FOLLOWING, defaultValue: false);

  void _fitToBoundsOnce() async {
    if (_hasFitToBounds == false) {
      if (!isFollowing && widget.fitBounds?.isValid == true) {
        // Listen for ready event
        _mapController.onReady.then((_) => _fitBounds());
      }
      // Only do this once per state instance
      _hasFitToBounds = true;
    }
  }

  void _fitBounds() {
    if (_mapController?.ready == true) {
      _mapController.fitBounds(
        widget.fitBounds,
        options: widget.fitBoundOptions ?? FIT_BOUNDS_OPTIONS,
      );
    }
  }

  List<LayerOptions> _setLayerOptions() {
    final tool = _mapToolController?.of<MeasureTool>();
    _layerOptions
      ..clear()
      ..addAll([
        _buildBaseMapLayer(),
        if (_useLayers.contains(LAYER_DEVICE)) _buildDeviceOptions(),
        if (_useLayers.contains(LAYER_PERSONNEL)) _buildPersonnelOptions(),
        if (_useLayers.contains(LAYER_UNIT)) _buildUnitOptions(),
        if (_useLayers.contains(LAYER_POI) && widget.operation != null) _buildPoiOptions(),
        if (_searchMatch != null) _buildMatchOptions(_searchMatch),
        if (widget.withControlsLocateMe && _locationController?.isReady == true)
          _locationController.build(
            withTail: _useLayers.contains(LAYER_TRACKING),
          ),
        if (widget.withCoordsPanel && _useLayers.contains(LAYER_COORDS)) CoordinateLayerOptions(),
        if (widget.withScaleBar && _useLayers.contains(LAYER_SCALE)) _buildScaleBarOptions(),
        if (tool != null && tool.active()) MeasureLayerOptions(tool),
      ]);
    return _layerOptions;
  }

  TileLayerOptions _buildBaseMapLayer() => TileLayerOptions(
        tms: _currentBaseMap.tms,
        urlTemplate: _currentBaseMap.url,
        subdomains: _currentBaseMap.subdomains,
        overrideTilesWhenUrlChanges: true,
        tileProvider: _tileProvider,
        errorImage: _offline ? _tileOfflineImage : _tileErrorImage,
        placeholderImage: _offline ? _tileOfflineImage : _tilePendingImage,
        maxZoom: useRetinaMode ? _currentBaseMap.maxZoom - 1 : _currentBaseMap.maxZoom,
        retinaMode: useRetinaMode,
        rebuild: _tileProvider.onEvicted,
        errorTileCallback: _tileProvider.onError,
      );

  bool get useRetinaMode =>
      context.bloc<AppConfigBloc>().config.mapRetinaMode && MediaQuery.of(context).devicePixelRatio > 1.0;

  void _onTap(LatLng point) {
    if (_searchMatch == null) _clearSearchField();
    if (_mapToolController != null) _mapToolController.onTap(context, point, _zoom, ScalebarOption.SCALES);
    if (widget.onTap != null) widget.onTap(point);
  }

  void _onLongPress(LatLng point) {
    if (_searchMatch == null) _clearSearchField();
    if (_mapToolController != null) _mapToolController.onLongPress(context, point, _zoom, ScalebarOption.SCALES);
  }

  ScalebarOption _buildScaleBarOptions() {
    return ScalebarOption(
      lineColor: Colors.black54,
      lineWidth: 2,
      textStyle: TextStyle(color: Colors.black87, fontSize: 12),
      padding: EdgeInsets.only(left: 16, top: 16),
      alignment: Alignment.bottomLeft,
    );
  }

  Widget _buildSearchBar() {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    final maxWidth = orientation != Orientation.landscape ||
            _searchFieldKey.currentState != null && _searchFieldKey.currentState.hasFocus
        ? size.width + (orientation == Orientation.landscape ? -56.0 : 0.0)
        : math.min(size.width, size.height) * 0.7;
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: EdgeInsets.all(8.0),
            child: MapSearchField(
              key: _searchFieldKey,
              zoom: _zoom,
              mapController: _mapController,
              onError: (message) => widget.onMessage(message),
              onMatch: _onSearchMatch,
              onCleared: _onSearchCleared,
              prefixIcon: IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {
                  _searchFieldKey.currentState.clear();
                  if (widget.onOpenDrawer != null) {
                    widget.onOpenDrawer();
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (_mapControls == null) {
      _mapControls = MapControls(
        top: widget.withControlsOffset,
        controller: _mapToolController,
        controls: [
          if (widget.withControlsLayer)
            MapControl(
              icon: Icons.filter_list,
              onPressed: () => _showLayerSheet(context),
            ),
          if (widget.withControlsBaseMap)
            MapControl(
              icon: Icons.map,
              onPressed: () => _showBaseMapSheet(context),
            ),
          if (widget.withControlsZoom) ...[
            MapControl(
              icon: Icons.add,
              onPressed: () {
                _zoom = _writeState(STATE_ZOOM, math.min(_zoom + 1, _maxZoom()));
                _mapController.animatedMove(_center, _zoom, this, milliSeconds: 250);
              },
            ),
            MapControl(
              icon: Icons.remove,
              onPressed: () {
                _zoom = _writeState(STATE_ZOOM, math.max(_zoom - 1, _minZoom()));
                _mapController.animatedMove(_center, _zoom, this, milliSeconds: 250);
              },
            )
          ],
          if (widget.withControlsLocateMe)
            MapControl(
              icon: Icons.gps_fixed,
              listenable: _isLocating,
              onPressed: () {
                _locationController.goto();
                _writeState(STATE_FOLLOWING, false);
              },
              onLongPress: () {
                _locationController.goto(locked: true);
                _writeState(STATE_FOLLOWING, true);
              },
            ),
          if (widget.withControlsTool)
            MapControl(
              icon: MdiIcons.tapeMeasure,
              listenable: _isMeasuring,
              children: [
                MapControl(
                  icon: MdiIcons.mapMarkerPlus,
                  state: MapControlState(),
                  onPressed: () {
                    _mapToolController.of<MeasureTool>().add(_center);
                  },
                ),
                MapControl(
                  icon: MdiIcons.mapMarkerMinus,
                  state: MapControlState(),
                  onPressed: () {
                    _mapToolController.of<MeasureTool>().remove();
                  },
                )
              ],
              onPressed: () {
                final tool = _mapToolController.of<MeasureTool>();
                tool.state = !tool.state;
                tool.init();
                _isMeasuring.value = MapControlState(toggled: tool.active());
                if (widget.onToolChange != null) widget.onToolChange(tool);
              },
            ),
        ],
      );
    }
    return _mapControls;
  }

  double _minZoom() => _currentBaseMap?.minZoom ?? Defaults.minZoom;

  double _maxZoom() => _currentBaseMap?.maxZoom ?? Defaults.maxZoom;

  POILayerOptions _buildPoiOptions() {
    return widget.operation == null
        ? null
        : POILayerOptions(
            context.bloc<OperationBloc>(),
            ouuid: widget.operation.uuid,
            align: AnchorAlign.top,
            icon: Icon(
              Icons.location_on,
              size: 30,
              color: Colors.red,
            ),
            rebuild: context.bloc<OperationBloc>().map((_) => null),
          );
  }

  DeviceLayerOptions _buildDeviceOptions() {
    return DeviceLayerOptions(
      bloc: context.bloc<TrackingBloc>(),
      onMessage: widget.onMessage,
      showTail: _useLayers.contains(LAYER_TRACKING),
    );
  }

  PersonnelLayerOptions _buildPersonnelOptions() {
    return PersonnelLayerOptions(
      bloc: context.bloc<TrackingBloc>(),
      onMessage: widget.onMessage,
      showRetired: widget.showRetired,
      showTail: _useLayers.contains(LAYER_TRACKING),
    );
  }

  UnitLayerOptions _buildUnitOptions() {
    return UnitLayerOptions(
      bloc: context.bloc<TrackingBloc>(),
      onMessage: widget.onMessage,
      showRetired: widget.showRetired,
      showTail: _useLayers.contains(LAYER_TRACKING),
    );
  }

  MarkerLayerOptions _buildMatchOptions(LatLng point) {
    return MarkerLayerOptions(
      markers: [
        Marker(
          width: 80.0,
          height: 80.0,
          point: point,
          builder: (_) => IgnorePointer(
            child: SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: CrossPainter(color: Colors.red.withOpacity(0.6)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    var center = position.center;
    if ((hasGesture) && _mapController.ready) {
      _zoom = _writeState(STATE_ZOOM, _mapController.zoom);
      if (widget.withControlsLocateMe) {
        if (_locationController.isLocked) {
          center = _center;
          _mapController.move(_center, _zoom);
        }
      }
    }
    if ((hasGesture) && widget.withControlsLocateMe) {
      _updateLocationToolState();
    }
    _center = _writeState(STATE_CENTER, center);
    if (widget.onPositionChanged != null) widget.onPositionChanged(position, hasGesture);
  }

  void _updateLocationToolState({bool force = false}) {
    if (force || _locationController.isLocated != _isLocating.value?.toggled) {
      _isLocating.value = MapControlState(
        toggled: _locationController.isLocated,
        locked: _locationController.isLocked,
      );
    }
  }

  void _clearSearchField() {
    _searchFieldKey?.currentState?.clear();
  }

  void _onSearchMatch(LatLng point) {
    _searchMatch = point;
    _setLayerOptions();
    _locationController?.stop();
    _mapController.animatedMove(point, _zoom, this);
  }

  void _onSearchCleared() {
    setState(() {
      _searchMatch = null;
    });
  }

  void _showBaseMapSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Kart", style: Theme.of(context).textTheme.headline6),
              ),
              Divider(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: landscape ? 4 : 2,
                    children: _toBaseMapCards(),
                  ),
                ),
              ),
            ],
          );
        });
  }

  List<Widget> _toBaseMapCards() {
    final List<Widget> _cards = [];

    for (BaseMap map in _baseMapService.baseMaps) {
      _cards.add(
        GestureDetector(
          child: Center(child: BaseMapCard(map: map)),
          onTap: () => setState(
            () {
              _setBaseMap(_writeState(STATE_BASE_MAP, map));
              _setLayerOptions();
              Navigator.pop(context);
            },
          ),
        ),
      );
    }
    return _cards;
  }

  void _onTrackingChanged(bool isLocated, bool isLocked) {
    if (_disposed) return;
    _isLocating.value = MapControlState(
      toggled: isLocated,
      locked: isLocked,
    );
    _setLayerOptions();
  }

  void _onLocationChanged(LatLng point, bool goto, bool locked) {
    if (mounted) {
      _setLayerOptions();
    }
  }

  void _showLayerSheet(context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) => FilterSheet<String>(
        allowNone: true,
        initial: _useLayers,
        identifier: STATE_FILTERS,
        bucket: PageStorage.of(context),
        onBuild: () => _withLayers(retainOnly: true).map(
          (name) => FilterData(
            key: name,
            title: name,
          ),
        ),
        onChanged: (Set<String> selected) {
          setState(() => _useLayers = selected);
        },
      ),
    );
  }

  Set<String> _withLayers({bool retainOnly = false}) {
    final layers = ALL_LAYERS.toList();
    if (!widget.withScaleBar) layers.remove(LAYER_SCALE);
    if (!widget.withCoordsPanel) layers.remove(LAYER_COORDS);
    if (!widget.withPOIs) layers.remove(LAYER_POI);
    if (!widget.withUnits) layers.remove(LAYER_UNIT);
    if (!widget.withPersonnel) layers.remove(LAYER_PERSONNEL);
    if (!widget.withDevices) layers.remove(LAYER_DEVICE);
    if (!widget.withTracking) layers.remove(LAYER_TRACKING);
    if (retainOnly) {
      layers.retainWhere((layer) => widget.showLayers.contains(layer));
    }
    return layers.toSet();
  }

  void _onMoveProgress() {
    _zoom = _writeState(STATE_ZOOM, _mapController.progress.value.zoom);
    _center = _writeState(STATE_CENTER, _mapController.progress.value.center);
  }

  T _readState<T>(String identifier, {T defaultValue, bool read = true, T orElse}) {
    if (widget.withRead && read) {
      final model = getPageState<MapWidgetStateModel>(
        context,
        STATE,
        defaultValue: _defaultState(),
      );
      switch (identifier) {
        case STATE_CENTER:
          return model?.center ?? defaultValue;
        case STATE_ZOOM:
          return model?.zoom ?? defaultValue;
        case STATE_BASE_MAP:
          return model?.baseMap ?? defaultValue;
        case STATE_FOLLOWING:
          return model?.following ?? defaultValue;
        case STATE_FILTERS:
          return model?.filters ?? defaultValue;
        default:
          throw '_writeState: Unexpected identifier $identifier';
      }
    }
    return read ? defaultValue : orElse ?? defaultValue;
  }

  T _writeState<T>(String identifier, T value) {
    if (widget.withWrite) {
      var model = getPageState<MapWidgetStateModel>(
        context,
        STATE,
        defaultValue: _defaultState(),
      );
      switch (identifier) {
        case STATE_CENTER:
          model = model.cloneWith(
            center: value as LatLng,
            incident: widget.operation?.uuid,
          );
          break;
        case STATE_ZOOM:
          model = model.cloneWith(
            zoom: value as double,
            incident: widget.operation?.uuid,
          );
          break;
        case STATE_BASE_MAP:
          model = model.cloneWith(
            baseMap: value as BaseMap,
            incident: widget.operation?.uuid,
          );
          break;
        case STATE_FOLLOWING:
          model = model.cloneWith(
            following: value as bool,
            incident: widget.operation?.uuid,
          );
          break;
        case STATE_FILTERS:
          model = model.cloneWith(
            filters: value as List<String>,
            incident: widget.operation?.uuid,
          );
          break;
        default:
          throw '_writeState: Unexpected identifier $identifier';
      }
      putPageState<MapWidgetStateModel>(context, STATE, model);
    }
    return value;
  }

  MapWidgetStateModel _defaultState() {
    return MapWidgetStateModel(
      zoom: _zoom,
      center: _center,
      incident: widget.operation?.uuid,
      baseMap: _currentBaseMap,
      filters: _readLayers().toList(),
      following: _isLocating.value.locked,
    );
  }
}

/// Incident MapController that supports animated move operations
class MapWidgetController extends MapControllerImpl {
  ValueNotifier<MapMoveState> progress = ValueNotifier(MapMoveState.none());

  AnimationController _controller;
  bool get isAnimating => _controller != null;

  void cancel() {
    if (_controller != null) {
      _controller.dispose();
      _controller = null;
    }
  }

  /// Move to given point and zoom
  void animatedMove(LatLng point, double zoom, TickerProvider provider,
      {int milliSeconds: 500, void onMove(LatLng point)}) {
    if (!isAnimating) {
      if (!ready) {
        move(point, zoom);
        progress.value = MapMoveState(point, zoom);
      } else {
        // Create some tweens. These serve to split up the transition from one location to another.
        // In our case, we want to split the transition be<tween> our current map center and the destination.
        final _latTween = Tween<double>(begin: center.latitude, end: point.latitude);
        final _lngTween = Tween<double>(begin: center.longitude, end: point.longitude);
        final _zoomTween = Tween<double>(begin: this.zoom, end: zoom);

        // Create a animation controller that has a duration and a TickerProvider.
        _controller = AnimationController(duration: Duration(milliseconds: milliSeconds), vsync: provider);

        // The animation determines what path the animation will take. You can try different Curves values, although I found
        // fastOutSlowIn to be my favorite.
        Animation<double> animation = CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn);

        _controller.addListener(() {
          final state = MapMoveState(
            LatLng(
              _latTween.evaluate(animation),
              _lngTween.evaluate(animation),
            ),
            _zoomTween.evaluate(animation),
          );
          move(state.center, state.zoom);
          progress.value = state;
          if (onMove != null) onMove(state.center);
        });

        animation.addStatusListener((status) {
          if ([AnimationStatus.completed, AnimationStatus.dismissed].contains(status)) {
            cancel();
          }
        });
        _controller.forward();
      }
    }
  }
}

class MapMoveState {
  final LatLng center;
  final double zoom;

  MapMoveState(this.center, this.zoom);

  static MapMoveState none() => MapMoveState(null, null);
}
