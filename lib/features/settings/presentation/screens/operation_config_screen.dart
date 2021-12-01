

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/unit/presentation/widgets/unit_widgets.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/extensions.dart';

class OperationConfigScreen extends StatefulWidget {
  @override
  _OperationConfigScreenState createState() => _OperationConfigScreenState();
}

class _OperationConfigScreenState extends State<OperationConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late AppConfigBloc _bloc;

  List<String>? _templates;

  @override
  void initState() {
    super.initState();
    _templates ??= context.read<AppConfigBloc>().config.units;
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
        title: Text("Aksjonsoppsett"),
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
            _buildUnitsTemplateField(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsTemplateField() {
    final enabled = true; //hasAvailableDevices;
    final types = List.from(UnitType.values)
      ..sort(
        (a, b) => enumName(a).compareTo(enumName(b)),
      );
    return buildChipsField<String>(
        name: 'units',
        enabled: enabled,
        labelText: 'Enheter',
        selectorLabel: 'Enheter',
        hintText: 'Søk etter enheter',
        selectorTitle: 'Velg enheter',
        emptyText: 'Fant ingen enheter',
        helperText: 'Listen kan endres i Hendelsesopppsett',
        builder: (context, unit) => UnitTemplateChip(unit: unit),
        categories: [
          DropdownMenuItem<String>(
            value: 'alle',
            child: Text('Alle'),
          ),
          ...types.map(
            (type) => DropdownMenuItem<String>(
              value: enumName(translateUnitType(type)),
              child: Text(translateUnitType(type).capitalize()),
            ),
          ),
        ],
        category: 'alle',
        options: _findUnits,
        items: () => _templates,
        onChanged: (templates) => updateUnitsTemplate(templates as List<String>));
  }

  void updateUnitsTemplate(List<String> templates) {
    _templates!.clear();
    _templates!.addAll(templates);
    _bloc.updateWith(units: List<String>.from(templates));
  }

  List<String> _findUnits(String? type, String? query) {
    var lowercaseQuery = query!.toLowerCase();
    final templates = asUnitTemplates(query, 15);
    return templates
        .where((template) => (template.toLowerCase().contains(type!.toLowerCase())) || type.contains('alle'))
        .where((template) => template.toLowerCase().contains(lowercaseQuery))
        .toList(growable: false);
  }
}
