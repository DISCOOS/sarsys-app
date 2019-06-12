import 'dart:io';

import 'package:SarSys/widgets/MapSearchField.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';

import 'package:SarSys/Services/LocationService.dart';
import 'package:SarSys/Widgets/AppDrawer.dart';
import 'package:SarSys/services/MaptileService.dart';

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => new MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  // TODO: move the baseMap to MapService
  String _currentBaseMap;
  bool _offlineBaseMap;
  MapController _mapController;
  LocationService _locationService = new LocationService();
  MaptileService _maptileService = new MaptileService();
  List<BaseMap> _baseMaps;
  MapSearchField _searchField;

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
      onError: _onError,
      prefixIcon: GestureDetector(
        child: Icon(Icons.menu),
        onTap: () => _scaffoldKey.currentState.openDrawer(),
      ),
    );
    initMaps();
  }

  void initMaps() async {
    _baseMaps = await _maptileService.fetchMaps();
  }

  void getPosition() async {
    Position location = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    // Move map to position - testing only on initState, should be triggered when user activates GPS.
    _mapController.move(new LatLng(location.latitude, location.longitude), _mapController.zoom);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(),
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _settingModalBottomSheet(context);
        },
        child: Icon(Icons.add),
        elevation: 2.0,
      ),
      body: _buildBody(),
//      bottomNavigationBar: _buildBottomAppBar(context),
      resizeToAvoidBottomInset: false,
    );
  }

  Stack _buildBody() {
    return Stack(
      children: [
        _buildMap(),
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

  FlutterMap _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: new LatLng(59.5, 10.09),
        zoom: 13,
        onTap: (_) => _clearSearchField(),
      ),
      layers: [
        new TileLayerOptions(
          urlTemplate: _currentBaseMap,
        ),
      ],
    );
  }

  BottomAppBar _buildBottomAppBar(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
//          IconButton(
//            icon: Icon(Icons.filter_list),
//            color: Colors.white,
//            onPressed: () {},
//          ),
          IconButton(
            icon: Icon(Icons.map),
            color: Colors.white,
            onPressed: () {
              _selectBaseMapBottomSheet(context);
            },
          ),
          Spacer(),
          Spacer(),
          IconButton(
            icon: Icon(Icons.gps_fixed),
            color: Colors.white,
            onPressed: () {
              getPosition();
            },
          ),
          IconButton(
            icon: Icon(Icons.add),
            color: Colors.white,
            onPressed: () {
              _mapController.move(_mapController.center, _mapController.zoom + 1);
            },
          ),
          IconButton(
            icon: Icon(Icons.remove),
            color: Colors.white,
            onPressed: () {
              _mapController.move(_mapController.center, _mapController.zoom - 1);
            },
          )
        ],
      ),
      shape: CircularNotchedRectangle(),
      color: Colors.grey[850],
    );
  }

  void _settingModalBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Container(
            child: new Wrap(
              children: <Widget>[
                new ListTile(
                    leading: new Icon(Icons.warning),
                    title: new Text('Spor'),
                    onTap: () {
                      Navigator.pop(context);
                    }),
                new ListTile(
                  leading: new Icon(Icons.golf_course),
                  title: new Text('Markering'),
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
        child: new BaseMapCard(map: map),
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

class BaseMapCard extends StatelessWidget {
  final BaseMap map;

  BaseMapCard({this.map});

  Image previewImage() {
    String basePath = "assets/mapspreview";
    // TODO: Check if file exists in filesystem before returning
    if (map.previewFile != null && !map.offline) {
      // Online maps preview image is distributed in assets
      // Should be moved to documents folder if list of online maps is a downloadable config
      return Image(image: AssetImage("$basePath/${map.previewFile}"));
    } else if (map.previewFile != null && map.offline) {
      // Offline maps must be read from SDCard
      return Image.file(new File(map.previewFile));
    } else {
      return Image(image: AssetImage("$basePath/missing.png"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      //clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.all(2.0),
      //elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: previewImage(),
                ),
              ),
              Text(
                map.description,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ]),
      ),
    );
  }
}
