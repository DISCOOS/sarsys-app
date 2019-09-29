import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/core/defaults.dart';
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

  final Map<String, String> _departments = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();

  final _numberController = TextEditingController();
  final _callsignController = TextEditingController();
  final _phoneController = TextEditingController();

  String _editedName;
  UnitBloc _unitBloc;
  DeviceBloc _deviceBloc;
  TrackingBloc _trackingBloc;
  AppConfigBloc _appConfigBloc;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _appConfigBloc = BlocProvider.of<AppConfigBloc>(context);
  }

  void _init() async {
    _departments.addAll(await AssetsService().fetchAllDepartments(Defaults.orgId));
    if (mounted) setState(() {});
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
                buildTwoCellRow(_buildNameField(), _buildNumberField(), spacing: SPACING),
                SizedBox(height: SPACING),
                buildTwoCellRow(_buildTypeField(), _buildCallsignField(), spacing: SPACING),
                SizedBox(height: SPACING),
                buildTwoCellRow(_buildStatusField(), _buildPhoneField(), spacing: SPACING),
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

  InputDecorator _buildNameField() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "Navn",
        filled: true,
        enabled: false,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          _editedName ?? widget?.unit?.name ?? "${translateUnitType(UnitType.Team)} ${_unitBloc.units.length + 1}",
          style: Theme.of(context).textTheme.subhead,
        ),
      ),
    );
  }

  FormBuilderTextField _buildNumberField() {
    final actualType = _getActualType(UnitType.Team);
    final defaultNumber = _getDefaultNumber(actualType);
    final actualNumber = _getActualNumber(defaultNumber);
    _numberController.text = "$actualNumber";
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'number',
      maxLength: 2,
      maxLengthEnforced: true,
      initialValue: "$actualNumber",
      onChanged: (number) => _onTypeOrNumberEdit(
        enumName(_getActualType(UnitType.Team)),
        number,
        false,
      ),
      onEditingComplete: () => setState(() {}),
      controller: _numberController,
      decoration: InputDecoration(
        hintText: 'Skriv inn',
        filled: true,
        labelText: 'Nummer',
        suffix: GestureDetector(
          child: Icon(
            Icons.clear,
            color: Colors.grey,
            size: 20,
          ),
          onTap: () => _setText(
            _numberController,
            "${_getActualNumber(_getDefaultNumber(_getActualType(UnitType.Team)))}",
          ),
        ),
      ),
      keyboardType: TextInputType.numberWithOptions(),
      validators: [
        FormBuilderValidators.required(errorText: 'Nummer må fylles inn'),
        FormBuilderValidators.numeric(errorText: "Verdi må være et nummer"),
        (value) {
          Unit unit = _unitBloc.units.values.firstWhere(
            (Unit unit) => unit != widget.unit && unit.number == value,
            orElse: () => null,
          );
          return unit != null ? "Lag $value finnes allerede" : null;
        },
      ],
      valueTransformer: (value) => int.tryParse(value) ?? actualNumber,
    );
  }

  FormBuilderTextField _buildCallsignField() {
    final defaultValue = _getDefaultCallSign();
    final actualValue = _getActualCallSign(defaultValue);
    _callsignController.text = actualValue;
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'callsign',
      initialValue: actualValue,
      controller: _callsignController,
      decoration: InputDecoration(
        hintText: 'Skriv inn',
        filled: true,
        labelText: 'Kallesignal',
        suffix: GestureDetector(
          child: Icon(
            Icons.clear,
            color: Colors.grey,
            size: 20,
          ),
          onTap: () => _setText(_callsignController, _getDefaultCallSign()),
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
          return unit != null ? "${unit.name} har kallesignal $value" : null;
        },
      ],
    );
  }

  bool _isSameCallsign(String callsign1, String callsign2) {
    return callsign1.toLowerCase().replaceAll(RegExp(r'\s|-'), '') ==
        callsign2.toLowerCase().replaceAll(RegExp(r'\s|-'), '');
  }

  FormBuilderTextField _buildPhoneField() {
    final value = (widget?.unit?.phone ?? "").toString();
    _phoneController.text = value;
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'phone',
      maxLength: 8,
      maxLengthEnforced: true,
      autofocus: true,
      initialValue: value,
      controller: _phoneController,
      decoration: InputDecoration(
        filled: true,
        hintText: 'Skriv inn',
        labelText: 'Mobiltelefon',
        suffix: GestureDetector(
          child: Icon(
            Icons.clear,
            color: Colors.grey,
            size: 20,
          ),
          onTap: () => _setText(_phoneController, value),
        ),
      ),
      keyboardType: TextInputType.phone,
    );
  }

  void _setText(TextEditingController controller, String value) {
    // Workaround for errors when clearing TextField,
    // see https://github.com/flutter/flutter/issues/17647
    if (value.isEmpty)
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.clear());
    else
      controller.text = value;
    _formKey.currentState.save();
  }

  void _onTypeOrNumberEdit(String type, number, bool update) {
    _formKey.currentState.save();
    var unit = Unit.fromJson(_formKey.currentState.value);
    // Type changed?
    if (enumName(unit.type) != type) {
      number = _getDefaultNumber(unit.type);
      _setText(_numberController, "$number");
    }
    _editedName = "${translateUnitType(unit.type)} ${number ?? _getDefaultNumber(unit.type)}";
    if (update) setState(() {});
  }

  Widget _buildTypeField() {
    final defaultValue = UnitType.Team;
    final actualValue = _getActualType(defaultValue);
    return buildDropDownField(
      attribute: 'type',
      label: 'Type enhet',
      initialValue: enumName(actualValue),
      items: UnitType.values
          .map((type) => [enumName(type), translateUnitType(type)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Type må velges'),
      ],
      onChanged: (_) => _onTypeOrNumberEdit(
        enumName(actualValue),
        _formKey.currentState.value["number"],
        true,
      ),
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
        ? _trackingBloc.getDevicesFromTrackingId(
            widget?.unit?.tracking,
            // Include closed tracks
            exclude: [],
          )
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
          hintText: "Søk etter apparater",
          filled: true,
          contentPadding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
        ),
        findSuggestions: (String query) async {
          if (query.length != 0) {
            var lowercaseQuery = query.toLowerCase();
            return _deviceBloc.devices.values
                .where((devices) => _trackingBloc.isTrackingDeviceById(devices.id) == false)
                .where((device) =>
                    device.number.toLowerCase().contains(lowercaseQuery) ||
                    device.type.toString().toLowerCase().contains(lowercaseQuery))
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
      Navigator.pop(context, UnitEditorResult(unit, devices));
    } else {
      // Show errors
      setState(() {});
    }
  }

  int _getDefaultNumber(UnitType type) {
    return _unitBloc.units.length + 1;
    //return _unitBloc.units.values.where((unit) => type == unit.type).length + 1;
  }

  int _getActualNumber(int defaultValue) {
    final values = _formKey?.currentState?.value;
    return (values == null ? widget?.unit?.number ?? defaultValue : values['number']) ??
        widget?.unit?.number ??
        defaultValue;
  }

  UnitType _getActualType(UnitType defaultValue) {
    final values = _formKey?.currentState?.value;
    return (values == null ? widget?.unit?.type ?? defaultValue : Unit.fromJson(values).type) ??
        widget?.unit?.type ??
        defaultValue;
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
