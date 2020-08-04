import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/data/services/location/location_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/foundation.dart';
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

  AppConfigBloc get bloc => context.bloc<AppConfigBloc>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _interval.text = "${bloc.config.locationFastestInterval ~/ 1000}";
    _displacement.text = "${bloc.config.locationSmallestDisplacement}";
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
                _buildLocationDebugField(),
              ],
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
                if (value.isNotEmpty) {
                  bloc.updateWith(
                    locationSmallestDisplacement: int.parse(value ?? 0),
                  );
                }
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
                if (value.isNotEmpty) {
                  bloc.updateWith(
                    locationFastestInterval: int.parse(value ?? 0) * 1000,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _debug = kDebugMode;

  Padding _buildLocationDebugField() {
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
              title: Text("Aktiver debugging"),
              subtitle: Text("En lyd høres når endringer skjer"),
            ),
          ),
          Flexible(
              child: FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, snapshot) {
                    _debug = snapshot.hasData ? snapshot.data.getBool('location_debug') ?? false : _debug;
                    return Switch(
                      value: _debug,
                      onChanged: (value) async {
                        if (snapshot.hasData) {
                          await snapshot.data.setBool('location_debug', value);
                          await LocationService().configure(
                            debug: value,
                          );
                        }
                        setState(() => _debug = value);
                      },
                    );
                  })),
        ],
      ),
    );
  }
}
