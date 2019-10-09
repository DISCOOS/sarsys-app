import 'dart:math' as math;

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/map/basemap_card.dart';
import 'package:SarSys/map/layers/coordate_layer.dart';
import 'package:SarSys/map/layers/device_layer.dart';
import 'package:SarSys/map/layers/measure_layer.dart';
import 'package:SarSys/map/map_controls.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/controllers/location_controller.dart';
import 'package:SarSys/map/map_caching.dart';
import 'package:SarSys/map/layers/scalebar.dart';
import 'package:SarSys/map/tools/device_tool.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/map/tools/measure_tool.dart';
import 'package:SarSys/map/tools/poi_tool.dart';
import 'package:SarSys/map/tools/unit_tool.dart';
import 'package:SarSys/map/layers/unit_layer.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/image_cache_service.dart';
import 'package:SarSys/services/maptile_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/map/layers/poi_layer.dart';
import 'package:SarSys/map/map_search.dart';
import 'package:SarSys/map/layers/my_location.dart';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:provider/provider.dart';
import 'package:latlong/latlong.dart';
import 'package:wakelock/wakelock.dart';

typedef ToolCallback = void Function(MapTool tool);

class IncidentMap extends StatefulWidget {
  static const BASEMAP = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";

  final String url;
  final bool offline;
  final bool interactive;
  final bool withSearch;
  final bool withControls;
  final bool withLocation;
  final bool withScaleBar;
  final bool withCoordsPanel;

  final bool withPOIs;
  final bool withUnits;
  final bool withDevices;
  final bool withTracking;

  final Incident incident;
  final TapCallback onTap;
  final MessageCallback onMessage;
  final ToolCallback onToolChange;
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

  final List<String> showLayers;

  IncidentMap({
    Key key,
    this.zoom,
    this.center,
    this.incident,
    this.fitBounds,
    this.fitBoundOptions = FIT_BOUNDS_OPTIONS,
    this.url = BASEMAP,
    this.offline = false,
    this.interactive = true,
    this.withPOIs = true,
    this.withUnits = true,
    this.withDevices = true,
    this.withSearch = false,
    this.withControls = false,
    this.withLocation = false,
    this.withScaleBar = false,
    this.withTracking = true,
    this.withCoordsPanel = false,
    this.showLayers = IncidentMapState.DEFAULT_LAYERS,
    this.onTap,
    this.onMessage,
    this.onToolChange,
    this.onOpenDrawer,
    MapController mapController,
  })  : this.mapController = mapController ?? IncidentMapController(),
        super(key: key);

  @override
  IncidentMapState createState() => IncidentMapState();
}

class IncidentMapState extends State<IncidentMap> with TickerProviderStateMixin {
  static const POI_LAYER = "Interessepunkt";
  static const UNIT_LAYER = "Enheter";
  static const DEVICE_LAYER = "Apparater";
  static const TRACKING_LAYER = "Sporing";
  static const COORDS_LAYER = "Koordinater";
  static const SCALE_LAYER = "Målestokk";

  static const ALL_LAYERS = [
    POI_LAYER,
    UNIT_LAYER,
    TRACKING_LAYER,
    DEVICE_LAYER,
    SCALE_LAYER,
    COORDS_LAYER,
  ];
  static const DEFAULT_LAYERS = [
    POI_LAYER,
    UNIT_LAYER,
    SCALE_LAYER,
  ];

  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  String _currentBaseMap;
  List<BaseMap> _baseMaps;
  MaptileService _mapTileService = MaptileService();

  LatLng _center;
  LatLng _searchMatch;
  double _zoom = Defaults.zoom;

  MapControls _mapControls;
  IncidentMapController _mapController;
  MapToolController _mapToolController;
  LocationController _locationController;

  ValueNotifier<MapControlState> _isLocating = ValueNotifier(MapControlState());
  ValueNotifier<MapControlState> _isMeasuring = ValueNotifier(MapControlState());

  Set<String> _useLayers;
  List<LayerOptions> _layerOptions = [];

  // Prevent location updates after dispose
  bool _disposed = false;

