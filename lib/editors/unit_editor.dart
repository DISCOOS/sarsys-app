import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:intl/intl.dart';
import 'package:SarSys/blocs/app_config_bloc.dart';
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
  final Iterable<Device> devices;

  const UnitEditor({Key key, this.unit, this.devices = const []}) : super(key: key);

  @override
  _UnitEditorState createState() => _UnitEditorState();
}

class _UnitEditorState extends State<UnitEditor> {
  static const SPACING = 16.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();
  final _callsignController = TextEditingController();
  final Map<String, String> _departments = {};

  String _editedName;
  UnitBloc _unitBloc;
  DeviceBloc _deviceBloc;
  TrackingBloc _trackingBloc;
  AppConfigBloc _appConfigBloc;

  @override
  void initState() {
    super.initState();
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _appConfigBloc = BlocProvider.of<AppConfigBloc>(context);
    _init();
  }

  void _init() async {
    _departments.addAll(await AssetsService().fetchAllDepartments(Defaults.orgId));
    setState(() {});
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
                _buildNameAndNumber(),
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
                SizedBox(height: MediaQuery.of(context).size.height / 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Row _buildNameAndNumber() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 6,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: "Navn",
              filled: true,
              enabled: false,
            ),
            child: Text(_editedName ??
                widget?.unit?.name ??
                "${translateUnitType(UnitType.Team)} ${_unitBloc.units.length + 1}"),
          ),
        ),
        SizedBox(width: SPACING),
        Expanded(flex: 6, child: _buildNumberField()),
      ],
    );
  }

  FormBuilderTextField _buildNumberField() {
    final actualValue = widget?.unit?.number ?? _unitBloc.units.length + 1;
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'number',
      maxLength: 2,
      maxLengthEnforced: true,
      initialValue: "$actualValue",
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
      valueTransformer: (value) => int.tryParse(value) ?? actualValue,
    );
  }

  FormBuilderTextField _buildCallsignField() {
    final defaultValue = _getDefaultCallSign();
    final actualValue = _getActualCallSign(defaultValue);
    _callsignController.text = actualValue;
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'callsign',
      autofocus: true,
      initialValue: actualValue,
      controller: _callsignController,
      decoration: InputDecoration(
        hintText: 'Skriv inn',
        filled: true,
        labelText: 'Kallesignal',
        suffix: GestureDetector(
          child: Icon(Icons.clear, color: Colors.grey),
          onTap: () {
            _callsignController.text = _getDefaultCallSign();
            _formKey.currentState.save();
          },
        ),
      ),
      keyboardType: TextInputType.text,
      validators: [
        FormBuilderValidators.required(errorText: 'Kallesignal må fylles inn'),
        (value) {
          Unit unit = _unitBloc.units.values.firstWhere(
            (Unit unit) => unit != widget.unit && _isSameCallsign(value as String, unit.callsign),
            orElse: () => null,
          );
          return unit != null ? "${unit.name} har samme kallesignal" : null;
        },
      ],
    );
  }

  bool _isSameCallsign(String callsign1, String callsign2) {
    return callsign1.toLowerCase().replaceAll(RegExp(r'\s|-'), '') ==
        callsign2.toLowerCase().replaceAll(RegExp(r'\s|-'), '');
  }

  FormBuilderTextField _buildPhoneField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'phone',
      maxLength: 8,
      maxLengthEnforced: true,
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
    final devices = (widget?.unit?.tracking != null
        ? _trackingBloc.getDevicesFromTrackingId(widget?.unit?.tracking)
        : [])
      ..addAll(widget.devices);
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

  void _submit(BuildContext context) async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      List<Device> devices = List<Device>.from(_formKey.currentState.value["devices"]);
      var unit = widget.unit == null
          ? Unit.fromJson(_formKey.currentState.value)
          : widget.unit.withJson(_formKey.currentState.value);
      Navigator.pop(context, await _apply(unit, devices));
    } else {
      // Show errors
      setState(() {});
    }
  }

  Future<UnitEditorResult> _apply(Unit unit, List<Device> devices) async {
    if (widget.unit == null) {
      unit = await _unitBloc.create(unit);
    } else {
      await _unitBloc.update(unit);
    }
    if (unit.tracking == null) {
      _trackingBloc.create(unit, devices);
    } else if (_trackingBloc.tracks.containsKey(unit.tracking)) {
      var tracking = _trackingBloc.tracks[unit.tracking];
      _trackingBloc.update(tracking, devices: devices);
    }
    return UnitEditorResult(unit, devices);
  }

  final _callsignFormat = NumberFormat("00")..maximumFractionDigits = 0;

  String _getActualCallSign(String defaultValue) {
    final values = _formKey?.currentState?.value;
    return (values == null ? widget?.unit?.callsign ?? defaultValue : values['callsign']) ??
        widget?.unit?.callsign ??
        defaultValue;
  }

  String _getDefaultCallSign() {
    final String department = _departments[_appConfigBloc.config.department];
    int number = _ensureCallSignSuffix();
    final suffix = "${_callsignFormat.format(number % 10 == 0 ? ++number : number)}";
    return "$department ${suffix.substring(0, 1)}-${suffix.substring(1, 2)}";
  }

  int _ensureCallSignSuffix() {
    final count = _unitBloc.units.length;
    final values = _formKey?.currentState?.value;
    // TODO: Use number plan in fleet map (units use range 21 - 89, except all 'x0' numbers)
    final number = ((values == null ? (widget?.unit?.number ?? count + 1) : values['number']) ??
        widget?.unit?.number ??
        count + 1);
    return 20 + number;
  }
}

class UnitEditorResult {
  final Unit unit;
  final List<Device> devices;

  UnitEditorResult(this.unit, this.devices);
}
