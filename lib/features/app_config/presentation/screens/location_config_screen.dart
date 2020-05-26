import 'dart:io';

import 'package:SarSys/features/app_config/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/services/location_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:geolocator/geolocator.dart';

class LocationConfigScreen extends StatefulWidget {
  @override
  _LocationConfigScreenState createState() => _LocationConfigScreenState();
}

class _LocationConfigScreenState extends State<LocationConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _displacement = TextEditingController();
  final _interval = TextEditingController();

  LocationService _locationService;
  AppConfigBloc get bloc => context.bloc<AppConfigBloc>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _interval.text = "${bloc.config.locationFastestInterval ~/ 1000}";
    _displacement.text = "${bloc.config.locationSmallestDisplacement}";
    _locationService = LocationService(bloc);
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
              physics: ClampingScrollPhysics(),
              children: <Widget>[
                _buildLocationAccuracyField(),
                _buildLocationFastestIntervalField(),
                _buildLocationSmallestDisplacementField(),
              ],
            ),
            Divider(),
            ListTile(
              title: Text(
                "Posisjonstjeneste",
                style: Theme.of(context).textTheme.subtitle2.copyWith(fontWeight: FontWeight.bold),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.system_update),
                    tooltip: "Konfigurer posisjonstjenesten på nytt",
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final answer = await prompt(
                        context,
                        "Bekreftelse",
                        "Dette vil konfigurere posisjonstjenesten på nytt, vil du forsette?",
                      );
                      if (answer) {
                        await LocationService(bloc).configure(force: true);
                        setState(() {});
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.my_location),
                    tooltip: "Be om min posisjon",
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      await LocationService(bloc).update();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    tooltip: "Send posisjonslogg til epostmottaker",
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final Email email = Email(
                        body: 'Posisjonstjeneste log:\n\n${_locationService.events.map(
                              (event) => '${event.runtimeType}\n$event',
                            ).join('\n\n')}',
                        subject: 'Posisjonstjeneste - log',
                        recipients: ['support@discoos.org'],
                      );
                      await FlutterEmailSender.send(email);
                    },
                  ),
                ],
              ),
            ),
            StreamBuilder<LocationEvent>(
                stream: _locationService.onChanged,
                builder: (context, snapshot) {
                  final now = DateTime.now();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: ClampingScrollPhysics(),
                    itemCount: _locationService.events.length,
                    itemBuilder: (BuildContext context, int index) {
                      final LocationEvent event = _locationService[index];
                      final duration = now.difference(_locationService[index].timestamp);
                      return ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('${event.runtimeType}', style: TextStyle(fontWeight: FontWeight.w600)),
                            Chip(label: Text('${formatDuration(duration, withMillis: true)}')),
                          ],
                        ),
                        subtitle: Text('$event'),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) => Divider(),
                  );
                }),
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
              title: Text("Nøyaktighet"),
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
              onChanged: (value) async {
                await bloc.updateWith(
                  locationAccuracy: enumName(value),
                );
                setState(() {});
              },
              value: bloc.config?.toLocationAccuracy(),
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
                bloc.updateWith(locationSmallestDisplacement: int.parse(value ?? 0));
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
                bloc.updateWith(locationFastestInterval: int.parse(value ?? 0) * 1000);
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
