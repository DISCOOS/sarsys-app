import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/map/map_search.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/widgets/input_coordinate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

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
  MapSearchField _searchField;
  IncidentMapController _mapController;

  StreamController<LatLng> _changes;

  @override
  void initState() {
    super.initState();
    _mapController = IncidentMapController();
    // TODO: Use device location as default location
    _changes = StreamController<LatLng>();
    _current = widget.point == null ? Point.now(59.5, 10.09) : widget.point;
    _searchField = MapSearchField(
      key: _searchFieldKey,
      offset: 106.0,
      withBorder: false,
      onError: _onError,
      mapController: _mapController,
      onMatch: (point) => setState(() => _current = Point.now(point.latitude, point.longitude)),
    );
  }

  @override
  void dispose() {
    _changes?.close();
    _mapController?.cancel();
    _changes = null;
    _mapController = null;
    super.dispose();
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
        ],
      ),
      resizeToAvoidBottomInset: false,
    );
  }

  Widget _buildInputFields() {
    final size = MediaQuery.of(context).size;
    final maxWidth = min(min(size.width, size.height), 480.0);
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
    return StreamBuilder<LatLng>(
        initialData: toLatLng(_current),
        stream: _changes.stream,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? Container(
                  margin: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 0.0),
                  child: InputUTM(
                    point: snapshot.data,
                    onChanged: (point) {
                      _mapController.animatedMove(point, _mapController.zoom, this);
                      _current = Point.now(point.latitude, point.longitude);
                    },
                  ),
                )
              : Container();
        });
  }

  Widget _buildMap() {
    return IncidentMap(
      incident: widget.incident,
      center: _mapController.ready ? _mapController.center : LatLng(_current.lat, _current.lon),
      mapController: _mapController,
      withRead: true,
      readLayers: true,
      withPOIs: true,
      withUnits: false,
      withScaleBar: true,
      withControls: true,
      withControlsZoom: true,
      withControlsLocateMe: true,
      withControlsOffset: 180,
      onPositionChanged: _onPositionChanged,
      onTap: (_) => _searchFieldKey.currentState.clear(),
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
    if (hasGesture) {
      _current = Point.now(position.center.latitude, position.center.longitude);
      _changes.add(position.center);
    }
  }
}
