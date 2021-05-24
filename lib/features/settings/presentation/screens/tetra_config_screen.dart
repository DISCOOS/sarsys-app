import 'package:SarSys/core/domain/models/converters.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroupCatalog.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TetraConfigScreen extends StatefulWidget {
  @override
  _TetraConfigScreenState createState() => _TetraConfigScreenState();
}

class _TetraConfigScreenState extends State<TetraConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  AppConfigBloc _bloc;
  Organisation get organisation => context.read<AffiliationBloc>().findUserOrganisation();

  List<TalkGroupCatalog> get catalogs => sortList(
        organisation.fleetMap?.catalogs ?? [],
        (TalkGroupCatalog a, TalkGroupCatalog b) => a.name.compareTo(
          b.name,
        ),
      );

  List<TalkGroup> getTgGroups(String catalog) {
    return organisation.fleetMap.catalogs.firstWhere((c) => c.name == catalog, orElse: () => null)?.groups ?? [];
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = context.read<AppConfigBloc>();
  }

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Nødnettsoppsett"),
        automaticallyImplyLeading: true,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            _buildTGCatalogField(),
            _buildTGField(),
            _buildCallsignReuse(),
          ],
        ),
      ),
    );
  }

  Widget _buildTGCatalogField() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(flex: 1, child: Text("Standard nødnettkatalog")),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            disabledHint: Text("Laster..."),
            items: catalogs
                .map((catalog) => catalog.name)
                .map((name) => DropdownMenuItem<String>(
                      value: "$name",
                      child: Text("$name"),
                    ))
                .toList(),
            onChanged: (value) => setState(() {
              _bloc.updateWith(talkGroupCatalog: value);
            }),
            value: _bloc.config?.talkGroupCatalog ?? Defaults.talkGroupCatalog,
          ),
        ),
      ],
    );
  }

  Widget _buildTGField() {
    return buildChipsField<TalkGroup>(
      name: 'talkgroups',
      labelText: 'Lytt til',
      hintText: 'Velg talegrupper',
      selectorLabel: 'Lytt til',
      selectorTitle: 'Velg talegrupper',
      builder: (context, tg) => Chip(label: Text(tg.name)),
      categories: catalogs.map(
        (c) => DropdownMenuItem<String>(
          value: c.name,
          child: Text(c.name),
        ),
      ),
      category: _bloc.config.talkGroupCatalog,
      items: () => FleetMapTalkGroupConverter.toList(
        _bloc.config.talkGroups,
      ),
      options: (String category, String query) {
        if (query?.isNotEmpty == true) {
          return AffiliationUtils.findTalkGroups(
            AffiliationUtils.findCatalog(organisation.fleetMap, category),
            query,
          );
        }
        return getTgGroups(
          category ?? _bloc.config.talkGroupCatalog,
        );
      },
      onChanged: (value) => setState(() {
        final items = value.map((tg) => tg.name).toList();
        _bloc.updateWith(talkGroups: List<String>.from(items));
      }),
    );
  }

  Widget _buildCallsignReuse() {
    return Padding(
      padding: const EdgeInsets.only(left: 0.0, right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
              flex: 2,
              child: ListTile(
                title: Text(
                  "Gjenbruk kallesignal",
                  style: Theme.of(context).textTheme.bodyText2,
                ),
                subtitle: Text(
                  "Kallesignal til oppløste enheter gjenbrukes",
                ),
              )),
          Switch(
            value: _bloc.config.callsignReuse,
            onChanged: (value) => setState(() {
              _bloc.updateWith(callsignReuse: value);
            }),
          ),
        ],
      ),
    );
  }
}
