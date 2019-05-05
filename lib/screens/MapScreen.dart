import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong/latlong.dart';

import '../Services/LocationService.dart';
import '../Widgets/AppDrawer.dart';
import '../services/MaptileService.dart';

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => new MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  // TODO: move the baseMap to MapService
  String currentBaseMap;
  bool offlineBaseMap;
  MapController mapController;
  LocationService locationService = new LocationService();
  MaptileService maptileService = new MaptileService();
  List<BaseMap> baseMaps;

  @override
  void initState() {
    super.initState();
    // TODO: Dont bother fixing this now, moving to BLoC/Streamcontroller later
    currentBaseMap = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
    offlineBaseMap = false;
    mapController = MapController();
    initMaps();
  }

  void initMaps() async {
    baseMaps = await maptileService.fetchMaps();
  }

  void getPosition() async {
    Position location = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    // Move map to position - testing only on initState, should be triggered when user activates GPS.
    mapController.move(new LatLng(location.latitude, location.longitude), mapController.zoom);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      drawer: AppDrawer(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _settingModalBottomSheet(context);
        },
        child: Icon(Icons.add),
        elevation: 2.0,
      ),
      bottomNavigationBar: BottomAppBar(
        // TODO: Move to stack to fix map behind navbar
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.sort),
              color: Colors.white,
              onPressed: () {},
            ),
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
                mapController.move(mapController.center, mapController.zoom + 1);
              },
            ),
            IconButton(
              icon: Icon(Icons.remove),
              color: Colors.white,
              onPressed: () {
                mapController.move(mapController.center, mapController.zoom - 1);
              },
            )
          ],
        ),
        shape: CircularNotchedRectangle(),
        color: Colors.grey[850],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            center: new LatLng(59.5, 10.09),
            zoom: 13,
          ),
          layers: [
            new TileLayerOptions(
              urlTemplate: currentBaseMap,
              offlineMode: false,
              fromAssets: false,
            ),
          ],
        ),
        Positioned(
          top: 0.0,
          left: 0.0,
          right: 0.0,
          child: Opacity(
            opacity: 0.4,
            child: AppBar(
              title: new Text(""),
              actions: <Widget>[
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {},
                ),
              ],
              //toolbarOpacity: 0.5,
              //bottomOpacity: 0.5,
            ),
          ),
        )
      ]),
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

  List<Widget> mapBottomSheetCards() {
    List<Widget> _mapCards = [];

    for (BaseMap map in baseMaps) {
      _mapCards.add(GestureDetector(
        child: new BaseMapCard(map: map),
        onTap: () {
          setState(() {
            currentBaseMap = map.url;
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
            child: GridView.count(
              crossAxisCount: 2,
              children: mapBottomSheetCards(),
            ),
          );
        });
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
              ClipRRect(borderRadius: new BorderRadius.circular(8.0), child: previewImage()),
              Text(map.description)
            ]),
      ),
    );
  }
}
