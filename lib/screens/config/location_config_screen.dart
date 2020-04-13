import 'dart:io';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/services/location_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

class LocationConfigScreen extends StatefulWidget {
  @override
  _LocationConfigScreenState createState() => _LocationConfigScreenState();
}

class _LocationConfigScreenState extends State<LocationConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _displacement = TextEditingController();
  final _interval = TextEditingController();

  AppConfigBloc _bloc;
  LocationService _locationService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = BlocProvider.of<AppConfigBloc>(context);
    _interval.text = "${_bloc.config.locationFastestInterval ~/ 1000}";
    _displacement.text = "${_bloc.config.locationSmallestDisplacement}";
    _locationService = LocationService(_bloc);
  }

  @override
  void dispose() {
    _interval.dispose();
    _displacement.dispose();
    super.dispose();
  }

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Posisjon og sporing"),
        automaticallyImplyLeading: true,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListView(
              shrinkWrap: true,
              children: <Widget>[
                _buildLocationAccuracyField(),
                _buildLocationFastestIntervalField(),
                _buildLocationSmallestDisplacementField(),
              ],
            ),
            Divider(),
            ListView.separated(
              shrinkWrap: true,
              itemCount: _locationService.events,
              itemBuilder: (BuildContext context, int index) {
                final LocationEvent event = _locationService[index];
                final duration =
                    index > 0 ? _locationService[index - 1].timestamp.difference(event.timestamp).inSeconds : 0;
                return ListTile(
                  title: Text('${event.timestamp.toIso8601String()}: ${event.runtimeType}: $duration s'),
                  subtitle: Text('$event'),
                );
              },
              separatorBuilder: (BuildContext context, int index) => Divider(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationAccuracyField() {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: ListTile(
              title: Text("Lokasjonsnøyaktighet"),
              subtitle: Text("Høy nøyaktighet bruker mer batteri"),
            ),
          ),
          Flexible(
            child: DropdownButton<LocationAccuracy>(
              isExpanded: true,
              items: _toOsSpecific(LocationAccuracy.values)
                  .map((value) => DropdownMenuItem<LocationAccuracy>(
                        value: value,
                        child: Text("${LocationService.toAccuracyName(value)}", textAlign: TextAlign.center),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _bloc.update(locationAccuracy: enumName(value))),
              value: _bloc.config?.toLocationAccuracy(),
            ),
          ),
        ],
      ),
    );
  }

  Padding _buildLocationSmallestDisplacementField() {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: ListTile(
              title: Text("Minste avstand"),
              subtitle: Text("Angi avstand mellom 0 til 99 meter"),
            ),
          ),
          Flexible(
            child: TextField(
              maxLength: 2,
              controller: _displacement,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                WhitelistingTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(filled: true, counterText: ""),
              onChanged: (value) {
                _bloc.update(locationSmallestDisplacement: int.parse(value ?? 0));
              },
            ),
          ),
        ],
      ),
    );
  }

  Padding _buildLocationFastestIntervalField() {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: ListTile(
              title: Text("Minste tidsinterval"),
              subtitle: Text("Angi tid mellom 0 og 99 sekunder"),
            ),
          ),
          Flexible(
            child: TextField(
              maxLength: 2,
              controller: _interval,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                WhitelistingTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(filled: true, counterText: ""),
              onChanged: (value) {
                _bloc.update(locationFastestInterval: int.parse(value ?? 0) * 1000);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<LocationAccuracy> _toOsSpecific(List<LocationAccuracy> values) {
    if (Platform.isIOS == false) {
      values = values.toList()..remove(LocationAccuracy.best)..remove(LocationAccuracy.bestForNavigation);
    }
    return values;
  }
}
