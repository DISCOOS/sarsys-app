import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Location.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/point_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';

class IncidentEditor extends StatefulWidget {
  final Point ipp;
  final Incident incident;

  final PermissionController controller;

  const IncidentEditor({
    Key key,
    this.ipp,
    this.incident,
    @required this.controller,
  }) : super(key: key);

  @override
  _IncidentEditorState createState() => _IncidentEditorState();
}

class _IncidentEditorState extends State<IncidentEditor> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();
  final _tgCatalog = ValueNotifier(<String>[]);

  int _currentStep = 0;
  AppConfigBloc _configBloc;
  IncidentBloc _incidentBloc;
  bool _rememberUnits = true;
  bool _rememberTalkGroups = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    var catalogs = await AssetsService().fetchTalkGroupCatalogs(Defaults.orgId)
      ..sort();
    _tgCatalog.value = catalogs;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configBloc = BlocProvider.of<AppConfigBloc>(context);
    _incidentBloc = BlocProvider.of<IncidentBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.incident == null ? 'Ny hendelse' : 'Endre hendelse'),
        centerTitle: false,
        leading: GestureDetector(
          child: Icon(Icons.close),
          onTap: () {
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          FlatButton(
            child: Text(widget.incident == null ? 'OPPRETT' : 'OPPDATER',
                style: TextStyle(fontSize: 14.0, color: Colors.white)),
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            onPressed: () => _submit(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        reverse: _currentStep > 1,
        child: FormBuilder(
          key: _formKey,
          child: Column(
            children: <Widget>[
              Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                physics: ClampingScrollPhysics(),
                onStepTapped: (int step) {
                  setState(() => _currentStep = step);
                  FocusScope.of(context).unfocus();
                },
                onStepContinue: _currentStep < 2 ? () => setState(() => _currentStep += 1) : null,
                onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep -= 1) : null,
                controlsBuilder: (BuildContext context, {VoidCallback onStepContinue, VoidCallback onStepCancel}) {
                  return Container();
                },
                steps: [
                  _buildGeneralStep(),
                  _buildClassificationStep(),
                  _buildPoiStep(),
                  _buildTGStep(),
                  if (widget.incident == null) _buildPreparationStep(),
                  _buildReferenceStep(),
                ],
              ),
              Container(
                padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Step _buildReferenceStep() {
    return Step(
      title: Text('Referanser'),
      subtitle: Text('Oppgi hendelsesnummer oppgitt fra rekvirent'),
      content: _buildReferenceField(),
      isActive: _currentStep >= 0,
      state: _isValid(['reference'])
          ? (_currentStep > (widget.incident == null ? 5 : 4) ? StepState.complete : StepState.indexed)
          : StepState.error,
    );
  }

  Step _buildPreparationStep() {
    return Step(
      title: Text('Forberedelser'),
      subtitle: Text('Oppgi enheter som skal opprettes automatisk'),
      content: Column(
        children: <Widget>[
          _buildUnitsField(),
          _buildRememberUnitsField(),
        ],
      ),
      isActive: _currentStep >= 0,
      state: (_currentStep > 4 ? StepState.complete : StepState.indexed),
    );
  }

  Step _buildTGStep() {
    return Step(
      title: Text('Talegrupper'),
      subtitle: Text('Oppgi hvilke talegrupper som skal spores'),
      content: Column(
        children: <Widget>[
          _buildTGField(),
          SizedBox(height: 16.0),
          _buildTgCatalogField(),
          _buildRememberTalkGroupsField(),
        ],
      ),
      isActive: _currentStep >= 0,
      state: _isValid(['talkgroups']) ? (_currentStep > 3 ? StepState.complete : StepState.indexed) : StepState.error,
    );
  }

  Step _buildPoiStep() {
    return Step(
      title: Text('Plasseringer'),
      subtitle: Text('Oppgi hendelsens plasseringer'),
      content: Column(
        children: <Widget>[
          _buildLocationField(),
          SizedBox(height: 16.0),
          _buildMeetupField(),
        ],
      ),
      isActive: _currentStep >= 0,
      state:
          _isValid(['ipp', 'meetup']) ? (_currentStep > 2 ? StepState.complete : StepState.indexed) : StepState.error,
    );
  }

  Step _buildClassificationStep() {
    return Step(
      title: Text('Klassifisering'),
      subtitle: Text('Oppgi type og status'),
      content: Column(
        children: [
          buildTwoCellRow(_buildTypeField(), _buildStatusField()),
        ],
      ),
      isActive: _currentStep >= 0,
      state:
          _isValid(['type', 'status']) ? (_currentStep > 1 ? StepState.complete : StepState.indexed) : StepState.error,
    );
  }

  Step _buildGeneralStep() {
    return Step(
      title: Text('Generelt'),
      subtitle: Text('Oppgi stedsnavn og begrunnelse'),
      content: Column(
        children: [
          _buildNameField(),
          SizedBox(height: 16.0),
          _buildJustificationField(),
          SizedBox(height: 16.0),
          _buildOccurredField(),
        ],
      ),
      isActive: _currentStep >= 0,
      state: _isValid(['name', 'justification', 'occurred'])
          ? (_currentStep > 0 ? StepState.complete : StepState.indexed)
          : StepState.error,
    );
  }

  FormBuilderDateTimePicker _buildOccurredField() {
    final now = DateTime.now();
    return FormBuilderDateTimePicker(
      attribute: "occurred",
      initialTime: null,
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialValue: widget?.incident?.occurred ?? now,
      format: DateFormat("yyyy-MM-dd HH:mm"),
      resetIcon: null,
      autocorrect: true,
      decoration: InputDecoration(
        labelText: "Hendelsestidspunkt",
        contentPadding: EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 12.0),
        filled: true,
      ),
      keyboardType: TextInputType.datetime,
      validators: [
        (value) {
          return value.isAfter(DateTime.now()) ? "Du kan ikke sette klokkeslett frem i tid" : null;
        }
      ],
      valueTransformer: (dt) => dt.toString(),
    );
  }

  Widget _buildNameField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'name',
      initialValue: widget?.incident?.name,
      decoration: new InputDecoration(
        labelText: 'Stedsnavn',
        hintText: 'Oppgi stedsnavn',
        filled: true,
      ),
      validators: [
        FormBuilderValidators.required(errorText: 'Navn må fylles inn'),
      ],
    );
  }

  Widget _buildJustificationField() {
    return FormBuilderTextField(
      maxLines: 3,
      attribute: 'justification',
      initialValue: widget?.incident?.justification,
      decoration: new InputDecoration(
        labelText: 'Begrunnelse',
        hintText: 'Oppgi begrunnelse',
        filled: true,
      ),
      validators: [
        FormBuilderValidators.required(errorText: 'Begrunnelse må fylles inn'),
      ],
    );
  }

  Widget _buildReferenceField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'reference',
      initialValue: widget?.incident?.reference,
      decoration: new InputDecoration(
        hintText: 'SAR- eller AMIS-nummer',
        filled: true,
      ),
    );
  }

  Widget _buildTypeField() {
    return buildDropDownField(
      attribute: 'type',
      label: 'Type hendelse',
      initialValue: enumName(widget?.incident?.type ?? IncidentType.Lost),
      items: IncidentType.values
          .map((type) => [enumName(type), translateIncidentType(type)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Type må velges'),
      ],
    );
  }

  Widget _buildStatusField() {
    return buildDropDownField(
      attribute: 'status',
      label: 'Status',
      initialValue: enumName(widget?.incident?.status ?? IncidentStatus.Registered),
      items: IncidentStatus.values
          .map((status) => [enumName(status), translateIncidentStatus(status)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Status må velges'),
      ],
    );
  }

  Widget _buildLocationField() => PointField(
        attribute: 'ipp',
        initialValue: widget?.incident?.ipp?.point ?? widget.ipp,
        labelText: "IPP",
        hintText: 'Velg IPP',
        errorText: 'IPP må oppgis',
        controller: widget.controller,
        onChanged: (point) => setState(() {}),
      );

  Widget _buildMeetupField() => PointField(
        attribute: 'meetup',
        initialValue: widget?.incident?.meetup?.point ?? widget.ipp,
        labelText: "Oppmøtested",
        hintText: 'Velg oppmøtested',
        errorText: 'Oppmøtested må oppgis',
        controller: widget.controller,
        onChanged: (point) => setState(() {}),
      );

  Widget _buildTGField() {
    final style = Theme.of(context).textTheme.caption;
    final service = AssetsService();
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
        child: Center(
          child: FormBuilderChipsInput(
            attribute: 'talkgroups',
            maxChips: 5,
            initialValue:
                widget?.incident?.talkgroups ?? FleetMapTalkGroupConverter.toList(_configBloc.config.talkGroups),
            decoration: InputDecoration(
              labelText: "Talegrupper",
              hintText: "Søk etter talegrupper",
              filled: true,
              contentPadding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
            ),
            findSuggestions: (String query) async {
              if (query.length != 0) {
                var lowercaseQuery = query.toLowerCase();
                var talkGroup = _formKey.currentState.fields["tgCatalog"].currentState.value;
                return (await service.fetchTalkGroups(Defaults.orgId, talkGroup))
                    .where((tg) =>
                        tg.name.toLowerCase().contains(lowercaseQuery) ||
                        tg.type.toString().toLowerCase().contains(lowercaseQuery))
                    .take(5)
                    .toList(growable: false);
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
            valueTransformer: (values) => values.map((tg) => tg.toJson()).toList(),
            validators: [
              FormBuilderValidators.required(errorText: 'Talegruppe(r) må oppgis'),
            ],
            // BUG: These are required, no default values are given.
            obscureText: false,
            autocorrect: false,
            inputType: TextInputType.text,
            keyboardAppearance: Brightness.dark,
            inputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTgCatalogField() {
    return ValueListenableBuilder(
      valueListenable: _tgCatalog,
      builder: (BuildContext context, List value, Widget child) {
        return buildDropDownField(
          attribute: 'tgCatalog',
          label: 'Nødnett',
          initialValue: _configBloc?.config?.talkGroupCatalog ?? Defaults.talkGroupCatalog,
          items: _tgCatalog.value.map((name) => DropdownMenuItem(value: name, child: Text("$name"))).toList(),
          validators: [
            FormBuilderValidators.required(errorText: 'Talegruppe må velges'),
          ],
        );
      },
    );
  }

  Widget _buildRememberTalkGroupsField() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Husk talegrupper",
                style: Theme.of(context).textTheme.body1,
              ),
              subtitle: Text(
                "Liste kan endres i Nødnettsoppsett",
              ),
            ),
          ),
          Switch(
            value: _rememberTalkGroups,
            onChanged: (value) => setState(() {
              _rememberTalkGroups = !_rememberTalkGroups;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitsField() {
    final style = Theme.of(context).textTheme.caption;
    return Padding(
      padding: EdgeInsets.zero,
      child: FormBuilderChipsInput(
        attribute: 'units',
        maxChips: 15,
        initialValue: _configBloc.config.units,
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
        // BUG: These are required, no default values are given.
        obscureText: false,
        autocorrect: false,
        inputType: TextInputType.text,
        keyboardAppearance: Brightness.dark,
        inputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.none,
      ),
    );
  }

  Widget _buildRememberUnitsField() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Husk enheter",
                style: Theme.of(context).textTheme.body1,
              ),
              subtitle: Text(
                "Liste kan endres i Hendelsesoppsett",
              ),
            ),
          ),
          Switch(
            value: _rememberUnits,
            onChanged: (value) => setState(() {
              _rememberUnits = !_rememberUnits;
            }),
          ),
        ],
      ),
    );
  }

  _isValid(List<String> fields) {
    var state = _formKey.currentState;
    return _formKey.currentState == null ||
        fields.where((name) => state.fields[name] == null || !state.fields[name].currentState.hasError).length ==
            fields.length;
  }

  Map<String, dynamic> _toJson() {
    Map<String, dynamic> json = Map.from(_formKey.currentState.value);
    json['ipp'] = Location(point: Point.fromJson(json['ipp'])).toJson();
    json['meetup'] = Location(point: Point.fromJson(json['meetup'])).toJson();
    return json;
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState.validate()) {
      Incident incident;
      const closed = [IncidentStatus.Cancelled, IncidentStatus.Resolved];
      final current = widget?.incident?.status;
      final userId = BlocProvider.of<UserBloc>(context).user?.userId;

      _formKey.currentState.save();

      if (_rememberTalkGroups) {
        final list = _formKey.currentState.value['talkgroups'];
        final talkGroups = List<String>.from(
          list.map((tg) => TalkGroup.fromJson(tg)).map((tg) => tg.name),
        );
        _configBloc.update(talkGroups: talkGroups);
      }

      if (widget.incident == null) {
        final units = List<String>.from(_formKey.currentState.value['units']);
        if (_rememberUnits) {
          _configBloc.update(units: units);
        }
        Navigator.pop(
          context,
          Pair<Incident, List<String>>.of(Incident.fromJson(_toJson()).withAuthor(userId), units),
        );
      } else {
        incident = widget.incident.withJson(_toJson(), userId: userId);
        if (!closed.contains(current) && IncidentStatus.Cancelled == incident.status) {
          prompt(
            context,
            "Bekreft kansellering",
            "Dette vil stoppe alle sporinger og sette status til Kansellert",
          ).then(
            (proceed) => proceed ? _update(incident) : Navigator.pop(context),
          );
        } else if (!closed.contains(current) && IncidentStatus.Resolved == incident.status) {
          prompt(
            context,
            "Bekreft løsning",
            "Dette vil stoppe alle sporinger og sette status til Løst",
          ).then(
            (proceed) => proceed ? _update(incident) : Navigator.pop(context),
          );
        } else {
          _update(incident);
        }
      }
    } else {
      // Show errors
      setState(() {});
    }
  }

  void _update(Incident incident) {
    _incidentBloc.update(incident);
    Navigator.pop(context, incident);
  }
}