  AppConfigBloc _configBloc;
  TrackingBloc _trackingBloc;
  IncidentBloc _incidentBloc;

  bool _wakeLockWasOn;
  bool _hasFitToBounds = false;

  @override
  void initState() {
    super.initState();
    _zoom = widget.zoom ?? Defaults.zoom;
    _currentBaseMap = widget.url;
    _useLayers = _withLayers()..retainAll(widget.showLayers.toSet());
    _mapController = widget.mapController;
    _mapController.progress.addListener(_onMoveProgress);

    _configBloc = BlocProvider.of<AppConfigBloc>(context);
    _incidentBloc = BlocProvider.of<IncidentBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);

    // Configure map tool controller
    if (widget.withControls) {
      _mapToolController = MapToolController(
        tools: [
          MeasureTool(),
          POITool(
            _incidentBloc,
            active: () => _useLayers.contains(POI_LAYER),
            onMessage: widget.onMessage,
          ),
          UnitTool(
            _trackingBloc,
            active: () => _useLayers.contains(UNIT_LAYER),
            onMessage: widget.onMessage,
          ),
          DeviceTool(
            _trackingBloc,
            active: () => _useLayers.contains(DEVICE_LAYER),
            onMessage: widget.onMessage,
          ),
        ],
      );
    }
    _init();
  }

  void _init() async {
    _baseMaps = await _mapTileService.fetchMaps();
    _wakeLockWasOn = await Wakelock.isEnabled;
    await Wakelock.toggle(on: _configBloc.config.keepScreenOn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Ensure all controllers are set
    _ensureMapToolController();
    _ensureLocationControllers();

    // Only ensure center if not set already
    _center ??= _ensureCenter();
  }

  void _ensureMapToolController() {
    if (widget.withControls) {
      _mapToolController ??= MapToolController(
        tools: [
          MeasureTool(),
          POITool(
            _incidentBloc,
            active: () => _useLayers.contains(POI_LAYER),
            onMessage: widget.onMessage,
          ),
          UnitTool(
            _trackingBloc,
            active: () => _useLayers.contains(UNIT_LAYER),
            onMessage: widget.onMessage,
          ),
          DeviceTool(
            _trackingBloc,
            active: () => _useLayers.contains(DEVICE_LAYER),
            onMessage: widget.onMessage,
          ),
        ],
      );
    }
  }

  void _ensureLocationControllers() {
    // Configure location controller only once
    if (widget.withLocation && _locationController == null) {
      _locationController = LocationController(
        tickerProvider: this,
        configBloc: _configBloc,
        permissionController: Provider.of<PermissionController>(context).cloneWith(
          onMessage: widget.onMessage,
        ),
        mapController: widget.mapController,
        onTrackingChanged: _onTrackingChanged,
        onLocationChanged: _onLocationChanged,
      );
      _locationController.init();
    }
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
    _isLocating = null;
    _isMeasuring = null;
    _mapController = null;
    _mapToolController = null;
    _locationController = null;
    _restoreWakeLock();

    super.dispose();
  }

  void _restoreWakeLock() async {
    final wakeLock = await Wakelock.isEnabled;
    if (wakeLock != _wakeLockWasOn) await Wakelock.toggle(on: _wakeLockWasOn);
  }

  LatLng _ensureCenter() {
    final current = widget.withLocation ? _locationController.current : null;
    return widget.center ??
        (_incidentBloc?.current?.meetup != null ? toLatLng(_incidentBloc?.current?.meetup) : null) ??
        (current != null ? LatLng(current.latitude, current.longitude) : Defaults.origo);
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

  Widget _buildMap() {
    _fitToBoundsOnce();
    return FlutterMap(
      key: widget.incident == null ? GlobalKey() : ObjectKey(widget.incident),
      mapController: _mapController,
      options: MapOptions(
        zoom: _zoom,
        center: _center,
        maxZoom: Defaults.maxZoom,
        minZoom: Defaults.minZoom,
        interactive: widget.interactive,
        onTap: (point) => _onTap(point),
        onLongPress: (point) => _onLongPress(point),
        onPositionChanged: _onPositionChanged,
        plugins: [
          MyLocation(),
          POILayer(),
          DeviceLayer(),
          UnitLayer(),
          CoordinateLayer(),
          ScaleBar(),
          MeasureLayer(),
        ],
      ),
      layers: _setLayerOptions(),
    );
  }

  void _fitToBoundsOnce() async {
    if (_hasFitToBounds == false) {
      if (widget.fitBounds?.isValid == true) {
        // Listen for ready event
        _mapController.onReady.then((_) => _fitBounds());
      }
      // Only do this once per state instance
      _hasFitToBounds = true;
    }
  }

  void _fitBounds() {
    _mapController.fitBounds(
      widget.fitBounds,
      options: widget.fitBoundOptions ?? FIT_BOUNDS_OPTIONS,
    );
  }

  /*
  void _debugFitBounds() {
    final fitBounds = widget.fitBounds;
    final fitBoundOptions = widget.fitBoundOptions ?? FIT_BOUNDS_OPTIONS;
    final centerZoom = _mapController.getBoundsCenterZoom(fitBounds, fitBoundOptions);
    try {
      _fitBounds();
    } on Error catch (e) {
      Catcher.reportCheckedError(
        "Method _fitBounds() failed with: \n "
        "_mapController(zoom: ${_mapController.zoom}, center: ${_mapController.center}, ${_mapController.size}, "
        "options(zoom: ${_mapController.options.zoom}), state(zoom: ${_mapController.state.zoom})) \n"
        "fitBounds(isValid: ${fitBounds.isValid}, west: ${fitBounds.west}, "
        "north: ${fitBounds.north}, east: ${fitBounds.east}, south: ${fitBounds.south}) \n"
        "fitBoundsOptions(zoom: ${fitBoundOptions.zoom}, maxZoom ${fitBoundOptions.maxZoom}),${fitBoundOptions.padding}) \n"
        "centerZoom(zoom: ${centerZoom.zoom}, center: ${centerZoom.center}). \n"
        "Error was $e",
        e.stackTrace,
      );
    }
  }
   */

  List<LayerOptions> _setLayerOptions() {
    final tool = _mapToolController?.of<MeasureTool>();
    _layerOptions
      ..clear()
      ..addAll([
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
          tileProvider: _buildTileProvider(),
        ),
        if (_useLayers.contains(DEVICE_LAYER)) _buildDeviceOptions(),
        if (_useLayers.contains(UNIT_LAYER)) _buildUnitOptions(),
        if (_useLayers.contains(POI_LAYER))
          _buildPoiOptions({
            widget?.incident?.ipp ?? _incidentBloc?.current?.ipp: "IPP",
            widget?.incident?.meetup ?? _incidentBloc?.current?.meetup: "Oppmøte",
          }),
        if (_searchMatch != null) _buildMatchOptions(_searchMatch),
        if (widget.withLocation && _locationController?.isReady == true) _locationController.options,
        if (widget.withCoordsPanel && _useLayers.contains(COORDS_LAYER)) CoordinateLayerOptions(),
        if (widget.withScaleBar && _useLayers.contains(SCALE_LAYER)) _buildScaleBarOptions(),
        if (tool != null && tool.active()) MeasureLayerOptions(tool),
      ]);
    return _layerOptions;
  }

  TileProvider _buildTileProvider() {
    return ManagedCacheTileProvider(FileCacheService(_configBloc.config));
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
              mapController: _mapController,
              zoom: _zoom,
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
        controller: _mapToolController,
        controls: [
          MapControl(
            icon: Icons.filter_list,
            onPressed: () => _showLayerSheet(context),
          ),
          MapControl(
            icon: Icons.map,
            onPressed: () {
              _showBaseMapBottomSheet(context);
            },
          ),
          MapControl(
            icon: Icons.add,
            onPressed: () {
              _zoom = math.min(_zoom + 1, Defaults.maxZoom);
              _mapController.animatedMove(_center, _zoom, this, milliSeconds: 250);
            },
          ),
          MapControl(
            icon: Icons.remove,
            onPressed: () {
              _zoom = math.max(_zoom - 1, Defaults.minZoom);
              _mapController.animatedMove(_center, _zoom, this, milliSeconds: 250);
            },
          ),
          MapControl(
            icon: Icons.gps_fixed,
            listenable: _isLocating,
            onPressed: () {
              _locationController.goto();
            },
            onLongPress: () {
              _locationController.goto(locked: true);
            },
          ),
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

  POILayerOptions _buildPoiOptions(Map<Point, String> points) {
    return POILayerOptions(
      List.from(points.entries.where((entry) => entry.key != null).map(
            (entry) => POI(
              name: entry.value,
              point: entry.key,
            ),
          )),
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
      showTail: _useLayers.contains(TRACKING_LAYER),
    );
  }

  UnitLayerOptions _buildUnitOptions() {
    return UnitLayerOptions(
      bloc: _trackingBloc,
      onMessage: widget.onMessage,
      showTail: _useLayers.contains(TRACKING_LAYER),
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
      _zoom = _mapController.zoom;
      if (widget.withLocation) {
        if (_locationController.isLocked) {
          center = _center;
          _mapController.move(_center, _zoom);
        }
      }
    }
    if ((hasGesture) && widget.withLocation) {
      if (_locationController.isLocated != _isLocating.value?.toggled) {
        _isLocating.value = MapControlState(
          toggled: _locationController.isLocated,
          locked: _locationController.isLocked,
        );
      }
    }
    _center = center;
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

  void _showBaseMapBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Internettkart", style: Theme.of(context).textTheme.title),
              ),
              Divider(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: landscape ? 4 : 2,
                    children: _mapBottomSheetCards(),
                  ),
                ),
              ),
            ],
          );
        });
  }

  List<Widget> _mapBottomSheetCards() {
    List<Widget> _mapCards = [];

    for (BaseMap map in _baseMaps) {
      _mapCards.add(
        GestureDetector(
          child: Center(child: BaseMapCard(map: map)),
          onTap: () => setState(
            () {
              _currentBaseMap = map.url;
              _setLayerOptions();
              Navigator.pop(context);
            },
          ),
        ),
      );
    }
    return _mapCards;
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
    final title = Theme.of(context).textTheme.title;
    final filter = Theme.of(context).textTheme.subtitle;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return StatefulBuilder(builder: (context, state) {
          return DraggableScrollableSheet(
              expand: false,
              builder: (context, controller) {
                return ListView(
                  padding: EdgeInsets.only(bottom: 56.0),
                  children: <Widget>[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.only(left: 16.0, right: 0),
                      title: Text("Vis", style: title),
                      trailing: FlatButton(
                        child: Text('LUKK', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.0)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Divider(),
                    ..._withLayers()
                        .map((layer) => ListTile(
                            dense: true,
                            title: Text(layer, style: filter),
                            trailing: Switch(
                              value: _useLayers.contains(layer),
                              onChanged: (value) => _onFilterChanged(layer, value, state),
                            )))
                        .toList(),
                  ],
                );
              });
        });
      },
    );
  }

  Set<String> _withLayers() {
    final layers = ALL_LAYERS.toList();
    if (!widget.withScaleBar) layers.remove(SCALE_LAYER);
    if (!widget.withCoordsPanel) layers.remove(COORDS_LAYER);
    if (!widget.withPOIs) layers.remove(POI_LAYER);
    if (!widget.withUnits) layers.remove(UNIT_LAYER);
    if (!widget.withDevices) layers.remove(DEVICE_LAYER);
    if (!widget.withTracking) layers.remove(TRACKING_LAYER);
    return layers.toSet();
  }

  void _onFilterChanged(String layer, bool value, StateSetter update) {
    update(() {
      if (value) {
        _useLayers.add(layer);
      } else {
        _useLayers.remove(layer);
      }
      setState(() {});
    });
  }

  void _onMoveProgress() {
    _zoom = _mapController.progress.value.zoom;
    _center = _mapController.progress.value.center;
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
