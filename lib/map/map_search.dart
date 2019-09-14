import 'dart:collection';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final IncidentMapController mapController;

  final Widget prefixIcon;

  final bool withRetired;

  const MapSearchField({
    Key key,
    @required this.onError,
    @required this.mapController,
    this.onMatch,
    this.onCleared,
    this.prefixIcon,
    this.zoom,
    this.hintText,
    this.withRetired = false,
  }) : super(key: key);

  @override
  MapSearchFieldState createState() => MapSearchFieldState();
}

class MapSearchFieldState extends State<MapSearchField> with TickerProviderStateMixin {
  final _searchKey = GlobalKey();
  final _focusNode = FocusNode();
  final _controller = TextEditingController();

  LatLng _match;
  OverlayEntry _overlayEntry;

  bool get hasFocus => _focusNode?.hasFocus ?? false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => {
        setState(() {}),
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _hideResults();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).iconTheme;
    return Container(
      margin: EdgeInsets.all(8.0),
      padding: EdgeInsets.all(0.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: widget.prefixIcon,
          ),
          Expanded(
            child: TextField(
              key: _searchKey,
              focusNode: _focusNode,
              autofocus: false,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintMaxLines: 1,
                hintText: widget.hintText ?? "Søk her",
                contentPadding: EdgeInsets.only(top: 16.0, bottom: 16.0),
              ),
              controller: _controller,
              onSubmitted: (value) => _search(context, value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _focusNode.hasFocus || _match != null || _overlayEntry != null
                ? GestureDetector(
                    child: Icon(Icons.close, color: theme.color),
                    onTap: () => clear(),
                  )
                : Icon(Icons.search, color: theme.color.withOpacity(0.4)),
          ),
        ],
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
      if (widget.onCleared != null) widget.onCleared();
    });
  }

  void _hideResults() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showResults(List<_SearchResult> results) async {
    final RenderBox renderBox = _searchKey.currentContext.findRenderObject();
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _hideResults();
    _focusNode.requestFocus();

    final choices = results
        .map((result) => result is _AddressLookup ? _buildListTileFromLookup(result) : _buildListTile(context, result))
        .toList();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 8.0,
        top: offset.dy + size.height + 5.0,
        width: MediaQuery.of(context).size.width - 16.0,
        height: MediaQuery.of(context).size.height - (offset.dy + size.height + 16.0),
        child: Material(
          elevation: 0.0,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: results.length,
              semanticChildCount: results.length,
              itemBuilder: (BuildContext context, int index) => choices[index],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(this._overlayEntry);
  }

  Widget _buildListTileFromLookup(_AddressLookup lookup) {
    return FutureBuilder<_SearchResult>(
      initialData: lookup,
      future: lookup.search,
      builder: (BuildContext context, AsyncSnapshot<_SearchResult> snapshot) {
        return _buildListTile(context, snapshot.hasData ? snapshot.data : lookup);
      },
    );
  }

  ListTile _buildListTile(BuildContext context, _SearchResult data) {
    final backgroundColor = Theme.of(context).canvasColor;
    return ListTile(
      leading: CircleAvatar(
        child: Icon(data.icon, size: 36.0),
        backgroundColor: backgroundColor,
      ),
      title: Text(data.title ?? ''),
      subtitle: data.address == null
          ? Text(data.position)
          : Text([data.address, data.position].where((test) => test != null).join("\n")),
      contentPadding:
          data.address == null ? EdgeInsets.only(left: 16.0, right: 16.0) : EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
      onTap: () {
        _goto(data.latitude, data.longitude);
      },
    );
  }

  void _search(BuildContext context, String value) {
    if (!_searchBlocs(context, value)) {
      _searchForLocation(value, context);
    }
  }

  void _searchForLocation(String value, BuildContext context) async {
    var row;
    var zone = -1, lat, lon;
    var isSouth = false;
    var isDefault = false;
    var matches = List<Match>();
    var ordinals = HashMap<String, Match>();

    value = value.trim();

    if (!kReleaseMode) print("Search: $value");

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
            if (!kReleaseMode) print('Found same axis label on both ordinals');
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
      if (!kReleaseMode) print("Assumed default order {NORTHING, EASTING} ");
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
          if (!kReleaseMode) print("Inferred axis '$axis' from ordinal: '${first.group(0)}'");
        }
      });
    }

    // Search for address?
    if (ordinals.length != 2) {
      try {
        var placemarks = await _fromAddress(value);
        if (placemarks.length > 0) {
          _showResults(placemarks
              .map((placemark) => _SearchResult(
                    icon: Icons.home,
                    title: "${placemark.thoroughfare} ${placemark.subThoroughfare}",
                    address: _AddressLookup.toAddress(placemark),
                    position: _AddressLookup.toPosition(placemark.position.latitude, placemark.position.longitude),
                    latitude: placemark.position.latitude,
                    longitude: placemark.position.longitude,
                  ))
              .toList());
        }
      } catch (e) {
        _hideResults();
        if (widget.onError != null) widget.onError('"$value" ikke funnet');
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
    } else {
      if (widget.onError != null) widget.onError('"$value" ikke funnet');
    }
  }

  Future<List<Placemark>> _fromAddress(String value) async {
    try {
      Locale locale = Localizations.localeOf(context);
      return await Geolocator().placemarkFromAddress(value, localeIdentifier: locale.toString());
    } on Exception {
      return [];
    }
  }

  bool _searchBlocs(BuildContext context, String value) {
    final results = <_AddressLookup>[];
    final match = RegExp("${_prepare(value)}");
    final units = BlocProvider.of<TrackingBloc>(context).getTrackedUnits;
    final tracks = BlocProvider.of<TrackingBloc>(context).tracks;
    final devices = BlocProvider.of<DeviceBloc>(context).devices;
    final incident = BlocProvider.of<IncidentBloc>(context).current;

    var found = incident != null;

    if (found) {
      // Search for matches in incident
      if (_prepare(incident.searchable).contains(match)) {
        var matches = [
          _AddressLookup(
            context: context,
            point: incident.ipp,
            title: "${incident.name} > IPP",
            icon: Icons.location_on,
          ),
          _AddressLookup(
            context: context,
            point: incident.meetup,
            title: "${incident.name} > Oppmøte",
            icon: Icons.location_on,
          ),
        ];
        var positions = matches.where((test) => _prepare(test).contains(match));
        if ((positions).isNotEmpty) {
          results.addAll(positions);
        } else {
          results.addAll(matches);
        }
      }

      // Search for matches in units
      results.addAll(
        units(exclude: widget.withRetired ? [] : [TrackingStatus.Closed])
            .values
            .where((unit) => widget.withRetired || unit.status != UnitStatus.Retired)
            .where((unit) =>
                // Search in unit
                _prepare(unit.searchable).contains(match) ||
                // Search in devices tracked with this unit
                tracks[unit.tracking].devices.any((id) => _prepare(devices[id]).contains(match)))
            .where((unit) => tracks[unit.tracking].location != null)
            .map((unit) => _AddressLookup(
                  context: context,
                  point: tracks[unit.tracking].location,
                  title: unit.name,
                  icon: Icons.group,
                )),
      );

      if (results.length > 0) {
        _showResults(results);
      } else {
        found = false;
      }
    }
    return found;
  }

  String _prepare(Object object) => "$object".replaceAll(RegExp(r'\s*'), '').toLowerCase();

  void _goto(lat, lon) {
    _match = LatLng(lat, lon);
    if (!kReleaseMode) print("Goto: $_match");
    widget.mapController.animatedMove(_match, widget.zoom ?? widget.mapController.zoom, this);
    if (widget.onMatch != null) widget.onMatch(_match);
    _controller.clear();
    _focusNode?.unfocus();
    _hideResults();
  }
}

