import 'dart:math' as math;

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/map/basemap_card.dart';
import 'package:SarSys/map/layers/coordate_layer.dart';
import 'package:SarSys/map/layers/device_layer.dart';
import 'package:SarSys/map/layers/measure_layer.dart';
import 'package:SarSys/map/map_controls.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/map/location_controller.dart';
import 'package:SarSys/map/map_caching.dart';
import 'package:SarSys/map/layers/scalebar.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/map/tools/measure_tool.dart';
import 'package:SarSys/map/tools/unit_tool.dart';
import 'package:SarSys/map/layers/unit_layer.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/image_cache_service.dart';
import 'package:SarSys/services/maptile_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';

import 'package:SarSys/map/layers/icon_layer.dart';
import 'package:SarSys/map/map_search.dart';
import 'package:SarSys/map/layers/my_location.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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

  final Incident incident;
  final TapCallback onTap;
  final PromptCallback onPrompt;
  final MessageCallback onMessage;
  final ToolCallback onToolChange;
  final IncidentMapController mapController;

  final GestureTapCallback onOpenDrawer;

  /// Center map on given point [center]. If [fitBounds] is given [center] is overridden
  final LatLng center;

  /// Fit map to given bounds. If [fitBounds] is given [center] is overridden
  final LatLngBounds fitBounds;

  /// If [fitBounds] is given, control who bounds is fitted with [fitBoundOptions]
  final FitBoundsOptions fitBoundOptions;

  IncidentMap({
    Key key,
    this.center,
    this.incident,
    this.fitBounds,
    this.fitBoundOptions = FIT_BOUNDS_OPTIONS,
    this.url = BASEMAP,
    this.offline = false,
    this.interactive = true,
    this.withSearch = false,
    this.withControls = false,
    this.withLocation = false,
    this.withScaleBar = false,
    this.withCoordsPanel = false,
    this.onTap,
    this.onPrompt,
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
  static const UNITS_LAYER = "Enheter";
  static const DEVICES_LAYER = "Terminaler";
  static const TRACKING_LAYER = "Sporing";
  static const COORDS_LAYER = "Koordinater";
  static const SCALE_LAYER = "Målestokk";
  static const LAYERS = [
    POI_LAYER,
    UNITS_LAYER,
    TRACKING_LAYER,
    DEVICES_LAYER,
    SCALE_LAYER,
    COORDS_LAYER,
  ];
  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  String _currentBaseMap;
  List<BaseMap> _baseMaps;
  MaptileService _maptileService = MaptileService();

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

  AppConfigBloc _appConfigBloc;

  @override
  void initState() {
    super.initState();
    _currentBaseMap = widget.url;
    _appConfigBloc = BlocProvider.of<AppConfigBloc>(context);
    // Configure location controller
    if (widget.withLocation) {
      _locationController = LocationController(
        appConfigBloc: _appConfigBloc,
        mapController: widget.mapController,
        tickerProvider: this,
        onMessage: widget.onMessage,
        onPrompt: widget.onPrompt,
        onTrackingChanged: _onTrackingChanged,
        onLocationChanged: _onLocationChanged,
      );
    }
    // Configure map tool controller
    if (widget.withControls) {
      _mapToolController = MapToolController(
        tools: [
          MeasureTool(),
          UnitTool(BlocProvider.of<TrackingBloc>(context), active: true),
        ],
      );
    }
    _center = _ensureCenter();
    _useLayers = Set.of(_withLayers())..removeAll([DEVICES_LAYER, TRACKING_LAYER, COORDS_LAYER]);
    _mapController = widget.mapController;
    // Only do this once per state instance
    _mapController.onReady.then((_) {
      if (widget.fitBounds != null)
        _mapController.fitBounds(
          widget.fitBounds,
          options: widget.fitBoundOptions ?? FIT_BOUNDS_OPTIONS,
        );
    });
    _mapController.progress.addListener(_onMoveProgress);

    _init();
  }

  LatLng _ensureCenter() {
    final bloc = BlocProvider.of<IncidentBloc>(context);
    final current = widget.withLocation ? _locationController.current : null;
    return widget.center ??
        (bloc.current?.meetup != null ? toLatLng(bloc.current?.meetup) : null) ??
        current ??
        Defaults.origo;
  }

  void _init() async {
    _baseMaps = await _maptileService.fetchMaps();
    _locationController?.init();
  }

  @override
  void dispose() {
    super.dispose();
    _mapToolController?.dispose();
    _locationController?.dispose();
    _mapController.progress.removeListener(_onMoveProgress);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMap(),
        if (widget.withControls) _buildControls(),
        if (widget.withSearch) _buildSearchBar(),
      ],
    );
  }

  Widget _buildMap() {
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
          IconLayer(),
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

  List<LayerOptions> _setLayerOptions() {
    final tool = _mapToolController?.of<MeasureTool>();
    final bloc = BlocProvider.of<IncidentBloc>(context);
    _layerOptions
      ..clear()
      ..addAll([
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
          tileProvider: ManagedCacheTileProvider(FileCacheService(_appConfigBloc.config)),
        ),
        if (_useLayers.contains(DEVICES_LAYER)) _buildDeviceOptions(),
        if (_useLayers.contains(UNITS_LAYER)) _buildUnitOptions(),
        if (_useLayers.contains(POI_LAYER))
          _buildPoiOptions({
            widget?.incident?.ipp ?? bloc?.current?.ipp: "IPP",
            widget?.incident?.meetup ?? bloc?.current?.meetup: "Oppmøte",
          }),
        if (_searchMatch != null) _buildMatchOptions(_searchMatch),
        if (widget.withLocation && _locationController.isReady) _locationController.options,
        if (widget.withCoordsPanel && _useLayers.contains(COORDS_LAYER)) CoordinateLayerOptions(),
        if (widget.withScaleBar && _useLayers.contains(SCALE_LAYER)) _buildScaleBarOptions(),
        if (tool != null && tool.active) MeasureLayerOptions(tool),
      ]);
    return _layerOptions;
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
          child: MapSearchField(
            key: _searchFieldKey,
            mapController: _mapController,
            zoom: _zoom,
            onError: widget.onMessage,
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
              tool.active = !tool.active;
              tool.init();
              _isMeasuring.value = MapControlState(toggled: tool.active);
              if (widget.onToolChange != null) widget.onToolChange(tool);
            },
          ),
        ],
      );
    }
    return _mapControls;
  }

  IconLayerOptions _buildPoiOptions(Map<Point, String> points) {
    final bloc = BlocProvider.of<IncidentBloc>(context);
    return IconLayerOptions(
      Map.fromEntries(
        points.entries.where((entry) => entry.key != null).map((entry) => MapEntry(toLatLng(entry.key), entry.value)),
      ),
      align: AnchorAlign.top,
      icon: Icon(
        Icons.location_on,
        size: 30,
        color: Colors.red,
      ),
      rebuild: bloc.state.map((_) => null),
    );
  }

  DeviceLayerOptions _buildDeviceOptions() {
    final bloc = BlocProvider.of<DeviceBloc>(context);
    return DeviceLayerOptions(
      bloc: bloc,
      onMessage: widget.onMessage,
    );
  }

  UnitLayerOptions _buildUnitOptions() {
    final bloc = BlocProvider.of<TrackingBloc>(context);
    return UnitLayerOptions(
      bloc: bloc,
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
    if (widget.withLocation) {
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
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Container(
            padding: EdgeInsets.all(24.0),
            child: GridView.count(
              crossAxisCount: landscape ? 4 : 2,
              children: _mapBottomSheetCards(),
            ),
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
    _isLocating.value = MapControlState(
      toggled: isLocated,
      locked: isLocked,
    );
    _setLayerOptions();
  }

  void _onLocationChanged(LatLng point) {
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

  List<String> _withLayers() {
    final layers = LAYERS.toList();
    if (!widget.withScaleBar) layers.remove(SCALE_LAYER);
    if (!widget.withCoordsPanel) layers.remove(COORDS_LAYER);
    return layers;
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
  bool isAnimating = false;
  ValueNotifier<MapMoveState> progress = ValueNotifier(MapMoveState.none());

  /// Move to given point and zoom
  void animatedMove(LatLng point, double zoom, TickerProvider provider,
      {int milliSeconds: 500, void onMove(LatLng p)}) {
    if (!ready) {
      move(point, zoom);
      progress.value = MapMoveState(point, zoom);
    } else if (!isAnimating) {
      isAnimating = true;
      // Create some tweens. These serve to split up the transition from one location to another.
      // In our case, we want to split the transition be<tween> our current map center and the destination.
      final _latTween = Tween<double>(begin: center.latitude, end: point.latitude);
      final _lngTween = Tween<double>(begin: center.longitude, end: point.longitude);
      final _zoomTween = Tween<double>(begin: this.zoom, end: zoom);

      // Create a animation controller that has a duration and a TickerProvider.
      final controller = AnimationController(duration: Duration(milliseconds: milliSeconds), vsync: provider);

      // The animation determines what path the animation will take. You can try different Curves values, although I found
      // fastOutSlowIn to be my favorite.
      Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

      controller.addListener(() {
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
        if (status == AnimationStatus.completed) {
          isAnimating = false;
          controller.dispose();
        } else if (status == AnimationStatus.dismissed) {
          isAnimating = false;
          controller.dispose();
        }
      });

      controller.forward();
    }
  }
}

class MapMoveState {
  final LatLng center;
  final double zoom;

  MapMoveState(this.center, this.zoom);

  static MapMoveState none() => MapMoveState(null, null);
}
