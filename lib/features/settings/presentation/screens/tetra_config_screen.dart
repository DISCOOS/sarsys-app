import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';
import 'package:SarSys/core/domain/models/converters.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class TetraConfigScreen extends StatefulWidget {
  @override
  _TetraConfigScreenState createState() => _TetraConfigScreenState();
}

class _TetraConfigScreenState extends State<TetraConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  AppConfigBloc _bloc;
  Organisation get organisation => context.bloc<AffiliationBloc>().findUserOrganisation();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = context.bloc<AppConfigBloc>();
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
        padding: const EdgeInsets.all(8.0),
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

  Padding _buildTGCatalogField() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(flex: 1, child: Text("Nødnettskatalog")),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              disabledHint: Text("Laster..."),
              items: sortList(organisation.fleetMap.catalogs
                  .map((catalog) => catalog.name)
                  .map((name) => DropdownMenuItem<String>(
                        value: "$name",
                        child: Text("$name"),
                      ))
                  .toList()),
              onChanged: (value) => setState(() {
                _bloc.updateWith(talkGroupCatalog: value);
              }),
              value: _bloc.config?.talkGroupCatalog ?? Defaults.talkGroupCatalog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTGField() {
    final style = Theme.of(context).textTheme.caption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(
            "Standard talegrupper",
            style: Theme.of(context).textTheme.bodyText2,
          ),
          subtitle: Text(
            "Nye hendelser får disse lagt til automatisk",
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0),
          child: FormBuilderChipsInput(
            name: 'talkgroups',
            maxChips: 5,
            initialValue: FleetMapTalkGroupConverter.toList(_bloc.config.talkGroups),
            decoration: InputDecoration(
              labelText: "Lytt til",
              hintText: "Søk etter talegrupper",
              hintStyle: Theme.of(context).textTheme.bodyText2.copyWith(color: Colors.grey),
              filled: true,
              contentPadding: const EdgeInsets.all(8.0).copyWith(bottom: 10.0),
            ),
            findSuggestions: (String query) async {
              if (query.length != 0) {
                var catalog = _bloc.config.talkGroupCatalog;
                return AffiliationUtils.findTalkGroups(
                  AffiliationUtils.findCatalog(organisation.fleetMap, catalog),
                  query,
                );
              } else {
                return const <TalkGroup>[];
              }
            },
            chipBuilder: (context, state, tg) {
              return InputChip(
                key: ObjectKey(tg),
                label: Text(tg.name, style: style),
                onDeleted: () => state.deleteChip(tg),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            },
            suggestionBuilder: (context, state, tg) {
              return ListTile(
                key: ObjectKey(tg),
                leading: CircleAvatar(
                  child: Text(enumName(tg.type).substring(0, 1)),
                ),
                title: Text(tg.name),
                onTap: () => state.selectSuggestion(tg),
              );
            },
            onChanged: (value) => setState(() {
              final items = value.map((tg) => tg.name).toList();
              _bloc.updateWith(talkGroups: List<String>.from(items));
            }),
            // BUG: These are required, no default values are given.
            obscureText: false,
            autocorrect: false,
            inputType: TextInputType.text,
            keyboardAppearance: Brightness.dark,
            inputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.none,
          ),
        ),
      ],
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
