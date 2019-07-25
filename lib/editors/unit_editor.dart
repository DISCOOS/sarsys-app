import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class UnitEditor extends StatefulWidget {
  final Unit unit;

  const UnitEditor({Key key, this.unit}) : super(key: key);

  @override
  _UnitEditorState createState() => _UnitEditorState();
}

class _UnitEditorState extends State<UnitEditor> {
  static const SPACING = 16.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();

  UnitBloc bloc;
  TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    bloc = BlocProvider.of<UnitBloc>(context);
    _nameController = TextEditingController(
        text: widget?.unit?.name ?? "${translateUnitType(UnitType.Team)} ${bloc.units.length + 1}");
  }

  @override
  void dispose() {
    super.dispose();
    _nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.unit == null ? 'Ny enhet' : 'Endre enhet'),
        centerTitle: false,
        leading: GestureDetector(
          child: Icon(Icons.close),
          onTap: () {
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          FlatButton(
            child: Text(widget.unit == null ? 'OPPRETT' : 'OPPDATER',
                style: TextStyle(fontSize: 14.0, color: Colors.white)),
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            onPressed: () => _submit(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: FormBuilder(
          key: _formKey,
          onChanged: (values) {
            print("onChanged:$values");
          },
          child: ListView(
            children: <Widget>[
              _buildNameField(),
              SizedBox(height: SPACING),
              _buildTypeField(),
            ],
          ),
        ),
      ),
    );
  }

  FormBuilderTextField _buildNameField() {
    return FormBuilderTextField(
      maxLines: 1,
      autofocus: true,
      attribute: 'name',
      controller: _nameController,
      initialValue: widget?.unit?.name ?? "${translateUnitType(UnitType.Team)} ${bloc.units.length + 1}",
      decoration: InputDecoration(
        hintText: 'Navn',
        filled: true,
        suffixIcon: IconButton(
            icon: Icon(Icons.cancel),
            onPressed: () {
              _nameController.text =
                  widget?.unit?.name ?? "${translateUnitType(UnitType.Team)} ${bloc.units.length + 1}";
            }),
      ),
      validators: [
        FormBuilderValidators.required(errorText: 'Navn må fylles inn'),
      ],
    );
  }

  Widget _buildTypeField() {
    return buildDropDownField(
      attribute: 'type',
      label: 'Type hendelse',
      initialValue: enumName(widget?.unit?.type ?? UnitType.Team),
      items: UnitType.values
          .map((type) => [enumName(type), translateUnitType(type)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Type må velges'),
      ],
    );
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState.validate()) {
      var unit;
      _formKey.currentState.save();
      if (widget.unit == null) {
        Navigator.pop(context, Unit.fromJson(_formKey.currentState.value));
      } else {
        unit = widget.unit.withJson(_formKey.currentState.value);
        Navigator.pop(context, unit);
      }
    } else {
      // Show errors
      setState(() {});
    }
  }
}
