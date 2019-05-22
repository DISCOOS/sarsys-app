import 'dart:ui';

import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong/latlong.dart';

class PointEditor extends StatefulWidget {
  final Point point;
  final String title;

  const PointEditor(this.point, this.title, {Key key}) : super(key: key);

  @override
  _PointEditorState createState() => _PointEditorState();

  static final utm = TransverseMercatorProjection.utm(32, false);

  static String toDD(Point point) {
    final f = new NumberFormat("###.000000");
    f.maximumFractionDigits = 6;
    return point == null ? "Velg" : "DD ${f.format(point.lat)} ${f.format(point.lon)}";
  }

  static String toUTM(Point point) {
    final f = new NumberFormat("0000000");
    f.maximumFractionDigits = 0;
    var src = ProjCoordinate.from2D(point.lon, point.lat);
    var dst = utm.project(src);
    return point == null ? "Velg" : "UTM 32V ${f.format(dst.x)} ${f.format(dst.y)}";
  }
}

class _PointEditorState extends State<PointEditor> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Point _current;
  bool _init = false;
  String currentBaseMap;
  MapController mapController;

  @override
  void initState() {
    super.initState();
    // TODO: Dont bother fixing this now, moving to BLoC/Streamcontroller later
    currentBaseMap = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
    mapController = MapController();
    // TODO: Use device location as default location
    _current = widget.point == null ? Point.now(59.5, 10.09) : widget.point;
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: LatLng(_current.lat, _current.lon),
              zoom: 13,
              onPositionChanged: (point, hasGesture) => _updatePoint(point, hasGesture),
            ),
            layers: [
              TileLayerOptions(
                urlTemplate: currentBaseMap,
                offlineMode: false,
                fromAssets: false,
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.all(8.0),
              padding: EdgeInsets.all(16.0),
              height: 104.0,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5)),
              child: Column(
                children: <Widget>[
                  if (_current != null) Text(PointEditor.toDD(_current)),
                  if (_current != null) Text(PointEditor.toUTM(_current)),
                ],
              ),
            ),
          ),
          Center(
            child: SizedBox(
                width: 56,
                height: 56,
                child: CustomPaint(
                  painter: CrossPainter(),
                )),
          ),
        ],
      ),
    );
  }

  void _updatePoint(MapPosition point, bool hasGesture) {
    _current = Point.now(point.center.latitude, point.center.longitude);
    if (_init) setState(() {});
    _init = true;
  }
}

class CrossPainter extends CustomPainter {
  Paint _paint;
  final _gap = 15.0;
  final _length = 40.0;

  CrossPainter() {
    _paint = Paint()
      ..color = Colors.red.withOpacity(0.4)
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
