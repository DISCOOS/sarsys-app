

import 'dart:io';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/data/services/file_cache_service.dart';
import 'package:filesize/filesize.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MapConfigScreen extends StatefulWidget {
  @override
  _MapConfigScreenState createState() => _MapConfigScreenState();
}

class _MapConfigScreenState extends State<MapConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _ttl = TextEditingController();
  final _capacity = TextEditingController();

  late AppConfigBloc _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = context.read<AppConfigBloc>();
    _ttl.text = '${_bloc.config!.mapCacheTTL}';
    _capacity.text = '${_bloc.config!.mapCacheCapacity}';
  }

  @override
  void dispose() {
    _ttl.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Kartoppsett'),
        automaticallyImplyLeading: true,
        centerTitle: false,
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
          _buildUseRetinaModeField(),
          _buildKeepScreenOnField(),
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
              title: Text('Maksimal lagringstid for kartfliser'),
              subtitle: Text('Angi mellom 0 til 999 dager'),
            ),
          ),
          Flexible(
            child: TextField(
              maxLength: 3,
              controller: _ttl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(filled: true, counterText: ''),
              onChanged: (value) {
                _bloc.updateWith(mapCacheTTL: int.parse(value ?? 0 as String));
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
              title: Text('Maksimalt antall kartfliser lagret'),
              subtitle: Text('Angi mellom 0 til 99999 fliser'),
            ),
          ),
          Flexible(
            child: TextField(
              maxLength: 5,
              controller: _capacity,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(filled: true, counterText: ''),
              onChanged: (value) {
                _bloc.updateWith(mapCacheCapacity: int.parse(value ?? 0 as String));
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
            final root = new Directory(snapshot.data as String);
            final files = root.listSync(recursive: true);
            final size = files.fold(0, (dynamic sum, file) => sum + file.statSync().size);
            return ListTile(
              title: Text('Slett kartbuffer'),
              subtitle: Text('Inneholder totalt ${files.length} kartfliser (${filesize(size)})'),
              trailing: Icon(Icons.delete),
              onTap: () async {
                if (await prompt(
                  context,
                  'Slette kart-fliser',
                  'Dette vil slette alle kartfliser lastet ned lokalt. Vil du fortsette?',
                )) {
                  imageCache!.clear();
                  await cache.emptyCache();
                  setState(() {});
                }
              },
            );
          }
          if (snapshot.hasError) {
            return ListTile(
              title: Text('Kartbuffer ikke funnet'),
              subtitle: Text('${snapshot.error}'),
            );
          }
          return Container();
        });
  }

  Widget _buildKeepScreenOnField() {
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
              title: Text('Hold skjermen påslått'),
              subtitle: Text('Når kartet vises vil skjermen forbli påslått'),
            ),
          ),
          Flexible(
            child: Switch(
              value: _bloc.config!.keepScreenOn,
              onChanged: (value) => setState(() {
                _bloc.updateWith(keepScreenOn: value);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUseRetinaModeField() {
    return SwitchListTile(
      value: context.read<AppConfigBloc>().config!.mapRetinaMode,
      title: Text('Vis høy oppløsning'),
      subtitle: Text('Krever skjerm med stor oppløsning (retina)'),
      onChanged: (value) {
        context.read<AppConfigBloc>().updateWith(
              mapRetinaMode: value,
            );
        setState(() {});
      },
    );
  }
}
