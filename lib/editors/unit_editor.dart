import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Device.dart';
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

  String _editedName;
  UnitBloc _unitBloc;
  DeviceBloc _deviceBloc;
  TrackingBloc _trackingBloc;

  @override
  void initState() {
    super.initState();
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
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
        child: SingleChildScrollView(
          child: FormBuilder(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Expanded(
                      flex: 6,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Navn",
                          filled: true,
                          enabled: false,
                        ),
                        child: Text(_editedName ?? widget?.unit?.name),
                      ),
                    ),
                    SizedBox(width: SPACING),
                    Expanded(flex: 6, child: _buildNumberField()),
                  ],
                ),
                SizedBox(height: SPACING),
                _buildTypeField(),
                SizedBox(height: SPACING),
                _buildCallsignField(),
                SizedBox(height: SPACING),
                _buildPhoneField(),
                SizedBox(height: SPACING),
                _buildStatusField(),
                SizedBox(height: SPACING),
                _buildDeviceListField(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FormBuilderTextField _buildNumberField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'number',
      initialValue: (widget?.unit?.number ?? "${_unitBloc.units.length + 1}").toString(),
      onChanged: (_) => _onEdit(),
      decoration: InputDecoration(
        hintText: 'Skriv inn',
        filled: true,
        labelText: 'Nummer',
      ),
      keyboardType: TextInputType.numberWithOptions(),
      validators: [
        FormBuilderValidators.required(errorText: 'Nummer må fylles inn'),
        FormBuilderValidators.numeric(errorText: "Verdi må være et nummer"),
        (value) {
          // TODO: Check if number is unique
          return null;
        },
      ],
      valueTransformer: (value) => int.parse(value),
    );
  }

  FormBuilderTextField _buildCallsignField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'callsign',
      initialValue: (widget?.unit?.callsign ?? "").toString(),
      decoration: InputDecoration(
        hintText: 'Skriv inn',
        filled: true,
        labelText: 'Kallesignal',
      ),
      keyboardType: TextInputType.text,
      validators: [
        FormBuilderValidators.required(errorText: 'Kallesignal må fylles inn'),
        (value) {
          // TODO: Check if callsign is unique
          return null;
        },
      ],
    );
  }

  FormBuilderTextField _buildPhoneField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'phone',
      initialValue: (widget?.unit?.phone ?? "").toString(),
      decoration: InputDecoration(
        hintText: 'Skriv inn',
        filled: true,
        labelText: 'Mobiltelefon',
      ),
      keyboardType: TextInputType.phone,
    );
  }

  void _onEdit() {
    return setState(() {
      _formKey.currentState.save();
      var unit = Unit.fromJson(_formKey.currentState.value);
      _editedName = "${translateUnitType(unit.type)} ${unit.number}";
      print("edit: $unit");
    });
  }

  Widget _buildTypeField() {
    return buildDropDownField(
      attribute: 'type',
      label: 'Type enhet',
      initialValue: enumName(widget?.unit?.type ?? UnitType.Team),
      items: UnitType.values
          .map((type) => [enumName(type), translateUnitType(type)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Type må velges'),
      ],
      onChanged: (_) => _onEdit(),
    );
  }

  Widget _buildStatusField() {
    return buildDropDownField(
      attribute: 'status',
      label: 'Status',
      initialValue: enumName(widget?.unit?.status ?? UnitStatus.Mobilized),
      items: UnitStatus.values
          .map((status) => [enumName(status), translateUnitStatus(status)])
          .map((status) => DropdownMenuItem(value: status[0], child: Text("${status[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Status må velges'),
      ],
    );
  }

  Widget _buildDeviceListField() {
    final style = Theme.of(context).textTheme.caption;
    final devices = _trackingBloc.devices(widget?.unit?.tracking);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
      child: FormBuilderChipsInput(
        attribute: 'devices',
        maxChips: 5,
        initialValue: devices,
        decoration: InputDecoration(
          labelText: "Sporing",
          hintText: "Søk etter terminaler",
          filled: true,
          contentPadding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
        ),
        findSuggestions: (String query) async {
          if (query.length != 0) {
            var lowercaseQuery = query.toLowerCase();
            return _deviceBloc.devices.values
                .where((device) {
                  return device.number.toLowerCase().contains(lowercaseQuery) ||
                      device.type.toString().toLowerCase().contains(lowercaseQuery);
                })
                .take(5)
                .toList(growable: false);
          } else {
            return const <Device>[];
          }
        },
        chipBuilder: (context, state, device) {
          return InputChip(
            key: ObjectKey(device),
            label: Text(device.number, style: style),
            onDeleted: () => state.deleteChip(device),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
        suggestionBuilder: (context, state, device) {
          return ListTile(
            key: ObjectKey(device),
            leading: CircleAvatar(
              child: Text(enumName(device.type).substring(0, 1)),
            ),
            title: Text(device.number),
            onTap: () => state.selectSuggestion(device),
          );
        },
        valueTransformer: (values) => values.map((device) => device).toList(),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      List<Device> devices = List<Device>.from(_formKey.currentState.value["devices"]);
      var unit = widget.unit == null
          ? Unit.fromJson(_formKey.currentState.value)
          : widget.unit.withJson(_formKey.currentState.value);
      Navigator.pop(context, _apply(unit, devices));
    } else {
      // Show errors
      setState(() {});
    }
  }

  UnitEditorResult _apply(Unit unit, List<Device> devices) {
    if (widget.unit == null) {
      _unitBloc.create(unit);
    } else {
      _unitBloc.update(unit);
    }
    if (unit.tracking == null) {
      _trackingBloc.create(unit, devices);
    } else if (_trackingBloc.tracks.containsKey(unit.tracking)) {
      var tracking = _trackingBloc.tracks[unit.tracking];
      _trackingBloc.update(tracking, devices: devices);
    }
    return UnitEditorResult(unit, devices);
  }
}

class UnitEditorResult {
  final Unit unit;
  final List<Device> devices;

  UnitEditorResult(this.unit, this.devices);
}
