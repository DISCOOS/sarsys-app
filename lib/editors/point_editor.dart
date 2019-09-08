import 'dart:ui';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/map/coordinate_panel.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/map/layers/icon_layer.dart';
import 'package:SarSys/map/layers/scalebar.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/map/location_controller.dart';
import 'package:SarSys/map/map_search.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

class PointEditor extends StatefulWidget {
  final Point point;
  final String title;
  final Incident incident;

  const PointEditor(this.point, this.title, {Key key, this.incident}) : super(key: key);

  @override
  _PointEditorState createState() => _PointEditorState();
}

class _PointEditorState extends State<PointEditor> with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  bool _init;
  Point _current;
  String _currentBaseMap;
  MapSearchField _searchField;
  IncidentMapController _mapController;
  LocationController _locationController;

  @override
  void initState() {
    super.initState();
    // TODO: Dont bother fixing this now, moving to BLoC/Streamcontroller later
    _currentBaseMap = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
    _mapController = IncidentMapController();
    // TODO: Use device location as default location
    _init = false;
    _current = widget.point == null ? Point.now(59.5, 10.09) : widget.point;
    _searchField = MapSearchField(
      key: _searchFieldKey,
      mapController: _mapController,
      onError: _onError,
    );
    _locationController = LocationController(
        appConfigBloc: BlocProvider.of<AppConfigBloc>(context),
        mapController: _mapController,
        tickerProvider: this,
        onMessage: _showMessage,
        onPrompt: _prompt,
        onLocationChanged: (_) => setState(() {}));
    _locationController.init();
  }

  @override
  void dispose() {
    super.dispose();
    _locationController.dispose();
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
      body: GestureDetector(
        child: Stack(
          children: [
            _buildMap(),
            _buildCenterMark(),
            _buildSearchField(),
            _buildControls(),
            _buildCoordsPanel(),
          ],
        ),
        onTapDown: (_) => _clearSearchField(),
      ),
      resizeToAvoidBottomInset: false,
    );
  }

  FlutterMap _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
          center: LatLng(_current.lat, _current.lon),
          zoom: 13,
          onPositionChanged: _onPositionChanged,
          onTap: (_) => _clearSearchField(),
          plugins: [
            IconLayer(),
            ScaleBar(),
          ]),
      layers: [
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
        ),
        if (widget.incident != null)
          _buildPoiOptions([
            widget?.incident?.ipp,
            widget?.incident?.meetup,
          ]),
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

  Align _buildSearchField() {
    return Align(
      alignment: Alignment.topCenter,
      child: _searchField,
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
              child: Container(
                child: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    _mapController.animatedMove(_mapController.center, _mapController.zoom + 1, this);
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
                    _mapController.animatedMove(_mapController.center, _mapController.zoom - 1, this);
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

  Align _buildCoordsPanel() {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(top: 220.0),
        child: CoordinatePanel(point: _current),
      ),
    );
  }

  void _updatePoint(MapPosition point, bool hasGesture) {
    _current = Point.now(point.center.latitude, point.center.longitude);
    if (_init) setState(() {});
    _init = true;
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

  void _clearSearchField() {
    _searchFieldKey?.currentState?.clear();
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (hasGesture && _locationController.isLocated) {
      _locationController.goto();
    }
    _updatePoint(position, hasGesture);
  }

  void _showMessage(String message, {String action = "OK", VoidCallback onPressed}) {
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

  Future<bool> _prompt(String title, String message) async {
    // flutter defined function
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text(title),
          content: new Text(message),
          actions: <Widget>[
            new FlatButton(
              child: new Text("CANCEL"),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            new FlatButton(
              child: new Text("FORTSETT"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }
}
