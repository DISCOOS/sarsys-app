import 'package:SarSys/blocs/UserBloc.dart';
import 'package:SarSys/editors/PointEditor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
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
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Ny hendelse"),
        centerTitle: false,
        leading: GestureDetector(
          child: Icon(Icons.close),
          onTap: () {
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          FlatButton(
            child: Text('OPPRETT', style: TextStyle(fontSize: 14.0, color: Colors.white)),
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
                onStepTapped: (int step) => setState(() => _currentStep = step),
                onStepContinue: _currentStep < 2 ? () => setState(() => _currentStep += 1) : null,
                onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep -= 1) : null,
                controlsBuilder: (BuildContext context, {VoidCallback onStepContinue, VoidCallback onStepCancel}) {
                  return Container();
                },
                steps: [
                  Step(
                    title: Text('Generelt'),
                    subtitle: Text('Oppgi navn og begrunnelse'),
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
                    title: Text('Plassering'),
                    subtitle: Text('Oppgi hendelsens plassering'),
                    content: _buildLocationField(),
                    isActive: _currentStep >= 0,
                    state: _isValid(['ipp'])
                        ? (_currentStep > 2 ? StepState.complete : StepState.indexed)
                        : StepState.error,
                  ),
                  Step(
                    title: Text('Talegrupper'),
                    subtitle: Text('Oppgi hvilke talegrupper som skal spores'),
                    content: _buildTGField(),
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
    return FormBuilderDateTimePicker(
      attribute: "occurred",
      initialTime: null,
      initialValue: widget?.incident?.occurred ?? DateTime.now(),
      inputType: InputType.both,
      format: DateFormat("yyyy-MM-dd HH:mm"),
      resetIcon: null,
      autocorrect: true,
      autovalidate: true,
      editable: false,
      decoration: InputDecoration(
        labelText: "Hendelsestidspunkt",
        isDense: true,
        contentPadding: EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 8.0),
        hasFloatingPlaceholder: false,
        filled: true,
      ),
      keyboardType: TextInputType.datetime,
      valueTransformer: (dt) => dt.toString(),
    );
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      print(_formKey.currentState.value);
      var userId = BlocProvider.of<UserBloc>(context).user?.userId;
      var incident = Incident.fromJson(_formKey.currentState.value).withAuthor(userId);
      Navigator.pop(context, incident);
    } else {
      // Show errors
      setState(() {});
    }
  }

  Widget _buildNameField() {
    return FormBuilderTextField(
      maxLines: 1,
      autofocus: true,
      attribute: 'name',
      initialValue: widget?.incident?.name,
      decoration: new InputDecoration(
        hintText: 'Navn',
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
        hintText: 'Begrunnelse',
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
    return _buildDropDownField(
      attribute: 'type',
      label: 'Type hendelse',
      initialValue: widget?.incident?.type ?? enumName(IncidentType.Lost),
      items: [
        [enumName(IncidentType.Lost), 'Savnet'],
        [enumName(IncidentType.Distress), 'Nødstedt'],
        [enumName(IncidentType.Other), 'Annet'],
      ].map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}"))).toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Type må velges'),
      ],
    );
  }

  Widget _buildStatusField() {
    return _buildDropDownField(
      attribute: 'status',
      label: 'Status',
      initialValue: widget?.incident?.status ?? enumName(IncidentStatus.Registered),
      items: [
        [enumName(IncidentStatus.Registered), 'Registrert'],
        [enumName(IncidentStatus.Handling), 'Håndteres'],
        [enumName(IncidentStatus.Other), 'Annet'],
      ].map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}"))).toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Status må velges'),
      ],
    );
  }

  Widget _buildDropDownField<T>({
    @required String attribute,
    @required String label,
    @required T initialValue,
    @required List<DropdownMenuItem<T>> items,
    @required List<FormFieldValidator> validators,
  }) =>
      FormBuilderCustomField(
        attribute: attribute,
        formField: FormField<T>(
          enabled: true,
          initialValue: initialValue,
          builder: (FormFieldState<T> field) => _buildDropdown<T>(
                field: field,
                label: label,
                items: items,
              ),
        ),
        validators: validators,
      );

  Widget _buildDropdown<T>({
    @required FormFieldState<T> field,
    @required String label,
    @required List<DropdownMenuItem<T>> items,
  }) =>
      InputDecorator(
        decoration: InputDecoration(
          hasFloatingPlaceholder: true,
          errorText: field.hasError ? field.errorText : null,
          filled: true,
          labelText: label,
        ),
        child: DropdownButtonHideUnderline(
          child: ButtonTheme(
            alignedDropdown: false,
            child: DropdownButton<T>(
              value: field.value,
              isDense: true,
              onChanged: (T newValue) {
                field.didChange(newValue);
              },
              items: items,
            ),
          ),
        ),
      );

  Widget _buildLocationField() => FormBuilderCustomField(
        attribute: 'ipp',
        formField: FormField<Point>(
          enabled: true,
          initialValue: widget?.incident?.ipp,
          builder: (FormFieldState<Point> field) => GestureDetector(
                child: InputDecorator(
                  decoration: InputDecoration(
                    filled: true,
                    suffixIcon: Icon(Icons.map),
                    contentPadding: EdgeInsets.fromLTRB(12.0, 16.0, 8.0, 16.0),
                    errorText: field.hasError ? field.errorText : null,
                  ),
                  child: field.value == null
                      ? Text('Velg posisjon', style: Theme.of(context).textTheme.caption.copyWith(fontSize: 16))
                      : Text(
                          PointEditor.toUTM(field.value),
                          style: Theme.of(context).textTheme.subhead.copyWith(fontSize: 16),
                        ),
                ),
                onTap: () => _selectLocation(context, field),
              ),
        ),
        valueTransformer: (point) => point.toJson(),
        validators: [
          FormBuilderValidators.required(errorText: 'Plassering må oppgis'),
        ],
      );

  void _selectLocation(BuildContext context, FormFieldState<Point> field) async {
    final selected = await showDialog(
      context: context,
      builder: (context) => PointEditor(field.value, 'Velg plassering'),
    );
    if (selected != field.value) {
      field.didChange(selected);
      setState(() {});
    }
  }

  Widget _buildTGField() {
    final style = Theme.of(context).textTheme.caption;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
        child: Center(
          child: FormBuilderChipsInput(
            attribute: 'talkgroups',
            maxChips: 5,
            initialValue: widget?.incident?.talkgroups,
            decoration: InputDecoration(
              hintText: "Søk etter talegrupper",
              filled: true,
              contentPadding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
            ),
            findSuggestions: (String query) {
              if (query.length != 0) {
                var lowercaseQuery = query.toLowerCase();
                return mockResults.where((tg) {
                  return tg.name.toLowerCase().contains(query.toLowerCase()) ||
                      tg.type.toString().toLowerCase().contains(query.toLowerCase());
                }).toList(growable: false)
                  ..sort((a, b) => a.name
                      .toLowerCase()
                      .indexOf(lowercaseQuery)
                      .compareTo(b.name.toLowerCase().indexOf(lowercaseQuery)));
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
}

String enumName(Object o) => o.toString().split('.').last;

var mockResults = <TalkGroup>[
  TalkGroup(name: "01-SAR-1", type: TalkGroupType.Tetra),
  TalkGroup(name: "01-SAR-2", type: TalkGroupType.Tetra),
  TalkGroup(name: "01-SAR-3", type: TalkGroupType.Tetra),
  TalkGroup(name: "01-SAR-4", type: TalkGroupType.Tetra),
];
