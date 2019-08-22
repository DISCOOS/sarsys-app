import 'dart:io';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:filesize/filesize.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MapConfigScreen extends StatefulWidget {
  @override
  _MapConfigScreenState createState() => _MapConfigScreenState();
}

class _MapConfigScreenState extends State<MapConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _ttl = TextEditingController();
  final _capacity = TextEditingController();

  AppConfigBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = BlocProvider.of<AppConfigBloc>(context);
    _ttl.text = "${_bloc.config.mapCacheTTL}";
    _capacity.text = "${_bloc.config.mapCacheCapacity}";
  }

  @override
  void dispose() {
    super.dispose();
    _ttl.dispose();
    _capacity.dispose();
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
    final cache = DefaultCacheManager();
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
}