class _SearchResult {
  final String title;
  final IconData icon;
  final String address;
  final String position;
  final double longitude;
  final double latitude;

  _SearchResult({
    this.title,
    this.icon,
    this.address,
    this.position,
    this.longitude,
    this.latitude,
  });

  @override
  String toString() {
    return '_SearchResult{title: $title, address: $address, position: $position, '
        'longitude: $longitude, latitude: $latitude}';
  }
}

class _AddressLookup extends _SearchResult {
  final locator = Geolocator();
  final BuildContext context;
  final Point point;

  _AddressLookup({
    @required this.context,
    @required this.point,
    @required String title,
    @required IconData icon,
  }) : super(
          title: title,
          icon: icon,
          position: toPosition(point.lat, point.lon),
          latitude: point.lat,
          longitude: point.lon,
        );

  Future<_SearchResult> get search => _lookup(context, point, title: title, icon: icon);

  Future<_SearchResult> _lookup(BuildContext context, Point point, {String title, IconData icon}) async {
    Placemark closest;
    var last = double.maxFinite;
    final Locale locale = Localizations.localeOf(context);

    final matches = await _fromCoordinates(context, locale, point);
    for (var placemark in matches) {
      if (closest == null) {
        closest = placemark;
        last = await locator.distanceBetween(
          closest.position.latitude,
          closest.position.longitude,
          point.lat,
          point.lon,
        );
      } else {
        var next = await locator.distanceBetween(
          closest.position.latitude,
          closest.position.longitude,
          placemark.position.latitude,
          placemark.position.longitude,
        );
        if (next < last) {
          closest = placemark;
          last = next;
        }
      }
    }

    return closest == null
        ? _SearchResult(
            icon: icon,
            title: title,
            position: toUTM(point),
            latitude: point.lat,
            longitude: point.lon,
          )
        : _SearchResult(
            icon: icon,
            title: "$title",
            address: toAddress(closest),
            position: toPosition(point.lat, point.lon, distance: last),
            latitude: point.lat,
            longitude: point.lon,
          );
  }

  Future<List<Placemark>> _fromCoordinates(BuildContext context, Locale locale, Point point) async {
    try {
      return await locator.placemarkFromCoordinates(point.lat, point.lon, localeIdentifier: locale.toString());
    } catch (e) {
      return [];
    }
  }

  static String toPosition(double lat, double lon, {double distance}) {
    final hasDistance = distance != null && distance != double.maxFinite && distance > 0;
    return "${toUTM(Point.now(lat, lon))}${hasDistance ? " (${distance.toStringAsFixed(0)} meter)" : ""}";
  }

  static String toAddress(Placemark placemark) {
    return [
      [
        placemark.postalCode,
        placemark.locality,
      ].where((test) => test != null && test.isNotEmpty).join(' '),
      placemark.administrativeArea,
      placemark.country,
    ].where((test) => test != null && test.isNotEmpty).join(", ").trim();
  }
}
