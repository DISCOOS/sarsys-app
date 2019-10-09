import 'dart:math';
import 'dart:ui';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/map/layers/poi_layer.dart';
import 'package:SarSys/map/layers/scalebar.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/controllers/location_controller.dart';
import 'package:SarSys/map/map_search.dart';
import 'package:SarSys/widgets/input_coordinate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:wakelock/wakelock.dart';

class PointEditor extends StatefulWidget {
  final Point point;
  final String title;
  final Incident incident;
  final PermissionController controller;

  const PointEditor(
    this.point, {
    Key key,
    this.incident,
    @required this.title,
    @required this.controller,
  }) : super(key: key);

  @override
  _PointEditorState createState() => _PointEditorState();
}

class _PointEditorState extends State<PointEditor> with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  Point _current;
  String _currentBaseMap;
  MapSearchField _searchField;
  IncidentMapController _mapController;
  LocationController _locationController;

  bool _wakeLockWasOn;

  @override
  void initState() {
    super.initState();
    // TODO: Dont bother fixing this now, moving to BLoC/Streamcontroller later
    _currentBaseMap = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
    _mapController = IncidentMapController();
    // TODO: Use device location as default location
    _current = widget.point == null ? Point.now(59.5, 10.09) : widget.point;
    _searchField = MapSearchField(
      key: _searchFieldKey,
      offset: 106.0,
      withBorder: false,
      onError: _onError,
      mapController: _mapController,
      onMatch: (point) => setState(() => _current = Point.now(point.latitude, point.longitude)),
    );
    _init();
  }

  void _init() async {
    _wakeLockWasOn = await Wakelock.isEnabled;
    await Wakelock.toggle(on: BlocProvider.of<AppConfigBloc>(context).config.keepScreenOn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locationController == null) {
      _locationController = LocationController(
        mapController: _mapController,
        configBloc: BlocProvider.of<AppConfigBloc>(context),
        permissionController: widget.controller.cloneWith(
          onMessage: _showMessage,
        ),
        tickerProvider: this,
        onLocationChanged: (point) => setState(() => _current = Point.now(point.latitude, point.longitude)),
      );
      _locationController.init();
    }
  }

  @override
  void dispose() {
    _mapController?.cancel();
    _locationController?.dispose();
    _mapController = null;
    _locationController = null;
    _restoreWakeLock();

    super.dispose();
  }

  void _restoreWakeLock() async {
    final wakeLock = await Wakelock.isEnabled;
    if (wakeLock != _wakeLockWasOn) await Wakelock.toggle(on: wakeLock);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        leading: GestureDetector(
          child: Icon(Icons.close),
          onTap: () {
            _searchFieldKey.currentState.clear();
            Navigator.pop(context, widget.point);
          },
        ),
        actions: <Widget>[
          FlatButton(
            child: Text('FERDIG', style: TextStyle(fontSize: 14.0, color: Colors.white)),
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            onPressed: () {
              Navigator.pop(context, _current);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildCenterMark(),
          _buildInputFields(),
          _buildControls(),
        ],
      ),
      resizeToAvoidBottomInset: false,
    );
  }

  Widget _buildInputFields() {
    final size = MediaQuery.of(context).size;
    final maxWidth = min(min(size.width, size.height), 380.0);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildSearchField(),
                _buildUTMField(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 4.0),
      child: _searchField,
    );
  }

  Widget _buildUTMField() {
    return Container(
      margin: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 0.0),
      child: InputUTM(
        point: LatLng(_current.lat, _current.lon),
        onChanged: (point) {
          _current = Point.now(point.latitude, point.longitude);
        },
        onEditingComplete: () {
          setState(() {});
          _mapController.animatedMove(
            LatLng(_current.lat, _current.lon),
            _mapController.zoom,
            this,
          );
        },
      ),
    );
  }

  FlutterMap _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
          zoom: 13,
          center: LatLng(_current.lat, _current.lon),
          onPositionChanged: _onPositionChanged,
          plugins: [
            POILayer(),
            ScaleBar(),
          ]),
      layers: [
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
        ),
        if (widget.incident != null)
          _buildPoiOptions({
            widget?.incident?.ipp: "IPP",
            widget?.incident?.meetup: "Oppmøte",
          }),
        ScalebarOption(
          lineColor: Colors.black54,
          lineWidth: 2,
          textStyle: TextStyle(color: Colors.black87, fontSize: 12),
          padding: EdgeInsets.only(left: 16, top: 16),
          alignment: Alignment.bottomLeft,
        ),
      ],
    );
  }

  POILayerOptions _buildPoiOptions(Map<Point, String> points) {
    final bloc = BlocProvider.of<IncidentBloc>(context);
    return POILayerOptions(
      List.from(
        points.entries.where((entry) => entry.key != null).map((entry) => POI(point: entry.key, name: entry.value)),
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

  Center _buildCenterMark() {
    return Center(
      child: SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: CrossPainter(color: Colors.red.withOpacity(0.6)),
          )),
    );
  }

  Widget _buildControls() {
    Size size = Size(42.0, 42.0);
    return Positioned(
      top: 172.0,
      right: 8.0,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              width: size.width,
              height: size.height,
              child: Container(
                child: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    _mapController.animatedMove(
                      _mapController.center,
                      _mapController.zoom + 1,
                      this,
                    );
                  },
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
            SizedBox(
              height: 4.0,
            ),
            SizedBox(
              width: size.width,
              height: size.height,
              child: Container(
                child: IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    _mapController.animatedMove(
                      _mapController.center,
                      _mapController.zoom,
                      this,
                    );
                  },
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
            SizedBox(
              height: 4.0,
            ),
            SizedBox(
              width: size.width,
              height: size.height,
              child: Container(
                child: IconButton(
                  color: _locationController.isLocated ? Colors.green : Colors.black,
                  icon: Icon(Icons.gps_fixed),
                  onPressed: () {
                    _locationController.goto();
                  },
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updatePoint(MapPosition point, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _current = Point.now(point.center.latitude, point.center.longitude);
      });
    }
  }

  void _onError(String message) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: SnackBarAction(
        label: "OK",
        onPressed: () {
          _scaffoldKey.currentState.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
        },
      ),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (hasGesture && _locationController.isLocated) {
      _locationController.goto();
    }
    _updatePoint(position, hasGesture);
  }

  void _showMessage(
    String message, {
    String action = "OK",
    VoidCallback onPressed,
    dynamic data,
  }) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: _buildAction(action, () {
        if (onPressed != null) onPressed();
        _scaffoldKey.currentState.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
      }),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  Widget _buildAction(String label, VoidCallback onPressed) {
    return SnackBarAction(
      label: label,
      onPressed: onPressed,
    );
  }
}
