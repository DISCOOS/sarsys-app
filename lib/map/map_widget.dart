import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/app_state.dart';
import 'package:SarSys/map/basemap_card.dart';
import 'package:SarSys/map/layers/coordate_layer.dart';
import 'package:SarSys/map/layers/device_layer.dart';
import 'package:SarSys/map/layers/measure_layer.dart';
import 'package:SarSys/map/layers/personnel_layer.dart';
import 'package:SarSys/map/map_controls.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/controllers/location_controller.dart';
import 'package:SarSys/map/tile_providers.dart';
import 'package:SarSys/map/layers/scalebar.dart';
import 'package:SarSys/map/tools/position_tool.dart';
import 'package:SarSys/map/tools/device_tool.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/map/tools/measure_tool.dart';
import 'package:SarSys/map/tools/personnel_tool.dart';
import 'package:SarSys/map/tools/poi_tool.dart';
import 'package:SarSys/map/tools/unit_tool.dart';
import 'package:SarSys/map/layers/unit_layer.dart';
import 'package:SarSys/models/BaseMap.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/connectivity_service.dart';
import 'package:SarSys/services/image_cache_service.dart';
import 'package:SarSys/services/base_map_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/map/layers/poi_layer.dart';
import 'package:SarSys/map/map_search.dart';
import 'package:SarSys/map/layers/my_location.dart';
import 'package:SarSys/widgets/filter_sheet.dart';

import 'package:geolocator/geolocator.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:latlong/latlong.dart';
import 'package:wakelock/wakelock.dart';

