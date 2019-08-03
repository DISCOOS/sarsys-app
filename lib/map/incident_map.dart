import 'dart:math' as math;

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/map/basemap_card.dart';
import 'package:SarSys/map/cross_painter.dart';
import 'package:SarSys/map/location_controller.dart';
import 'package:SarSys/map/tracking_layer.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/maptile_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
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
    this.onTap,
    this.onPrompt,
    this.onMessage,
    this.onOpenDrawer,
    MapController mapController,
  })  : this.mapController = mapController ?? MapController(),
        super(key: key);

  @override
  _IncidentMapState createState() => _IncidentMapState();
}

class _IncidentMapState extends State<IncidentMap> {
  static const POI_LAYER = "Interessepunkt";
  static const TRACKING_LAYER = "Sporing";
  static const LAYERS = [POI_LAYER, TRACKING_LAYER];
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

  @override
  void initState() {
    super.initState();
    _currentBaseMap = widget.url;
    if (widget.withLocation) {
      _locationController = LocationController(
        appConfigBloc: BlocProvider.of<AppConfigBloc>(context),
        mapController: widget.mapController,
        onMessage: widget.onMessage,
        onPrompt: widget.onPrompt,
        onTrackingChanged: _onTrackingChanged,
        onLocationChanged: _onLocationChanged,
      );
    }
    _center = widget.center ?? Defaults.origo;
    _layers = Set.of(LAYERS);

    init();
  }

  void init() async {
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
    Point ipp = widget?.incident?.ipp ?? BlocProvider.of<IncidentBloc>(context)?.current?.ipp;
    return FlutterMap(
      key: widget.incident == null ? GlobalKey() : ObjectKey(widget.incident),
      mapController: widget.mapController,
      options: MapOptions(
        center: _center,
        zoom: _zoom,
        maxZoom: Defaults.maxZoom,
        minZoom: Defaults.minZoom,
        interactive: widget.interactive,
        onTap: _onTap,
        onPositionChanged: _onPositionChanged,
        plugins: [
          MyLocation(),
          IconLayer(),
          TrackingLayer(),
        ],
      ),
      layers: [
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
          tileProvider: NetworkTileProvider(),
        ),
        if (_layers.contains(TRACKING_LAYER)) _buildTrackingOptions(),
        if (ipp != null && _layers.contains(POI_LAYER)) _buildPoiOptions([ipp]),
        if (_searchMatch != null) _buildMatchOptions(_searchMatch),
        if (widget.withLocation && _locationController.isReady) _locationController.options,
      ],
    );
  }

  Widget _buildSearchBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: MapSearchField(
          key: _searchFieldKey,
          controller: widget.mapController,
          zoom: 18,
          onError: widget.onMessage,
          onMatch: _onSearchMatch,
          onCleared: _onSearchCleared,
          prefixIcon: widget.onOpenDrawer == null
              ? Container()
              : GestureDetector(
                  child: Icon(Icons.menu),
                  onTap: widget.onOpenDrawer,
                ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    Size size = Size(42.0, 42.0);
    return Positioned(
      top: 100.0,
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
            child: IconButton(
              color: value ? Colors.green : Colors.black,
              icon: Icon(Icons.gps_fixed),
              onPressed: () {
                _locationController.toggle();
              },
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(30.0),
            ),
          );
        });
  }

  IconLayerOptions _buildPoiOptions(List<Point> points) {
    return IconLayerOptions(
      points.map((point) => toLatLng(point)).toList(),
      icon: Icon(
        Icons.location_on,
        size: 30,
        color: Colors.red,
      ),
    );
  }

  TrackingLayerOptions _buildTrackingOptions() {
    final trackingBloc = BlocProvider.of<TrackingBloc>(context);
    return TrackingLayerOptions(
      bloc: trackingBloc,
      onMessage: widget.onMessage,
      rebuild: trackingBloc.state,
    );
  }

  MarkerLayerOptions _buildMatchOptions(LatLng point) {
    return MarkerLayerOptions(
      markers: [
        Marker(
          width: 80.0,
          height: 80.0,
          point: point,
          builder: (_) => SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: CrossPainter(),
              )),
        ),
      ],
    );
  }

  void _onTap(LatLng point) {
    if (_searchMatch == null) _clearSearchField();
    if (widget.onTap != null) widget.onTap(point);
  }

  void _onPositionChanged(MapPosition position, bool hasGesture, bool isUserGesture) {
    _center = position.center;
    if (isUserGesture && widget.withLocation && _locationController.isTracking) {
      _locationController.toggle();
    }
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
      _mapCards.add(GestureDetector(
        child: BaseMapCard(map: map),
        onTap: () {
          setState(() {
            _currentBaseMap = map.url;
          });
          Navigator.pop(context);
        },
      ));
    }
    return _mapCards;
  }

  void _onTrackingChanged(bool isTracking) {
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
        builder: (BuildContext bc) {
          return StatefulBuilder(builder: (context, state) {
            return Container(
              padding: EdgeInsets.only(bottom: 56.0),
              child: Wrap(
                children: <Widget>[
                  ListTile(
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
                  ...LAYERS
                      .map((layer) => ListTile(
                          title: Text(layer, style: style),
                          trailing: Switch(
                            value: _layers.contains(layer),
                            onChanged: (value) => _onFilterChanged(layer, value, state),
                          )))
                      .toList(),
                ],
              ),
            );
          });
        });
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
}
