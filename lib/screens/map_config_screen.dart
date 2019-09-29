import 'dart:io';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/services/image_cache_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:filesize/filesize.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

class MapConfigScreen extends StatefulWidget {
  @override
  _MapConfigScreenState createState() => _MapConfigScreenState();
}

class _MapConfigScreenState extends State<MapConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _ttl = TextEditingController();
  final _capacity = TextEditingController();
  final _displacement = TextEditingController();
  final _interval = TextEditingController();

  AppConfigBloc _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = BlocProvider.of<AppConfigBloc>(context);
    _ttl.text = "${_bloc.config.mapCacheTTL}";
    _capacity.text = "${_bloc.config.mapCacheCapacity}";
    _interval.text = "${_bloc.config.locationFastestInterval ~/ 1000}";
    _displacement.text = "${_bloc.config.locationSmallestDisplacement}";
  }

  @override
  void dispose() {
    _ttl.dispose();
    _capacity.dispose();
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
        title: Text("Kartdata og oppsett"),
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        shrinkWrap: true,
        children: <Widget>[
          _buildClearCacheAction(),
          Divider(),
          _buildMapCacheTTLField(),
          _buildMapCacheCapacityField(),
          Divider(),
          _buildLocationAccuracyField(),
          _buildLocationFastestIntervalField(),
          _buildLocationSmallestDisplacementField(),
        ],
      ),
    );
  }

  Padding _buildMapCacheTTLField() {
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
              title: Text("Maksimal lagringstid for kartfliser"),
              subtitle: Text("Angi mellom 0 til 999 dager"),
            ),
          ),
          Flexible(
            child: TextField(
              controller: _ttl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(filled: true, counterText: ""),
              maxLength: 3,
              inputFormatters: [WhitelistingTextInputFormatter(RegExp("[0-9]"))],
              onChanged: (value) {
                _bloc.update(mapCacheTTL: int.parse(value ?? 0));
              },
            ),
          ),
        ],
      ),
    );
  }

  Padding _buildMapCacheCapacityField() {
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
              title: Text("Maksimalt antall kartfliser lagret"),
              subtitle: Text("Angi mellom 0 til 99999 fliser"),
            ),
          ),
          Flexible(
            child: TextField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(filled: true, counterText: ""),
              maxLength: 5,
              inputFormatters: [WhitelistingTextInputFormatter(RegExp("[0-9]"))],
              onChanged: (value) {
                _bloc.update(mapCacheCapacity: int.parse(value ?? 0));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearCacheAction() {
    final cache = FileCacheService(_bloc.config);
    final path = cache.getFilePath();
    return FutureBuilder<Object>(
        future: path,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final root = new Directory(snapshot.data);
            final files = root.listSync(recursive: true);
            final size = files.fold(0, (sum, file) => sum + file.statSync().size);
            return ListTile(
              title: Text("Slett kartbuffer"),
              subtitle: Text("Inneholder totalt ${files.length} kartfliser (${filesize(size)})"),
              trailing: Icon(Icons.delete),
              onTap: () async {
                if (await prompt(
                  context,
                  "Slette kart-fliser",
                  "Dette vil slette alle kartfliser lagret lokalt. Vil du fortsette?",
                )) {
                  await cache.emptyCache();
                  setState(() {});
                }
              },
            );
          }
          return Container();
        });
  }

  _buildLocationAccuracyField() {
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
                        child: Text("${_toAccuracyName(value)}", textAlign: TextAlign.center),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _bloc.update(locationAccuracy: enumName(value));
                });
              },
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
              controller: _displacement,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(filled: true, counterText: ""),
              maxLength: 2,
              inputFormatters: [WhitelistingTextInputFormatter(RegExp("[0-9]"))],
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
              controller: _interval,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(filled: true, counterText: ""),
              maxLength: 2,
              inputFormatters: [WhitelistingTextInputFormatter(RegExp("[0-9]"))],
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

  _toAccuracyName(LocationAccuracy value) {
    switch (value) {
      case LocationAccuracy.lowest:
        return "Lavest";
      case LocationAccuracy.low:
        return "Lav";
      case LocationAccuracy.medium:
        return "Medium";
      case LocationAccuracy.high:
        return "Høy";
      case LocationAccuracy.best:
        return "Best";
      case LocationAccuracy.bestForNavigation:
        return "Navigasjon";
    }
  }
}
