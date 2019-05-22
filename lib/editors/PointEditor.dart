import 'dart:collection';
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
  final _controller = TextEditingController();

  bool _init;
  Point _current;
  String _currentBaseMap;
  MapController _mapController;

  @override
  void initState() {
    super.initState();
    // TODO: Dont bother fixing this now, moving to BLoC/Streamcontroller later
    _currentBaseMap = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
    _mapController = MapController();
    // TODO: Use device location as default location
    _init = false;
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
          _buildMap(),
          _buildCenterMark(),
          _buildSearchField(),
          _buildCoordsPanel(),
        ],
      ),
    );
  }

  FlutterMap _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: LatLng(_current.lat, _current.lon),
        zoom: 13,
        onPositionChanged: (point, hasGesture) => _updatePoint(point, hasGesture),
      ),
      layers: [
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
          offlineMode: false,
          fromAssets: false,
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
        child: Container(
          margin: EdgeInsets.all(8.0),
          padding: EdgeInsets.all(0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: SizedBox(
            child: TextField(
              decoration: InputDecoration(
                border: InputBorder.none,
                hintMaxLines: 1,
                hintText: "Skriv inn posisjon eller adresse",
                contentPadding: EdgeInsets.all(16.0),
                suffixIcon: Icon(Icons.search),
              ),
              controller: _controller,
              enableInteractiveSelection: true,
              onSubmitted: (value) => _search(value),
            ),
          ),
        ));
  }

  Align _buildCoordsPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.all(8.0),
        padding: EdgeInsets.all(16.0),
        height: 72.0,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.6)),
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

  // TODO: Move coordinate format parsing to CoordinateFormat class.
  static const EASTING = "EW";
  static const NORTHTING = "NS";
  final RegExp utm = RegExp(
    r"([1-6]\d)([C-X]+)\s*([NSWE]?\d{1,7}[.]?\d*[NSWE]?\s+[NSWE]?\d{1,7}[.]?\d*[NSWE]?)",
    caseSensitive: false,
  );
  final RegExp ordinate = RegExp(
    r"([NSWE]?)([-]?\d+[.]?\d?)([NSWE]?)",
    caseSensitive: false,
  );

  void _search(String value) {
    print("Search: $value");
    var row;
    var zone = -1;
    var isSouth = false;
    var isDefault = false;
    var matches = List<Match>();
    var ordinals = HashMap<String, Match>();

    // Is utm?
    var match = utm.firstMatch(value);
    if (match != null) {
      zone = int.parse(match.group(1));
      row = match.group(2).toUpperCase();
      isSouth = 'N'.compareTo(row) > 0;
      value = match.group(3);
      print("Found UTM coordinate in grid '$zone$row'");
    }

    // Attempt to map each match to an axis
    value.split(" ").forEach((value) {
      var match = ordinate.firstMatch(value);
      if (match != null) {
        matches.add(match);
        var axis = _axis(_labels(match));
        // Preserve order
        if (axis != null) {
          if (ordinals.containsKey(axis)) {
            print('Found same axis label on both ordinals');
            ordinals.clear();
          } else {
            ordinals[axis] = match;
          }
        }
      }
    });

    // No axis labels found?
    if (ordinals.length == 0 && matches.length == 2) {
      // Assume default order {lat, lon} is entered
      isDefault = true;
      ordinals['lat'] = matches.first;
      ordinals['lon'] = matches.last;
      print("Assumed default order {'lat', 'lon'} ");
    } else if (ordinals.length == 1) {
      // One axis label found, try to infer the other
      matches.forEach((match) {
        if (!ordinals.containsValue(match)) {
          // Infer missing axis
          var first = ordinals.values.first;
          var axis = ('lat' == ordinals.keys.first ? 'lon' : 'lat');
          ordinals[axis] = match;
          print("Inferred axis '$axis' from ordinal: '${first.group(0)}'");
        }
      });
    }

    if (ordinals.length == 2) {
      double lat = double.tryParse(_trim(ordinals['lat'].group(2)));
      double lon = double.tryParse(_trim(ordinals['lon'].group(2)));
      if (zone > 0) {
        var proj = TransverseMercatorProjection.utm(zone, isSouth);
        var dst = proj.inverse(isDefault ? ProjCoordinate.from2D(lat, lon) : ProjCoordinate.from2D(lon, lat));
        lon = dst.x;
        lat = dst.y;
      }
      if (lat != null && lon != null) {
        var point = LatLng(lat, lon);
        print("Move to: $point");
        _mapController.move(point, _mapController.zoom);
      }
    }
  }

  String _trim(String value) {
    return value.replaceFirst(RegExp(r'^0+'), '');
  }

  String _axis(List<String> labels) {
    var axis;
    if (_isNorthing(labels)) {
      axis = 'lat';
    } else if (_isEasting(labels)) {
      axis = 'lon';
    }
    return axis;
  }

  List<String> _labels(Match match) {
    var values = match.groups([1, 3]).toSet().toList();
    values.retainWhere((test) => test.isNotEmpty);
    return values;
  }

  bool _isEasting(List<String> values) {
    var found = values.where((test) => test.isNotEmpty && EASTING.contains(test));
    return found.isNotEmpty;
  }

  bool _isNorthing(List<String> values) {
    var found = values.where((test) => test.isNotEmpty && NORTHTING.contains(test));
    return found.isNotEmpty;
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
