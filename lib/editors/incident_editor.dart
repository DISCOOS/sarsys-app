import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/editors/point_editor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';

class IncidentEditor extends StatefulWidget {
  final Incident incident;

  const IncidentEditor({Key key, this.incident}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _configBloc = BlocProvider.of<AppConfigBloc>(context);
    _incidentBloc = BlocProvider.of<IncidentBloc>(context);
    _init();
  }

  void _init() async {
    await _configBloc.fetch();
    var catalogs = await AssetsService().fetchTalkGroupCatalogs(Defaults.orgId)
      ..sort();
    _tgCatalog.value = catalogs;
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Scaffold(
      key: _scaffoldKey,
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
                  FocusScope.of(context).requestFocus(new FocusNode());
                },
                onStepContinue: _currentStep < 2 ? () => setState(() => _currentStep += 1) : null,
                onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep -= 1) : null,
                controlsBuilder: (BuildContext context, {VoidCallback onStepContinue, VoidCallback onStepCancel}) {
                  return Container();
                },
                steps: [
                  Step(
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
                  ),
                  Step(
                    title: Text('Klassifisering'),
                    subtitle: Text('Oppgi type og status'),
                    content: Column(
                      children: [
                        _buildTypeField(),
                        SizedBox(height: 16.0),
                        _buildStatusField(),
                      ],
                    ),
                    isActive: _currentStep >= 0,
                    state: _isValid(['type', 'status'])
                        ? (_currentStep > 1 ? StepState.complete : StepState.indexed)
                        : StepState.error,
                  ),
                  Step(
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
                    state: _isValid(['ipp'])
                        ? (_currentStep > 2 ? StepState.complete : StepState.indexed)
                        : StepState.error,
                  ),
                  Step(
                    title: Text('Talegrupper'),
                    subtitle: Text('Oppgi hvilke talegrupper som skal spores'),
                    content: Column(
                      children: <Widget>[
                        _buildTGField(),
                        SizedBox(height: 16.0),
                        _buildTgCatalogField(),
                      ],
                    ),
                    isActive: _currentStep >= 0,
                    state: _isValid(['talkgroups'])
                        ? (_currentStep > 3 ? StepState.complete : StepState.indexed)
                        : StepState.error,
                  ),
                  Step(
                    title: Text('Referanser'),
                    subtitle: Text('Oppgi hendelsesnummer oppgitt fra rekvirent'),
                    content: _buildReferenceField(),
                    isActive: _currentStep >= 0,
                    state: _isValid(['reference'])
                        ? (_currentStep > 4 ? StepState.complete : StepState.indexed)
                        : StepState.error,
                  ),
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
        hintText: "Hendelsestidspunkt",
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
      autofocus: true,
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
      autofocus: false,
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
      autofocus: true,
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

  Widget _buildLocationField() => FormBuilderCustomField(
        attribute: 'ipp',
        formField: FormField<Point>(
          enabled: true,
          initialValue: widget?.incident?.ipp,
          builder: (FormFieldState<Point> field) => GestureDetector(
            child: InputDecorator(
              decoration: InputDecoration(
                filled: true,
                labelText: "IPP",
                suffixIcon: Icon(Icons.map),
                contentPadding: EdgeInsets.fromLTRB(12.0, 16.0, 8.0, 16.0),
                errorText: field.hasError ? field.errorText : null,
              ),
              child: field.value == null
                  ? Text('Velg IPP', style: Theme.of(context).textTheme.caption.copyWith(fontSize: 16))
                  : Text(
                      toUTM(field.value),
                      style: Theme.of(context).textTheme.subhead.copyWith(fontSize: 16),
                    ),
            ),
            onTap: () => _selectLocation(context, field),
          ),
        ),
        valueTransformer: (point) => point.toJson(),
        validators: [
          FormBuilderValidators.required(errorText: 'IPP må oppgis'),
        ],
      );

  void _selectLocation(BuildContext context, FormFieldState<Point> field) async {
    final selected = await showDialog(
      context: context,
      builder: (context) => PointEditor(field.value, 'Velg IPP', incident: widget.incident),
    );
    if (selected != field.value) {
      field.didChange(selected);
      setState(() {});
    }
  }

  Widget _buildMeetupField() => FormBuilderCustomField(
        attribute: 'meetup',
        formField: FormField<Point>(
          enabled: true,
          initialValue: widget?.incident?.meetup,
          builder: (FormFieldState<Point> field) => GestureDetector(
            child: InputDecorator(
              decoration: InputDecoration(
                filled: true,
                labelText: "Oppmøtested",
                suffixIcon: Icon(Icons.map),
                contentPadding: EdgeInsets.fromLTRB(12.0, 16.0, 8.0, 16.0),
                errorText: field.hasError ? field.errorText : null,
              ),
              child: field.value == null
                  ? Text('Velg oppmøtested', style: Theme.of(context).textTheme.caption.copyWith(fontSize: 16))
                  : Text(
                      toUTM(field.value),
                      style: Theme.of(context).textTheme.subhead.copyWith(fontSize: 16),
                    ),
            ),
            onTap: () => _selectMeetup(context, field),
          ),
        ),
        valueTransformer: (point) => point.toJson(),
        validators: [
          FormBuilderValidators.required(errorText: 'Oppmøtested må oppgis'),
        ],
      );

  void _selectMeetup(BuildContext context, FormFieldState<Point> field) async {
    final selected = await showDialog(
      context: context,
      builder: (context) => PointEditor(field.value, 'Velg oppmøtested', incident: widget.incident),
    );
    if (selected != field.value) {
      field.didChange(selected);
      setState(() {});
    }
  }

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
            initialValue: widget?.incident?.talkgroups,
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
                return (await service.fetchTalkGroups(Defaults.orgId, talkGroup)).where((tg) {
                  return tg.name.toLowerCase().contains(lowercaseQuery) ||
                      tg.type.toString().toLowerCase().contains(lowercaseQuery);
                }).toList(growable: false);
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
          ),
        ),
      ),
    );
  }

  _isValid(List<String> fields) {
    var state = _formKey.currentState;
    return _formKey.currentState == null ||
        fields.where((name) => state.fields[name] == null || !state.fields[name].currentState.hasError).length ==
            fields.length;
  }

  Widget _buildTgCatalogField() {
    return ValueListenableBuilder(
      valueListenable: _tgCatalog,
      builder: (BuildContext context, List value, Widget child) {
        return buildDropDownField(
          attribute: 'tgCatalog',
          label: 'Nødnett',
          initialValue: _configBloc?.config?.talkGroups ?? Defaults.talkGroups,
          items: _tgCatalog.value.map((name) => DropdownMenuItem(value: name, child: Text("$name"))).toList(),
          validators: [
            FormBuilderValidators.required(errorText: 'Talegruppe må velges'),
          ],
        );
      },
    );
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState.validate()) {
      const closed = [IncidentStatus.Cancelled, IncidentStatus.Resolved];
      final userId = BlocProvider.of<UserBloc>(context).user?.userId;
      final current = widget?.incident?.status;
      var incident;
      _formKey.currentState.save();
      if (widget.incident == null) {
        _create(Incident.fromJson(_formKey.currentState.value).withAuthor(userId));
      } else {
        incident = widget.incident.withJson(_formKey.currentState.value, userId: userId);
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

  void _create(Incident incident) {
    _incidentBloc.create(incident);
    Navigator.pop(context, incident);
  }

  void _update(Incident incident) {
    _incidentBloc.update(incident);
    Navigator.pop(context, incident);
  }
}
