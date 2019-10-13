import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class IncidentConfigScreen extends StatefulWidget {
  @override
  _IncidentConfigScreenState createState() => _IncidentConfigScreenState();
}

class _IncidentConfigScreenState extends State<IncidentConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  AppConfigBloc _bloc;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = BlocProvider.of<AppConfigBloc>(context);
  }

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Hendelsesoppsett"),
        automaticallyImplyLeading: true,
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
            _buildUnitsField(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsField() {
    final style = Theme.of(context).textTheme.caption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(
            "Standard enheter",
            style: Theme.of(context).textTheme.body1,
          ),
          subtitle: Text(
            "Nye hendelser får disse lagt til automatisk",
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: FormBuilderChipsInput(
            attribute: 'units',
            maxChips: 15,
            initialValue: _bloc.config.units,
            decoration: InputDecoration(
              labelText: "Opprett enheter",
              hintText: "Søk etter enheter",
              filled: true,
              contentPadding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
            ),
            findSuggestions: (String query) async {
              if (query.length != 0) {
                var lowercaseQuery = query.toLowerCase();
                final templates = asUnitTemplates(query, 15);
                return templates
                    .where((template) => template.toLowerCase().contains(lowercaseQuery))
                    .toList(growable: false);
              } else {
                return const <String>[];
              }
            },
            chipBuilder: (context, state, template) {
              return InputChip(
                key: ObjectKey(template),
                label: Text(template, style: style),
                onDeleted: () => state.deleteChip(template),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            },
            suggestionBuilder: (context, state, template) {
              return ListTile(
                key: ObjectKey(template),
                title: Text(template),
                onTap: () => state.selectSuggestion(template),
              );
            },
            onChanged: (value) => setState(() {
              _bloc.update(units: List<String>.from(value));
            }),
            // BUG: These are required, no default values are given.
            obscureText: false,
            autocorrect: false,
            inputType: TextInputType.text,
            keyboardAppearance: Brightness.dark,
            inputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.none,
          ),
        )
      ],
    );
  }
}
