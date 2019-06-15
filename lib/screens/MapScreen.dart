import 'dart:async';

import 'package:SarSys/plugins/MyLocation.dart';
import 'package:SarSys/widgets/BaseMapCard.dart';
import 'package:SarSys/widgets/CrossPainter.dart';
import 'package:SarSys/widgets/LocationController.dart';
import 'package:SarSys/widgets/MapSearchField.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

import 'package:SarSys/Widgets/AppDrawer.dart';
import 'package:SarSys/services/MaptileService.dart';

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  // TODO: move the baseMap to MapService
  String _currentBaseMap;
  bool _offlineBaseMap;
  MapController _mapController;
  MaptileService _maptileService = MaptileService();
  List<BaseMap> _baseMaps;
  LatLng _match;
  MapSearchField _searchField;
  LocationController _locationController;

  @override
  void initState() {
    super.initState();
    // TODO: Dont bother fixing this now, moving to BLoC/Streamcontroller later
    _currentBaseMap = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
    _offlineBaseMap = false;
    _mapController = MapController();
    _searchField = MapSearchField(
      key: _searchFieldKey,
      controller: _mapController,
      zoom: 18,
      onError: _showMessage,
      onMatch: _onSearchMatch,
      onCleared: _onSearchCleared,
      prefixIcon: GestureDetector(
        child: Icon(Icons.menu),
        onTap: () => _scaffoldKey.currentState.openDrawer(),
      ),
    );
    _locationController = LocationController(
        mapController: _mapController,
        onMessage: _showMessage,
        onPrompt: _prompt,
        onLocationChanged: (_) => setState(() {}));
    initMaps();
  }

  void initMaps() async {
    _baseMaps = await _maptileService.fetchMaps();
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
      drawer: AppDrawer(),
      extendBody: true,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _settingModalBottomSheet(context);
        },
        child: Icon(Icons.add),
        elevation: 2.0,
      ),
      body: _buildBody(),
      resizeToAvoidBottomInset: false,
    );
  }

  Stack _buildBody() {
    return Stack(
      children: [
        _buildMap(),
        _buildControls(),
        _buildSearchBar(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: _searchField,
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
              child: Container(
                child: IconButton(
                  icon: Icon(Icons.filter_list),
                  onPressed: () {},
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
                  icon: Icon(Icons.map),
                  onPressed: () {
                    _selectBaseMapBottomSheet(context);
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
                  icon: Icon(Icons.add),
                  onPressed: () {
                    _mapController.move(_mapController.center, _mapController.zoom + 1);
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
                    _mapController.move(_mapController.center, _mapController.zoom - 1);
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
                  color: _locationController.isTracking ? Colors.green : Colors.black,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  FlutterMap _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
          center: LatLng(59.5, 10.09),
          zoom: 13,
          onTap: _onTap,
          onPositionChanged: _onPositionChanged,
          plugins: [
            MyLocation(),
          ]),
      layers: [
        TileLayerOptions(
          urlTemplate: _currentBaseMap,
        ),
        if (_match != null) _buildMarker(_match),
        if (_locationController.isReady) _locationController.options,
      ],
    );
  }

  void _onTap(LatLng point) {
    if (_match == null) _clearSearchField();
  }

  void _onPositionChanged(MapPosition position, bool hasGesture, bool isUserGesture) {
    if (isUserGesture && _locationController.isTracking) {
      _locationController.toggle();
    }
  }

  MarkerLayerOptions _buildMarker(LatLng point) {
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

  void _settingModalBottomSheet(context) {
    final style = Theme.of(context).textTheme.title;
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Container(
            padding: EdgeInsets.only(bottom: 56.0),
            child: Wrap(
              children: <Widget>[
                ListTile(title: Text("Opprett", style: style)),
                Divider(),
                ListTile(
                    leading: Icon(Icons.timeline),
                    title: Text('Spor', style: style),
                    onTap: () {
                      Navigator.pop(context);
                    }),
                ListTile(
                  leading: Icon(Icons.add_location),
                  title: Text('Markering', style: style),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
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

  // TODO: Quick demo - make widget that iterates over maps from MaptileService
  // TODO: Change from simple list to card showing map name, offline icon, sample image etc. (IRMA)
  void _selectBaseMapBottomSheet(context) {
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

  void _clearSearchField() {
    _searchFieldKey?.currentState?.clear();
  }

  void _onSearchMatch(LatLng point) {
    setState(() {
      _match = point;
    });
  }

  void _onSearchCleared() {
    setState(() {
      _match = null;
    });
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
