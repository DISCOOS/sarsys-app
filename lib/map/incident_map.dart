import 'dart:math' as math;

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/map/basemap_card.dart';
import 'package:SarSys/map/coordate_layer.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/map/location_controller.dart';
import 'package:SarSys/map/map_caching.dart';
import 'package:SarSys/map/scalebar.dart';
import 'package:SarSys/map/unit_layer.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/image_cache_service.dart';
import 'package:SarSys/services/maptile_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

import 'package:SarSys/map/icon_layer.dart';
import 'package:SarSys/map/map_search_field.dart';
import 'package:SarSys/map/my_location.dart';

typedef MessageCallback = void Function(String message, {String action, VoidCallback onPressed});

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
  final MapController mapController;
  final TapCallback onTap;
  final PromptCallback onPrompt;
  final MessageCallback onMessage;

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
    this.onOpenDrawer,
    MapController mapController,
  })  : this.mapController = mapController ?? MapController(),
        super(key: key);

  @override
  IncidentMapState createState() => IncidentMapState();
}

class IncidentMapState extends State<IncidentMap> {
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

  LocationController _locationController;
  ValueNotifier<bool> _isLocating = ValueNotifier(false);

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
        onMessage: widget.onMessage,
        onPrompt: widget.onPrompt,
        onTrackingChanged: _onTrackingChanged,
        onLocationChanged: _onLocationChanged,
      );
    }
    _center = widget.center ?? Defaults.origo;
    _layers = Set.of(_withLayers())..remove(COORDS_LAYER);
    _init();
  }

  void _init() async {
    _baseMaps = await _maptileService.fetchMaps();
    _locationController?.init();
  }

  @override
  void dispose() {
    super.dispose();
    _locationController?.dispose();
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
        onTap: (point) => _onAction(point, UnitLayer.showUnitInfo),
        onLongPress: (point) => _onAction(point, UnitLayer.showUnitMenu),
        onPositionChanged: _onPositionChanged,
        plugins: [
          MyLocation(),
          IconLayer(),
          UnitLayer(),
          CoordinateLayer(),
          ScaleBar(),
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
        if (widget.withScaleBar && _layers.contains(SCALE_LAYER)) _buildScaleBarOptions()
      ],
    );
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
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: math.min(size.width, size.height)),
          child: MapSearchField(
            key: _searchFieldKey,
            controller: widget.mapController,
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
    final Size size = Size(42.0, 42.0);
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Positioned(
      top: landscape ? 72.0 : 100.0,
      right: 8.0,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              width: size.width,
              height: size.height,
              child: _buildFilterAction(),
            ),
            SizedBox(
              height: 4.0,
            ),
            SizedBox(
              width: size.width,
              height: size.height,
              child: _buildBaseMapAction(),
            ),
            SizedBox(
              height: 4.0,
            ),
            SizedBox(
              width: size.width,
              height: size.height,
              child: _buildZoomInAction(),
            ),
            SizedBox(
              height: 4.0,
            ),
            SizedBox(
              width: size.width,
              height: size.height,
              child: _buildZoomOutAction(),
            ),
            SizedBox(height: 4.0),
            SizedBox(
              width: size.width,
              height: size.height,
              child: _buildLocateAction(size),
            ),
          ],
        ),
      ),
    );
  }

  Container _buildFilterAction() {
    return Container(
      child: IconButton(
        icon: Icon(Icons.filter_list),
        onPressed: () => _showLayerSheet(context),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(30.0),
      ),
    );
  }

  Container _buildBaseMapAction() {
    return Container(
      child: IconButton(
        icon: Icon(Icons.map),
        onPressed: () {
          _showBaseMapBottomSheet(context);
        },
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(30.0),
      ),
    );
  }

  Container _buildZoomInAction() {
    return Container(
      child: IconButton(
        icon: Icon(Icons.add),
        onPressed: () {
          _zoom = math.min(_zoom + 1, Defaults.maxZoom);
          widget.mapController.move(_center, _zoom);
//          setState(() {
//            _zoom = math.min(_zoom + 1, Defaults.maxZoom);
//          });
        },
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(30.0),
      ),
    );
  }

  Container _buildZoomOutAction() {
    return Container(
      child: IconButton(
        icon: Icon(Icons.remove),
        onPressed: () {
          _zoom = math.max(_zoom - 1, Defaults.minZoom);
          widget.mapController.move(_center, _zoom);
//          setState(() {
//            _zoom = math.max(_zoom - 1, Defaults.minZoom);
//          });
        },
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(30.0),
      ),
    );
  }

  Widget _buildLocateAction(Size size) {
    return ValueListenableBuilder(
        valueListenable: _isLocating,
        builder: (BuildContext context, bool value, Widget child) {
          return Container(
            child: GestureDetector(
              child: IconButton(
                color: value ? Colors.green : Colors.black,
                icon: Icon(Icons.gps_fixed),
                onPressed: () {
                  _locationController.toggle();
                },
              ),
              onLongPress: () {
                _locationController.toggle(locked: true);
              },
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              border: Border.all(color: _locationController.isLocked ? Colors.green : Colors.grey),
              borderRadius: BorderRadius.circular(30.0),
            ),
          );
        });
  }

  IconLayerOptions _buildPoiOptions(List<Point> points) {
    final bloc = BlocProvider.of<IncidentBloc>(context);
    return IconLayerOptions(
      points.map((point) => toLatLng(point)).toList(),
      labels: ["IPP", "Oppmøte"],
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
      rebuild: bloc.state.map((_) => null),
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

  void _onAction(LatLng point, Function onAction) {
    if (_searchMatch == null) _clearSearchField();

    //showUnitInfo(context, unit, options.bloc, options.onMessage)
    final bloc = BlocProvider.of<TrackingBloc>(context);
    final tracks = bloc.tracks;
    final size = MediaQuery.of(context).size;
    final tolerance = 120.0 / math.max(size.width, size.height);
    var distance = tolerance * ScaleBar.toDistance(ScalebarOption.SCALES, _zoom);
    // Find first unit within given tolerance of tapped point.
    final units = bloc.units.values.where(
      (unit) => _within(
        point,
        toLatLng(tracks[unit.tracking].location),
        distance,
      ),
    );
    if (units.isNotEmpty) _showUnit(units.toList(), bloc, onAction);

    if (widget.onTap != null) widget.onTap(point);
  }

  void _showUnit(List<Unit> units, TrackingBloc bloc, Function onAction) {
    if (units.length == 1) {
      onAction(context, units.first, bloc, widget.onMessage);
    } else {
      final style = Theme.of(context).textTheme.title;
      final size = MediaQuery.of(context).size;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('Velg enhet', style: style),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                Divider(),
                SizedBox(
                  height: math.min(size.height - 150, 380),
                  width: MediaQuery.of(context).size.width - 96,
                  child: ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        leading: Icon(Icons.group),
                        title: Text("${units[index].name}"),
                        onTap: () {
                          Navigator.of(context).pop();
                          onAction(context, units[index], bloc, widget.onMessage);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _onPositionChanged(MapPosition position, bool hasGesture, bool isUserGesture) {
    var center = position.center;
    if ((isUserGesture || hasGesture) && widget.mapController.ready) {
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
    _isLocating.value = isTracking;
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

  bool _within(LatLng point, LatLng location, double tolerance) {
    final distance = ProjMath.eucledianDistance(
      point.latitude,
      point.longitude,
      location.latitude,
      location.longitude,
    );
    return distance < tolerance;
  }
}
