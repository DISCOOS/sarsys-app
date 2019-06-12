import 'dart:ui';

import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:SarSys/widgets/MapSearchField.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

class PointEditor extends StatefulWidget {
  final Point point;
  final String title;

  const PointEditor(this.point, this.title, {Key key}) : super(key: key);

  @override
  _PointEditorState createState() => _PointEditorState();

  static String toDD(Point point) {
    return CoordinateFormat.toDD(ProjCoordinate.from2D(point.lon, point.lat));
  }

  /// TODO: Make UTM zone and northing configurable
  static final utmProj = TransverseMercatorProjection.utm(32, false);
  static String toUTM(Point point) {
    if (point == null) return "Velg";
    var src = ProjCoordinate.from2D(point.lon, point.lat);
    var dst = utmProj.project(src);
    return CoordinateFormat.toUTM(dst);
  }
}

class _PointEditorState extends State<PointEditor> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  bool _init;
  Point _current;
  String _currentBaseMap;
  MapController _mapController;
  MapSearchField _searchField;

  @override
  void initState() {
    super.initState();
    // TODO: Dont bother fixing this now, moving to BLoC/Streamcontroller later
    _currentBaseMap = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
    _mapController = MapController();
    // TODO: Use device location as default location
    _init = false;
    _current = widget.point == null ? Point.now(59.5, 10.09) : widget.point;
    _searchField = MapSearchField(
      key: _searchFieldKey,
      controller: _mapController,
      onError: _onError,
    );
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
        onPositionChanged: (point, hasGesture, isUserGesture) => _updatePoint(point, hasGesture),
        onTap: (_) => _clearSearchField(),
      ),
      layers: [
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
        ),
      ],
    );
  }

  Center _buildCenterMark() {
    return Center(
      child: SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: CrossPainter(),
          )),
    );
  }

  Align _buildSearchField() {
    return Align(
      alignment: Alignment.topCenter,
      child: _searchField,
    );
  }

  Align _buildCoordsPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.all(8.0),
        padding: EdgeInsets.all(16.0),
        height: 72.0,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(8.0)),
        child: Column(
          children: <Widget>[
            if (_current != null) Text(PointEditor.toDD(_current)),
            if (_current != null) Text(PointEditor.toUTM(_current)),
          ],
        ),
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
      duration: Duration(seconds: 1),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  void _clearSearchField() {
    _searchFieldKey?.currentState?.clear();
  }
}

class CrossPainter extends CustomPainter {
  Paint _paint;
  final _gap = 15.0;
  final _length = 40.0;

  CrossPainter() {
    _paint = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.width / 2);
    canvas.drawCircle(center, 2.0, _paint);
    canvas.drawLine(center.translate(-_gap, 0), center.translate(-_length, 0), _paint);
    canvas.drawLine(center.translate(_gap, 0), center.translate(_length, 0), _paint);
    canvas.drawLine(center.translate(0, _gap), center.translate(0, _length), _paint);
    canvas.drawLine(center.translate(0, -_gap), center.translate(0, -_length), _paint);
//
//    canvas.drawLine(Offset(size.width, 0.0), Offset(0.0, size.height), _paint);
  }

  @override
  bool shouldRepaint(CrossPainter oldDelegate) {
    return false;
  }
}