import 'models/map_widget_state_model.dart';

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

  final Incident incident;
  final TapCallback onTap;
  final ActionCallback onMessage;
  final ToolCallback onToolChange;
  final PositionCallback onPositionChanged;
  final IncidentMapController mapController;

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

  MapWidget({
    Key key,
    this.zoom,
    this.center,
    this.incident,
    this.fitBounds,
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
    this.showLayers = MapWidgetState.DEFAULT_LAYERS,
    this.onTap,
    this.onMessage,
    this.onPositionChanged,
    this.onToolChange,
    this.onOpenDrawer,
    Image placeholder,
    MapController mapController,
  })  : this.mapController = mapController ?? IncidentMapController(),
        super(key: key);

  @override
  MapWidgetState createState() => MapWidgetState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapWidget &&
          runtimeType == other.runtimeType &&
          interactive == other.interactive &&
          withSearch == other.withSearch &&
          withControls == other.withControls &&
          withControlsZoom == other.withControlsZoom &&
          withControlsTool == other.withControlsTool &&
          withControlsLayer == other.withControlsLayer &&
          withControlsBaseMap == other.withControlsBaseMap &&
          withControlsOffset == other.withControlsOffset &&
          withControlsLocateMe == other.withControlsLocateMe &&
          withScaleBar == other.withScaleBar &&
          withCoordsPanel == other.withCoordsPanel &&
          withPOIs == other.withPOIs &&
          withUnits == other.withUnits &&
          withPersonnel == other.withPersonnel &&
          withDevices == other.withDevices &&
          withTracking == other.withTracking &&
          withRead == other.withRead &&
          withWrite == other.withWrite &&
          readZoom == other.readZoom &&
          readCenter == other.readCenter &&
          readLayers == other.readLayers &&
          incident == other.incident &&
          onTap == other.onTap &&
          onMessage == other.onMessage &&
          onToolChange == other.onToolChange &&
          mapController == other.mapController &&
          onOpenDrawer == other.onOpenDrawer &&
          zoom == other.zoom &&
          center == other.center &&
          fitBounds == other.fitBounds &&
          fitBoundOptions == other.fitBoundOptions &&
          showLayers == other.showLayers &&
          showRetired == other.showRetired;

  @override
  int get hashCode =>
      interactive.hashCode ^
      withSearch.hashCode ^
      withControls.hashCode ^
      withControlsZoom.hashCode ^
      withControlsTool.hashCode ^
      withControlsLayer.hashCode ^
      withControlsBaseMap.hashCode ^
      withControlsOffset.hashCode ^
      withControlsLocateMe.hashCode ^
      withScaleBar.hashCode ^
      withCoordsPanel.hashCode ^
      withPOIs.hashCode ^
      withUnits.hashCode ^
      withPersonnel.hashCode ^
      withDevices.hashCode ^
      withTracking.hashCode ^
      withRead.hashCode ^
      withWrite.hashCode ^
      readZoom.hashCode ^
      readCenter.hashCode ^
      readLayers.hashCode ^
      incident.hashCode ^
      onTap.hashCode ^
      onMessage.hashCode ^
      onToolChange.hashCode ^
      mapController.hashCode ^
      onOpenDrawer.hashCode ^
      zoom.hashCode ^
      center.hashCode ^
      fitBounds.hashCode ^
      fitBoundOptions.hashCode ^
      showLayers.hashCode ^
      showRetired.hashCode;
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

  static const ALL_LAYERS = [
    LAYER_POI,
    LAYER_UNIT,
    LAYER_PERSONNEL,
    LAYER_TRACKING,
    LAYER_DEVICE,
    LAYER_SCALE,
    LAYER_COORDS,
  ];
  static const DEFAULT_LAYERS = [
    LAYER_POI,
    LAYER_UNIT,
    LAYER_SCALE,
  ];

  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  BaseMap _currentBaseMap;
  BaseMapService _baseMapService;

  LatLng _center;
  LatLng _searchMatch;
  double _zoom = Defaults.zoom;

  MapControls _mapControls;
  IncidentMapController _mapController;
  MapToolController _mapToolController;
  LocationController _locationController;
  PermissionController _permissionController;

  /// Conditionally set during initialization
  Future<LatLng> _locationRequest;

  ValueNotifier<MapControlState> _isLocating = ValueNotifier(MapControlState());
  ValueNotifier<MapControlState> _isMeasuring = ValueNotifier(MapControlState());

  Set<String> _useLayers;
  List<LayerOptions> _layerOptions = [];

  // Prevent location updates after dispose
  bool _disposed = false;

  UserBloc _userBloc;
  AppConfigBloc _configBloc;
  TrackingBloc _trackingBloc;
  IncidentBloc _incidentBloc;

  bool _wakeLockWasOn;
  bool _hasFitToBounds = false;
  bool _attemptRestore = true;

  /// Tile error data persisted across map reloads
  final Map<BaseMap, TileErrorData> _tileErrorData = {};

  /// Placeholder shown when a tile fails to load
  final ImageProvider _tileErrorImage = Image.asset("assets/error_tile.png").image;

  /// Placeholder shown while loading images
  final ImageProvider _tilePendingImage = Image.asset("assets/pending_tile.png").image;

  /// Asset name for offline tiles
  final String _fileOfflineAsset = "assets/offline_tile.png";

  /// Placeholder shown when tiles are not found in offline mode
  final ImageProvider _tileOfflineImage = Image.asset("assets/offline_tile.png").image;

  /// Flag indicating that network connection is offline
  bool get _offline {
    final status = Provider.of<ConnectivityStatus>(context);
    return status == null || ConnectivityStatus.Offline == status;
  }

  StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _setup();
    _subscription = ConnectivityService().changes.listen((status) async {
      if (ConnectivityStatus.Offline != status) await _removePlaceholders();
      setState(() {});
    });
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
    _subscription?.cancel();
    _permissionController?.dispose();
    _isLocating = null;
    _isMeasuring = null;
    _subscription = null;
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
    // Assumes that this.hash and this.== are up to date!
    if (widget != old) {
      _setup(
        wasZoom: widget.zoom != old.zoom,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _userBloc = BlocProvider.of<UserBloc>(context);
    _configBloc = BlocProvider.of<AppConfigBloc>(context);
    _incidentBloc = BlocProvider.of<IncidentBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);

    //
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
    await Wakelock.toggle(on: _configBloc.config.keepScreenOn);
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

  void _setBaseMap(BaseMap map) {
    _currentBaseMap = map;
    final data = _tileErrorData.putIfAbsent(map, () => TileErrorData(map));
    if (data.isFatal()) _onFatalTileError(data);
  }

  Set<String> _resolveLayers() => widget.withRead && widget.readLayers
      ? (FilterSheet.read(context, STATE_FILTERS, defaultValue: _withLayers()..retainAll(widget.showLayers.toSet())))
      : (_withLayers()..retainAll(widget.showLayers.toSet()));

  void _ensureMapToolController() {
    if (widget.withControlsTool) {
      _mapToolController ??= MapToolController(
        tools: [
          MeasureTool(),
          POITool(
            _incidentBloc,
            controller: _mapController,
            onMessage: widget.onMessage,
            active: () => _useLayers.contains(LAYER_POI),
          ),
          UnitTool(
            _trackingBloc,
            user: _userBloc.user,
            controller: _mapController,
            onMessage: widget.onMessage,
            active: () => _useLayers.contains(LAYER_UNIT),
          ),
          PersonnelTool(
            _trackingBloc,
            user: _userBloc.user,
            controller: _mapController,
            onMessage: widget.onMessage,
            active: () => _useLayers.contains(LAYER_PERSONNEL),
          ),
          DeviceTool(
            _trackingBloc,
            user: _userBloc.user,
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
      _locationController = LocationController(
        tickerProvider: this,
        configBloc: _configBloc,
        permissionController: _ensurePermissionController(),
        mapController: widget.mapController,
        onTrackingChanged: _onTrackingChanged,
        onLocationChanged: _onLocationChanged,
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
    _locationRequest ??= _locationController.configure();
    _locationRequest.then(callback);
  }

  PermissionController _ensurePermissionController() {
    _permissionController ??= PermissionController(
      configBloc: _configBloc,
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
        (_incidentBloc?.selected?.meetup != null ? toLatLng(_incidentBloc?.selected?.meetup?.point) : null) ??
        (current != null ? LatLng(current.latitude, current.longitude) : Defaults.origo);
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
    return Stack(
      overflow: Overflow.clip,
      children: [
        _buildMap(),
        if (widget.withControls) _buildControls(),
        if (widget.withSearch) _buildSearchBar(),
      ],
    );
  }

  // Removes all offline placeholders from caches when online.
  // This ensures that actual tiles are loaded instead of placeholders.
  FutureOr<int> _removePlaceholders() async {
    int removed = 0;
    final errors = _tileErrorData.values.where(
      (data) => data.errors.isNotEmpty,
    );
    if (errors.isNotEmpty) {
      final fileCache = FileCacheService(_configBloc.config);
      await Future.forEach<TileErrorData>(errors, (data) async {
        final images = data.errors.values
            .where(
              (error) => error.image is ManagedCachedNetworkImageProvider,
            )
            .map((error) => error.image);
        await Future.forEach(images, (key) async {
          await fileCache.removeFile(key.url);
          removed++;
        });
        removed += data.placeholders.length;
        data.placeholders
          ..forEach((key) => imageCache.evict(key))
          ..clear()
          ..length;
        data.errors.clear();
      });
    }
    return removed;
  }

  Widget _buildMap() {
    _fitToBoundsOnce();
    return FlutterMap(
      key: widget.incident == null ? GlobalKey() : ObjectKey(widget.incident),
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
        if (_useLayers.contains(LAYER_POI) && widget.incident != null) _buildPoiOptions(),
        if (_searchMatch != null) _buildMatchOptions(_searchMatch),
        if (widget.withControlsLocateMe && _locationController?.isReady == true) _locationController.options,
        if (widget.withCoordsPanel && _useLayers.contains(LAYER_COORDS)) CoordinateLayerOptions(),
        if (widget.withScaleBar && _useLayers.contains(LAYER_SCALE)) _buildScaleBarOptions(),
        if (tool != null && tool.active()) MeasureLayerOptions(tool),
      ]);
    return _layerOptions;
  }

  TileLayerOptions _buildBaseMapLayer() => TileLayerOptions(
        urlTemplate: _currentBaseMap.url,
        maxZoom: _currentBaseMap.maxZoom,
        subdomains: _currentBaseMap.subdomains,
        tms: _currentBaseMap.tms,
        placeholderImage: _offline ? _tileOfflineImage : _tilePendingImage,
        tileProvider: _buildTileProvider(_currentBaseMap),
      );

  TileProvider _buildTileProvider(BaseMap map) => map.offline
      ? ManagedFileTileProvider(
          _tileErrorData[map],
          errorImage: _tileErrorImage,
          onFatal: (data) => _onFatalTileError(data),
        )
      : ManagedCacheTileProvider(
          _tileErrorData[map],
          offline: _offline,
          errorImage: _tileErrorImage,
          offlineImage: _tileOfflineImage,
          offlineAsset: _fileOfflineAsset,
          cacheManager: FileCacheService(_configBloc.config),
          onFatal: (data) => _onFatalTileError(data),
        );

  void _onFatalTileError(TileErrorData data) {
    if (widget.onMessage != null) {
      final reason = data.explain().map((type) => translateTileErrorType(type));
      widget.onMessage("Kartdata ${reason.isNotEmpty ? reason.join(', ') : ' kan ikke lastes'}");
    }
  }

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
              prefixIcon: GestureDetector(
                child: Icon(Icons.menu),
                onTap: () {
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
//          icon: MdiIcons.mathCompass,
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
    return widget.incident == null
        ? null
        : POILayerOptions(
            _incidentBloc,
            incidentId: widget.incident.uuid,
            align: AnchorAlign.top,
            icon: Icon(
              Icons.location_on,
              size: 30,
              color: Colors.red,
            ),
            rebuild: _incidentBloc.state.map((_) => null),
          );
  }

  DeviceLayerOptions _buildDeviceOptions() {
    return DeviceLayerOptions(
      bloc: _trackingBloc,
      onMessage: widget.onMessage,
      showTail: _useLayers.contains(LAYER_TRACKING),
    );
  }

  PersonnelLayerOptions _buildPersonnelOptions() {
    return PersonnelLayerOptions(
      bloc: _trackingBloc,
      onMessage: widget.onMessage,
      showRetired: widget.showRetired,
      showTail: _useLayers.contains(LAYER_TRACKING),
    );
  }

  UnitLayerOptions _buildUnitOptions() {
    return UnitLayerOptions(
      bloc: _trackingBloc,
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
                child: Text("Kart", style: Theme.of(context).textTheme.title),
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
    _setLayerOptions();
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
        onBuild: () => _withLayers().map(
          (name) => FilterData(
            key: name,
            title: name,
          ),
        ),
        onChanged: (Set<String> selected) => setState(() => _useLayers = selected),
      ),
    );
  }

  Set<String> _withLayers() {
    final layers = ALL_LAYERS.toList();
    if (!widget.withScaleBar) layers.remove(LAYER_SCALE);
    if (!widget.withCoordsPanel) layers.remove(LAYER_COORDS);
    if (!widget.withPOIs) layers.remove(LAYER_POI);
    if (!widget.withUnits) layers.remove(LAYER_UNIT);
    if (!widget.withPersonnel) layers.remove(LAYER_PERSONNEL);
    if (!widget.withDevices) layers.remove(LAYER_DEVICE);
    if (!widget.withTracking) layers.remove(LAYER_TRACKING);
    return layers.toSet();
  }

  void _onMoveProgress() {
    _zoom = _writeState(STATE_ZOOM, _mapController.progress.value.zoom);
    _center = _writeState(STATE_CENTER, _mapController.progress.value.center);
  }

  T _readState<T>(String identifier, {T defaultValue, bool read = true, T orElse}) {
    if (widget.withRead && read) {
      final model = readState<MapWidgetStateModel>(context, STATE);
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
      var model = readState<MapWidgetStateModel>(context, STATE);
      switch (identifier) {
        case STATE_CENTER:
          model = model.cloneWith(
            center: value as LatLng,
            incident: widget.incident?.uuid,
          );
          break;
        case STATE_ZOOM:
          model = model.cloneWith(
            zoom: value as double,
            incident: widget.incident?.uuid,
          );
          break;
        case STATE_BASE_MAP:
          model = model.cloneWith(
            baseMap: value as BaseMap,
            incident: widget.incident?.uuid,
          );
          break;
        case STATE_FOLLOWING:
          model = model.cloneWith(
            following: value as bool,
            incident: widget.incident?.uuid,
          );
          break;
        case STATE_FILTERS:
          model = model.cloneWith(
            filters: value as List<String>,
            incident: widget.incident?.uuid,
          );
          break;
        default:
          throw '_writeState: Unexpected identifier $identifier';
      }
      writeState<MapWidgetStateModel>(context, STATE, model);
      writeAppState(PageStorage.of(context));
    }
    return value;
  }
}

/// Incident MapController that supports animated move operations
class IncidentMapController extends MapControllerImpl {
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
