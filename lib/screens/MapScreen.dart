import 'package:flutter/material.dart';
import '../Widgets/AppDrawer.dart';
import '../Widgets/SampleMap.dart';
import '../Services/LocationService.dart';
import 'package:flutter_map/flutter_map.dart';

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => new MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  // TODO: move the baseMap to MapService
  String currentBaseMap;
  bool offlineBaseMap;
  double mapZoom = 13;
  MapController mapController;
  LocationService locationService = new LocationService();

  @override
  void initState() {
    super.initState();
    currentBaseMap =
        "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
    offlineBaseMap = false;
    mapController = MapController();
    //getPosition();
  }

  void getPosition () async {
    LocationReport location = await locationService.getLocation();
    // Move map to position - testing only on initState, should be triggered when user activates GPS.
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
                _selecBaseMapBottomSheet(context);
              },
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.add),
              color: Colors.white,
              onPressed: () {
                setState(() {
                  mapZoom = mapZoom +1;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.remove),
              color: Colors.white,
              onPressed: () {
                setState(() {
                  mapZoom = mapZoom -1;
                });
              },
            )
          ],
        ),
        shape: CircularNotchedRectangle(),
        color: Colors.grey[850],
      ),
      body: Stack(children: [
        IncidentMap(
          url: currentBaseMap,
          offline: offlineBaseMap,
          zoom: mapZoom,
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

  // TODO: Quick demo - make widget that iterates over maps from MaptileService
  // TODO: Change from simple list to card showing map name, offline icon, sample image etc. (IRMA)
  void _selecBaseMapBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Container(
            child: new Wrap(
              children: <Widget>[
                new ListTile(
                    leading: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.signal_wifi_4_bar),
                    ]),
                    title: new Text('Topografisk'),
                    onTap: () {
                      setState(() {
                        currentBaseMap =
                            "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";
                        offlineBaseMap = false;
                      });
                      Navigator.pop(context);
                    }),
                new ListTile(
                    leading: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.signal_wifi_4_bar),
                    ]),
                    title: new Text('Toporaster'),
                    onTap: () {
                      setState(() {
                        currentBaseMap =
                            "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=toporaster3&zoom={z}&x={x}&y={y}";
                        offlineBaseMap = false;
                      });
                      Navigator.pop(context);
                    }),
                new ListTile(
                    leading: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.signal_wifi_4_bar),
                    ]),
                    title: new Text('Flyfoto'),
                    onTap: () {
                      setState(() {
                        currentBaseMap =
                        "http://maptiles2.finncdn.no/tileService/1.0.3/norortho/{z}/{x}/{y}.png";
                        offlineBaseMap = false;
                      });
                      Navigator.pop(context);
                    }),
                new ListTile(
                    leading: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.signal_wifi_off),
                    ]),
                    title: new Text('Toporaster (Norge 1:50000'),
                    onTap: () {
                      setState(() {
                        currentBaseMap =
                        "/storage/0123-4567/Maps/toporaster3/{z}/{x}/{y}.png";
                        offlineBaseMap = true;
                      });
                      Navigator.pop(context);
                    }),
              ],
            ),
          );
        });
  }
}
