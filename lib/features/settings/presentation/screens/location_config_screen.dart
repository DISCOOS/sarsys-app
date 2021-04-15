import 'package:SarSys/features/activity/presentation/blocs/activity_bloc.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/settings/presentation/screens/debug_location_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationConfigScreen extends StatefulWidget {
  @override
  _LocationConfigScreenState createState() => _LocationConfigScreenState();
}

class _LocationConfigScreenState extends State<LocationConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _displacement = TextEditingController();
  final _interval = TextEditingController();

  bool _manual;

  AppConfigBloc get bloc => context.bloc<AppConfigBloc>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _manual ??= false;
    _interval.text = "${timeInterval ~/ 1000}";
    _displacement.text = "$distanceFilter";
  }

  LocationOptions get options => context.bloc<ActivityBloc>().options;
  int get timeInterval => _manual ? bloc.config.locationFastestInterval : options.timeInterval;

  int get distanceFilter => _manual ? bloc.config.locationSmallestDisplacement : options.distanceFilter;

  bool get locationStoreLocally =>
      _manual ? context.bloc<AppConfigBloc>().config.locationStoreLocally : options.locationStoreLocally;

  bool get locationAllowSharing =>
      _manual ? context.bloc<AppConfigBloc>().config.locationAllowSharing : options.locationAllowSharing;

  bool get _locationDebug => _manual ? context.bloc<AppConfigBloc>().config.locationDebug : options.debug;

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
            FutureBuilder<SharedPreferences>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    _manual = snapshot.data.getBool(LocationService.pref_location_manual) ?? _manual;
                  }
                  _interval.text = "${timeInterval ~/ 1000}";
                  _displacement.text = "$distanceFilter";

                  return ListView(
                    shrinkWrap: true,
                    physics: ClampingScrollPhysics(),
                    children: <Widget>[
                      _buildManualOverride(),
                      Divider(),
                      _buildLocationAccuracyField(),
                      _buildLocationFastestIntervalField(),
                      _buildLocationSmallestDisplacementField(),
                      Divider(),
                      _buildLocationStoreLocallyField(),
                      _buildLocationAllowSharingField(),
                      Divider(),
                      _buildLocationDebugField(),
                      ListTile(
                        title: Text('Feilsøking'),
                        subtitle: Text('Feilsøke problemer med posisjon og sporing'),
                        trailing: const Icon(Icons.keyboard_arrow_right),
                        onTap: () async {
                          Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                            return DebugLocationScreen();
                          }));
                        },
                      ),
                    ],
                  );
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildManualOverride() {
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
              title: Text("Manuelle innstillinger"),
              subtitle: Text("Overstyr automatiske innstillingene"),
            ),
          ),
          Flexible(
              child: FutureBuilder<SharedPreferences>(
                  future: future,
                  builder: (context, snapshot) {
                    _manual = snapshot.hasData
                        ? snapshot.data.getBool(LocationService.pref_location_manual) ?? _manual
                        : _manual;
                    return Switch(
                      value: _manual,
                      onChanged: (value) async {
                        if (snapshot.hasData) {
                          await context.bloc<ActivityBloc>().apply(
                                manual: value,
                                config: bloc.config,
                              );
                        }
                        setState(() => _manual = value);
                      },
                    );
                  })),
        ],
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
              items: LocationAccuracy.values
                  .map((value) => DropdownMenuItem<LocationAccuracy>(
                        value: value,
                        child: Text("${LocationService.toAccuracyName(value)}", textAlign: TextAlign.center),
                      ))
                  .toList(),
              onChanged: _manual
                  ? (value) async {
                      await bloc.updateWith(
                        locationAccuracy: enumName(value),
                      );
                      setState(() {});
                    }
                  : null,
              hint: Text(
                LocationService.toAccuracyName(options.accuracy),
              ),
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
              enabled: _manual,
              controller: _displacement,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(filled: true, counterText: ""),
              onChanged: _manual
                  ? (value) {
                      if (value.isNotEmpty) {
                        bloc.updateWith(
                          locationSmallestDisplacement: int.parse(value ?? 0),
                        );
                      }
                    }
                  : null,
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
              enabled: _manual,
              controller: _interval,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(filled: true, counterText: ""),
              onChanged: _manual
                  ? (value) {
                      if (value.isNotEmpty) {
                        bloc.updateWith(
                          locationFastestInterval: int.parse(value ?? 0) * 1000,
                        );
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAllowSharingField() {
    return SwitchListTile(
      value: locationAllowSharing,
      title: Text('Del posisjoner'),
      subtitle: Text('Posisjonen kan bli lagret i aksjonen'),
      onChanged: _manual
          ? (value) {
              context.bloc<AppConfigBloc>().updateWith(
                    locationAllowSharing: value,
                  );
              setState(() {});
            }
          : null,
    );
  }

  Widget _buildLocationStoreLocallyField() {
    return SwitchListTile(
      value: locationStoreLocally,
      title: Text('Bufre posisjoner'),
      subtitle: Text('Lagres lokalt når du er uten nett'),
      onChanged: _manual
          ? (value) {
              context.bloc<AppConfigBloc>().updateWith(
                    locationStoreLocally: value,
                  );
              setState(() {});
            }
          : null,
    );
  }

  Widget _buildLocationDebugField() {
    return SwitchListTile(
        value: _locationDebug,
        title: Text('Aktiver debugging'),
        subtitle: Text('En lyd høres når endringer skjer'),
        onChanged: (value) async {
          await context.bloc<AppConfigBloc>().updateWith(
                locationDebug: value,
              );
          await LocationService().configure(
            debug: value,
          );
          setState(() {});
        });
  }

  Future<SharedPreferences> get future => _prefs ??= SharedPreferences.getInstance();
  Future<SharedPreferences> _prefs;
}
