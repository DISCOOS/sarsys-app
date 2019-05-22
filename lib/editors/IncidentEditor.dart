import 'package:SarSys/editors/PointEditor.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/TalkGroup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class IncidentEditor extends StatefulWidget {
  final Incident incident;

  const IncidentEditor({Key key, this.incident}) : super(key: key);

  @override
  _IncidentEditorState createState() => _IncidentEditorState();
}

class _IncidentEditorState extends State<IncidentEditor> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              if (_formKey.currentState.validate()) {
                _formKey.currentState.save();
                print(_formKey.currentState.value);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: FormBuilder(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNameField(),
                SizedBox(height: 16.0),
                _buildJustificationField(),
                SizedBox(height: 16.0),
                _buildTypeField(),
                SizedBox(height: 16.0),
                _buildStatusField(),
                SizedBox(height: 16.0),
                Divider(),
                _buildSubheader(context, 'Plassering'),
                SizedBox(height: 16.0),
                _buildLocationField(),
                SizedBox(height: 16.0),
                Divider(),
                _buildSubheader(context, 'Talegrupper'),
                SizedBox(height: 16.0),
//              _buildTGField(),
//              _buildTGField(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _buildSubheader(BuildContext context, String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.subhead,
        ),
      ],
    );
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
        icon: new Icon(
          Icons.announcement,
          color: Colors.grey,
        ),
      ),
      validators: [
        FormBuilderValidators.required(errorText: 'Navn må fylles inn'),
      ],
    );
  }

  Widget _buildJustificationField() {
    return FormBuilderTextField(
      maxLines: 5,
      autofocus: false,
      attribute: 'justification',
      initialValue: widget?.incident?.justification,
      decoration: new InputDecoration(
        hintText: 'Begrunnelse',
        filled: true,
        icon: new Icon(
          Icons.chat,
          color: Colors.grey,
        ),
      ),
      validators: [
        FormBuilderValidators.required(errorText: 'Begrunnelse må fylles inn'),
      ],
    );
  }

  Widget _buildTypeField() {
    return _buildDropDownField(
      attribute: 'type',
      label: 'Type hendelse',
      icon: SizedBox(width: 24, height: 24),
      initialValue: widget?.incident?.type ?? IncidentType.Lost,
      items: [
        [IncidentType.Lost, 'Savnet'],
        [IncidentType.Distress, 'Nødstedt'],
        [IncidentType.Other, 'Annet'],
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
      icon: SizedBox(width: 24, height: 24),
      initialValue: widget?.incident?.status ?? IncidentStatus.Registered,
      items: [
        [IncidentStatus.Registered, 'Registrert'],
        [IncidentStatus.Handling, 'Håndteres'],
        [IncidentStatus.Other, 'Annet'],
      ].map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}"))).toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Status må velges'),
      ],
    );
  }

  Widget _buildDropDownField<T>({
    @required String attribute,
    @required Widget icon,
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
                icon: icon,
                label: label,
                items: items,
              ),
        ),
        validators: validators,
      );

  Widget _buildDropdown<T>({
    @required FormFieldState<T> field,
    @required Widget icon,
    @required String label,
    @required List<DropdownMenuItem<T>> items,
  }) =>
      InputDecorator(
        decoration: InputDecoration(
          hasFloatingPlaceholder: true,
          icon: icon,
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
                    hasFloatingPlaceholder: true,
                    icon: SizedBox(width: 24, height: 24),
                    errorText: field.hasError ? field.errorText : null,
                    filled: true,
                    suffixIcon: Icon(Icons.map),
                  ),
                  child: Text(field.value == null ? 'Velg posisjon' : PointEditor.toDD(field.value),
                      style: Theme.of(context).textTheme.subhead),
                ),
                onTap: () => _selectLocation(context, field),
              ),
        ),
        validators: [
          FormBuilderValidators.required(errorText: 'Plassering må oppgis'),
        ],
      );

  _selectLocation(BuildContext context, FormFieldState<Point> field) async {
    final selected = await showDialog(
      context: context,
      builder: (context) => PointEditor(field.value, 'Velg plassering'),
    );
    if (selected != field.value) {
      field.didChange(selected);
    }
  }

//  Widget _buildTGField() {
//    final List<TalkGroup> groups = widget?.incident?.talkgroups ?? [];
//    return FormBuilderCustomField(
//      attribute: "talkgroup",
//      formField: FormField<List<TalkGroup>>(
//        enabled: true,
//        initialValue: groups,
//        builder: (FormFieldState<dynamic> field) {
//          return InputDecorator(
//            decoration: InputDecoration(
//                hasFloatingPlaceholder: true,
//                icon: SizedBox(width: 24, height: 24),
//                errorText: field.hasError ? field.errorText : null,
//                filled: true,
//                labelText: "Talkgroups",
//                prefixIcon: GestureDetector(
//                  child: Icon(Icons.delete),
//                  onTap: () => {},
//                )),
//            child: DropdownButtonHideUnderline(
//              child: ButtonTheme(
//                alignedDropdown: false,
//                child: DropdownButton<TalkGroup>(
//                  value: field.value,
//                  isDense: true,
//                  onChanged: (TalkGroup newValue) {
//                    field.didChange(newValue);
//                  },
//                  items: items,
//                ),
//              ),
//            ),
//          );
//        },
//      ),
//      validators: [
//        FormBuilderValidators.required(errorText: 'Status må velges'),
//      ],
//    );
//  }
}
