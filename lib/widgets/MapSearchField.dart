import 'dart:collection';

import 'package:SarSys/utils/proj4d.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';

typedef ErrorCallback = void Function(String message);
typedef MatchCallback = void Function(LatLng point);

class MapSearchField extends StatefulWidget {
  final double zoom;
  final String hintText;
  final ErrorCallback onError;
  final MatchCallback onMatch;
  final VoidCallback onCleared;
  final MapController controller;

  final Widget prefixIcon;

  const MapSearchField({
    Key key,
    @required this.onError,
    @required this.controller,
    this.onMatch,
    this.onCleared,
    this.prefixIcon,
    this.zoom,
    this.hintText,
  }) : super(key: key);

  @override
  MapSearchFieldState createState() => MapSearchFieldState();
}

class MapSearchFieldState extends State<MapSearchField> {
  final _searchKey = GlobalKey();
  final _focusNode = FocusNode();
  final _controller = TextEditingController();

  LatLng _match;
  OverlayEntry _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => {
          setState(() {}),
        });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          focusNode: _focusNode,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintMaxLines: 1,
            hintText: widget.hintText ?? "Skriv inn posisjon eller adresse",
            contentPadding: EdgeInsets.all(16.0),
            prefixIcon: widget.prefixIcon,
            suffixIcon: _focusNode.hasFocus || _match != null
                ? GestureDetector(
                    child: Icon(Icons.close),
                    onTap: () => clear(),
                  )
                : Icon(Icons.search),
          ),
          controller: _controller,
          onSubmitted: (value) => _search(value),
          enableInteractiveSelection: false,
        ),
      ),
    );
  }

  /// Hide overlay with results if shown, clear content and unfocus textfield
  void clear() {
    setState(() {
      _match = null;
      _controller.clear();
      _focusNode?.unfocus();
      _hideResults();
      widget?.onCleared();
    });
  }

  void _hideResults() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showResults(List<Placemark> placemarks) {
    RenderBox renderBox = _searchKey.currentContext.findRenderObject();
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    _hideResults();

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
                children: placemarks
                    .map(
                      (placemark) => ListTile(
                            title: Text(placemark.name),
                            subtitle: Text(placemark.country),
                            onTap: () {
                              _hideResults();
                              _goto(placemark.position.latitude, placemark.position.longitude);
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
        Locale locale = Localizations.localeOf(context);
        var identifier = "${locale.languageCode}_${locale.countryCode}";
        var placemarks = await Geolocator().placemarkFromAddress(value, localeIdentifier: identifier);
//        var addresses = await Geocoder.local.findAddressesFromQuery(value);
        if (placemarks.length > 1) {
          _showResults(placemarks);
        } else {
          var first = placemarks.first;
          lat = first.position.latitude;
          lon = first.position.longitude;
        }
      } catch (e) {
        widget.onError('Addresse "$value" ikke funnet');
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
    setState(() {
      _match = LatLng(lat, lon);
      print("Goto: $_match");
      widget.controller.move(_match, widget.zoom ?? widget.controller.zoom);
      widget?.onMatch(_match);
    });
  }
}
