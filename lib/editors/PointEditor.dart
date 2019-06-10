import 'dart:collection';
import 'dart:ui';

import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/proj4d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:geocoder/geocoder.dart';

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
  final _searchKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();

  bool _init;
  Point _current;
  String _currentBaseMap;
  OverlayEntry _overlayEntry;
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
      body: GestureDetector(
        child: Stack(
          children: [
            _buildMap(),
            _buildCenterMark(),
            _buildSearchField(),
            _buildCoordsPanel(),
          ],
        ),
        onTapDown: (_) => _hideSearchResults(),
      ),
    );
  }

  FlutterMap _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
          center: LatLng(_current.lat, _current.lon),
          zoom: 13,
          onPositionChanged: (point, hasGesture, isUserGesture) => _updatePoint(point, hasGesture),
          onTap: (_) => _hideSearchResults()),
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
              key: _searchKey,
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

  void _showResults(List<Address> addresses) {
    RenderBox renderBox = _searchKey.currentContext.findRenderObject();
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    _hideSearchResults();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 5.0,
            width: size.width,
            child: Material(
              elevation: 4.0,
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: addresses
                    .map(
                      (address) => ListTile(
                            title: Text(address.featureName),
                            subtitle: Text(address.addressLine),
                            onTap: () {
                              _hideSearchResults();
                              _goto(address.coordinates.latitude, address.coordinates.longitude);
                            },
                          ),
                    )
                    .toList(),
              ),
            ),
          ),
    );
    Overlay.of(context).insert(this._overlayEntry);
  }

  void _hideSearchResults() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future _search(String value) async {
    print("Search: $value");
    var row;
    var zone = -1, lat, lon;
    var isSouth = false;
    var isDefault = false;
    var matches = List<Match>();
    var ordinals = HashMap<String, Match>();

    value = value.trim();

    // Is utm?
    var match = CoordinateFormat.utm.firstMatch(value);
    if (match != null) {
      zone = int.parse(match.group(1));
      row = match.group(2).toUpperCase();
      isSouth = 'N'.compareTo(row) > 0;
      value = match.group(3);
      print("Found UTM coordinate in grid '$zone$row'");
    }

    // Attempt to map each match to an axis
    value.split(" ").forEach((value) {
      var match = CoordinateFormat.ordinate.firstMatch(value);
      if (match != null) {
        matches.add(match);
        var axis = CoordinateFormat.axis(CoordinateFormat.labels(match));
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
      ordinals[CoordinateFormat.NORTHTING] = matches.first;
      ordinals[CoordinateFormat.EASTING] = matches.last;
      print("Assumed default order {NORTHING, EASTING} ");
    } else if (ordinals.length == 1) {
      // One axis label found, try to infer the other
      matches.forEach((match) {
        if (!ordinals.containsValue(match)) {
          // Infer missing axis
          var first = ordinals.values.first;
          var axis = (CoordinateFormat.NORTHTING == ordinals.keys.first
              ? CoordinateFormat.EASTING
              : CoordinateFormat.NORTHTING);
          ordinals[axis] = match;
          print("Inferred axis '$axis' from ordinal: '${first.group(0)}'");
        }
      });
    }

    // Search for address?
    if (ordinals.length != 2) {
      try {
        var addresses = await Geocoder.local.findAddressesFromQuery(value);
        if (addresses.length > 1) {
          _showResults(addresses);
        } else {
          var first = addresses.first;
          lat = first.coordinates.latitude;
          lon = first.coordinates.longitude;
        }
      } catch (e) {
        final snackbar = SnackBar(
          duration: Duration(seconds: 1),
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Addresse ikke funnet'),
          ),
        );
        _scaffoldKey.currentState.showSnackBar(snackbar);
      }
    } else {
      lat = double.tryParse(CoordinateFormat.trim(ordinals[CoordinateFormat.NORTHTING].group(2)));
      lon = double.tryParse(CoordinateFormat.trim(ordinals[CoordinateFormat.EASTING].group(2)));
      if (zone > 0) {
        var proj = TransverseMercatorProjection.utm(zone, isSouth);
        var dst = proj.inverse(isDefault ? ProjCoordinate.from2D(lat, lon) : ProjCoordinate.from2D(lon, lat));
        lon = dst.x;
        lat = dst.y;
      }
    }
    if (lat != null && lon != null) {
      _goto(lat, lon);
    }
  }

  void _goto(lat, lon) {
    var point = LatLng(lat, lon);
    print("Goto: $point");
    _mapController.move(point, _mapController.zoom);
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
