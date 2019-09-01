import 'dart:math' as math;

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/map/basemap_card.dart';
import 'package:SarSys/map/layers/coordate_layer.dart';
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

  final LatLng center;
  final Incident incident;
  final TapCallback onTap;
  final PromptCallback onPrompt;
  final MessageCallback onMessage;
  final ToolCallback onToolChange;
  final IncidentMapController mapController;

  final GestureTapCallback onOpenDrawer;

  IncidentMap({
    Key key,
    this.center,
    this.url = BASEMAP,
    this.incident,
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
  static const TRACKING_LAYER = "Sporing";
  static const COORDS_LAYER = "Koordinater";
  static const SCALE_LAYER = "Målestokk";
  static const LAYERS = [
    POI_LAYER,
    UNITS_LAYER,
    TRACKING_LAYER,
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
  MapToolController _mapToolController;
  LocationController _locationController;
  ValueNotifier<MapControlState> _isLocating = ValueNotifier(MapControlState());
  ValueNotifier<MapControlState> _isMeasuring = ValueNotifier(MapControlState());

  Set<String> _layers;

  AppConfigBloc _appConfigBloc;

  @override
  void initState() {
    super.initState();
    _currentBaseMap = widget.url;
    _appConfigBloc = BlocProvider.of<AppConfigBloc>(context);
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
    if (widget.withControls) {
      _mapToolController = MapToolController(
        tools: [
          MeasureTool(),
          UnitTool(BlocProvider.of<TrackingBloc>(context), active: true),
        ],
      );
    }
    _center = widget.center ?? Defaults.origo;
    _layers = Set.of(_withLayers())..remove(COORDS_LAYER);
    widget.mapController.progress.addListener(_onMoveProgress);
    _init();
  }

  void _init() async {
    _baseMaps = await _maptileService.fetchMaps();
    _locationController?.init();
  }

  @override
  void didUpdateWidget(IncidentMap old) {
    super.didUpdateWidget(old);
    if (old.mapController != widget.mapController) {
      widget.mapController.progress.removeListener(_onMoveProgress);
      widget.mapController.progress.addListener(_onMoveProgress);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _mapToolController?.dispose();
    _locationController?.dispose();
    widget.mapController.progress.removeListener(_onMoveProgress);
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
    final tool = _mapToolController?.of<MeasureTool>();
    final bloc = BlocProvider.of<IncidentBloc>(context);
    return FlutterMap(
      key: widget.incident == null ? GlobalKey() : ObjectKey(widget.incident),
      mapController: widget.mapController,
      options: MapOptions(
        center: _center,
        zoom: _zoom,
        maxZoom: Defaults.maxZoom,
        minZoom: Defaults.minZoom,
        interactive: widget.interactive,
        onTap: (point) => _onTap(point),
        onLongPress: (point) => _onLongPress(point),
        onPositionChanged: _onPositionChanged,
        plugins: [
          MyLocation(),
          IconLayer(),
          UnitLayer(),
          CoordinateLayer(),
          ScaleBar(),
          MeasureLayer(),
        ],
      ),
      layers: [
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
          tileProvider: ManagedCacheTileProvider(FileCacheService(_appConfigBloc.config)),
        ),
        if (_layers.contains(UNITS_LAYER)) _buildUnitOptions(),
        if (_layers.contains(POI_LAYER))
          _buildPoiOptions([
            widget?.incident?.ipp ?? bloc?.current?.ipp,
            widget?.incident?.meetup ?? bloc?.current?.meetup,
          ]),
        if (_searchMatch != null) _buildMatchOptions(_searchMatch),
        if (widget.withLocation && _locationController.isReady) _locationController.options,
        if (widget.withCoordsPanel && _layers.contains(COORDS_LAYER)) CoordinateLayerOptions(),
        if (widget.withScaleBar && _layers.contains(SCALE_LAYER)) _buildScaleBarOptions(),
        if (tool != null && tool.active) MeasureLayerOptions(tool),
      ],
    );
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
            mapController: widget.mapController,
            zoom: 18,
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
              widget.mapController.animatedMove(_center, _zoom, this, milliSeconds: 250);
            },
          ),
          MapControl(
            icon: Icons.remove,
            onPressed: () {
              _zoom = math.max(_zoom - 1, Defaults.minZoom);
              widget.mapController.animatedMove(_center, _zoom, this, milliSeconds: 250);
            },
          ),
          MapControl(
            icon: Icons.gps_fixed,
            listenable: _isLocating,
            onPressed: () {
              _locationController.toggle();
            },
            onLongPress: () {
              _locationController.toggle(locked: true);
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

  IconLayerOptions _buildPoiOptions(List<Point> points) {
    final bloc = BlocProvider.of<IncidentBloc>(context);
    return IconLayerOptions(
      points.where((point) => point != null).map((point) => toLatLng(point)).toList(),
      labels: ["IPP", "Oppmøte"],
      align: AnchorAlign.top,
      icon: Icon(
        Icons.location_on,
        size: 30,
        color: Colors.red,
      ),
      rebuild: bloc.state.map((_) => null),
    );
  }

  UnitLayerOptions _buildUnitOptions() {
    final bloc = BlocProvider.of<TrackingBloc>(context);
    return UnitLayerOptions(
      bloc: bloc,
      onMessage: widget.onMessage,
      showTail: _layers.contains(TRACKING_LAYER),
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
    if (hasGesture && widget.mapController.ready) {
      _zoom = widget.mapController.zoom;
      if (widget.withLocation && _locationController.isTracking) {
        if (_locationController.isLocked) {
          center = _center;
          widget.mapController.move(_center, _zoom);
        } else {
          _locationController.toggle();
        }
      }
    }
    _center = center;
  }

  void _clearSearchField() {
    _searchFieldKey?.currentState?.clear();
  }

  void _onSearchMatch(LatLng point) {
    setState(() {
      _center = point;
      _searchMatch = point;
    });
  }

  void _onSearchCleared() {
    setState(() {
      _searchMatch = null;
    });
  }

  void _showBaseMapBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Container(
            padding: EdgeInsets.all(24.0),
            child: GridView.count(
              crossAxisCount: 2,
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
          onTap: () {
            setState(() {
              _currentBaseMap = map.url;
            });
            Navigator.pop(context);
          },
        ),
      );
    }
    return _mapCards;
  }

  void _onTrackingChanged(bool isTracking, bool isLocked) {
    _isLocating.value = MapControlState(
      toggled: isTracking,
      locked: isLocked,
    );
  }

  void _onLocationChanged(LatLng point) {
    setState(() {
      _center = point;
    });
  }

  void _showLayerSheet(context) {
    final style = Theme.of(context).textTheme.title;
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
                      title: Text("Vis", style: style),
                      trailing: FlatButton(
                        child: Text('BRUK', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.0)),
                        onPressed: () => setState(
                          () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                    Divider(),
                    ..._withLayers()
                        .map((layer) => ListTile(
                            dense: true,
                            title: Text(layer, style: style),
                            trailing: Switch(
                              value: _layers.contains(layer),
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
        _layers.add(layer);
      } else {
        _layers.remove(layer);
      }
    });
  }

  void _onMoveProgress() {
    _zoom = widget.mapController.progress.value.zoom;
    _center = widget.mapController.progress.value.center;
  }
}

/// Incident MapController that supports animated move operations
class IncidentMapController extends MapControllerImpl {
  ValueNotifier<MapMoveState> progress = ValueNotifier(MapMoveState.none());

  /// Move to given point and zoom
  void animatedMove(LatLng point, double zoom, TickerProvider provider, {int milliSeconds: 500}) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final _latTween = Tween<double>(begin: center.latitude, end: point.latitude);
    final _lngTween = Tween<double>(begin: center.longitude, end: point.longitude);
    final _zoomTween = Tween<double>(begin: this.zoom, end: zoom);

    // Create a animation controller that has a duration and a TickerProvider.
    var controller = AnimationController(duration: Duration(milliseconds: milliSeconds), vsync: provider);

    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      final state = MapMoveState(
        LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation)),
        _zoomTween.evaluate(animation),
      );
      move(state.center, state.zoom);
      progress.value = state;
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }
}

class MapMoveState {
  final LatLng center;
  final double zoom;

  MapMoveState(this.center, this.zoom);

  static MapMoveState none() => MapMoveState(null, null);
}
