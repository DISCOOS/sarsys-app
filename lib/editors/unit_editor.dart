import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/device.dart';
import 'package:SarSys/widgets/personnel.dart';
import 'package:SarSys/widgets/point_field.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class UnitEditor extends StatefulWidget {
  final Unit unit;
  final Point point;
  final Iterable<Device> devices;
  final Iterable<Personnel> personnel;
  final PermissionController controller;

  final UnitType type;

  const UnitEditor({
    Key key,
    @required this.controller,
    this.unit,
    this.point,
    this.type = UnitType.Team,
    this.devices = const [],
    this.personnel = const [],
  }) : super(key: key);

  @override
  _UnitEditorState createState() => _UnitEditorState();
}

class _UnitEditorState extends State<UnitEditor> {
  static const SPACING = 16.0;

  final Map<String, String> _departments = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();

  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _callsignController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<Device> _devices;
  List<Personnel> _personnel;

  String _editedName;
  UnitBloc _unitBloc;
  DeviceBloc _deviceBloc;
  TrackingBloc _trackingBloc;
  AppConfigBloc _appConfigBloc;
  PersonnelBloc _personnelBloc;

  @override
  void initState() {
    super.initState();
    _set();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _set();
  }

  void _set() {
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _appConfigBloc = BlocProvider.of<AppConfigBloc>(context);
    _personnelBloc = BlocProvider.of<PersonnelBloc>(context);
    _devices ??= _getActualDevices();
    _personnel ??= _getActualPersonnel();
  }

  void _init() async {
    _departments.addAll(await FleetMapService().fetchAllDepartments(Defaults.orgId));
    _initPhoneController();
    _initNumberController();
    _initCallsignController();
    if (mounted) setState(() {});
  }

  void _initCallsignController() {
    _setText(_callsignController, _defaultCallSign());
  }

  void _initNumberController() {
    _setText(_numberController, _defaultNumber());
    _numberController.addListener(
      () => _onTypeOrNumberEdit(
        translateUnitType(_actualType(widget.type)),
        _numberController.text,
        true,
      ),
    );
  }

  void _initPhoneController() {
    _setText(_phoneController, _defaultPhone());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
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
            onPressed: () => _submit(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                _buildPersonnelListField(),
                SizedBox(height: SPACING),
                _buildDeviceListField(),
                SizedBox(height: SPACING),
                _buildPointField(),
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
          _editedName ?? _defaultName(),
          style: Theme.of(context).textTheme.subhead,
        ),
      ),
    );
  }

  String _defaultName() => widget?.unit?.name ?? "${translateUnitType(widget.type)} ${_defaultNumber()}";

  FormBuilderTextField _buildNumberField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'number',
      maxLength: 2,
      maxLengthEnforced: true,
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
            _defaultNumber(),
          ),
        ),
      ),
      autovalidate: true,
      inputFormatters: [
        WhitelistingTextInputFormatter.digitsOnly,
      ],
      keyboardType: TextInputType.number,
      valueTransformer: (value) => int.tryParse(emptyAsNull(value) ?? _defaultNumber()),
      validators: [
        FormBuilderValidators.required(errorText: 'Må fylles inn'),
        FormBuilderValidators.numeric(errorText: "Må være et nummer"),
        _validateNumber,
      ],
    );
  }

  String _validateNumber(number) {
    Unit unit = _unitBloc.units.values
        .where(
          (unit) => widget.unit?.id != unit.id && UnitStatus.Retired != unit.status,
        )
        .firstWhere(
          (Unit unit) => isSameNumber(unit, number),
          orElse: () => null,
        );
    return unit != null ? "Lag $number finnes allerede" : null;
  }

  bool isSameNumber(Unit unit, number) =>
      number?.isNotEmpty == true && unit != widget.unit && unit.number == int.tryParse(number);

  FormBuilderTextField _buildCallsignField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'callsign',
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
          onTap: () => _setText(
            _callsignController,
            _defaultCallSign(),
          ),
        ),
      ),
      autovalidate: true,
      keyboardType: TextInputType.text,
      valueTransformer: (value) => emptyAsNull(value),
      validators: [
        FormBuilderValidators.required(errorText: 'Må fylles inn'),
        _validateCallsign,
      ],
    );
  }

  String _validateCallsign(callsign) {
    Unit unit = _unitBloc.units.values
        .where(
          (unit) => UnitStatus.Retired != unit.status,
        )
        .firstWhere(
          (Unit unit) => _isSameCallsign(unit, callsign),
          orElse: () => null,
        );
    return unit != null ? "${unit.name} har samme" : null;
  }

  bool _isSameCallsign(Unit unit, String callsign) {
    return callsign?.isNotEmpty == true &&
        unit?.id != widget?.unit?.id &&
        unit?.callsign?.toLowerCase()?.replaceAll(RegExp(r'\s|-'), '') ==
            callsign?.toLowerCase()?.replaceAll(RegExp(r'\s|-'), '');
  }

  FormBuilderTextField _buildPhoneField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'phone',
      maxLength: 12,
      maxLengthEnforced: true,
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
          onTap: () => _setText(
            _phoneController,
            _defaultPhone(),
          ),
        ),
      ),
      autovalidate: true,
      inputFormatters: [
        WhitelistingTextInputFormatter.digitsOnly,
      ],
      keyboardType: TextInputType.number,
      valueTransformer: (value) => emptyAsNull(value),
      validators: [
        _validatePhone,
        FormBuilderValidators.numeric(errorText: "Kun talltegn"),
        (value) => emptyAsNull(value) != null
            ? FormBuilderValidators.minLength(8, errorText: "Minimum åtte tegn")(value)
            : null,
      ],
    );
  }

  String _validatePhone(phone) {
    Unit unit = _unitBloc.units.values
        .where(
          (unit) => UnitStatus.Retired != unit.status,
        )
        .firstWhere(
          (Unit unit) => _isSamePhone(unit, phone),
          orElse: () => null,
        );
    return unit != null ? "${unit.name} har samme" : null;
  }

  bool _isSamePhone(Unit unit, String phone) {
    return phone?.isNotEmpty == true &&
        unit?.id != widget?.unit?.id &&
        unit?.phone?.toLowerCase()?.replaceAll(RegExp(r'\s|-'), '') ==
            phone?.toLowerCase()?.replaceAll(RegExp(r'\s|-'), '');
  }

  void _setText(TextEditingController controller, String value) {
    setText(controller, value);
    _formKey?.currentState?.save();
  }

  void _onTypeOrNumberEdit(String type, String number, bool update) {
    _formKey?.currentState?.save();
    if (type.isEmpty) type = translateUnitType(widget.type);
    if (number.isEmpty) number = "${_nextNumber()}";
    _editedName = "$type $number";
    if (update) setState(() {});
  }

  Widget _buildTypeField() {
    final actualValue = _actualType(widget.type);
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
      onChanged: (value) => _onTypeOrNumberEdit(
        translateUnitType(UnitType.values.firstWhere(
          (test) => enumName(test) == value,
          orElse: () => widget.type,
        )),
        _actualNumber(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
      child: FormBuilderChipsInput(
        attribute: 'devices',
        maxChips: 5,
        initialValue: _getActualDevices(),
        onChanged: (devices) => _devices = List.from(devices),
        decoration: InputDecoration(
          labelText: "Apparater",
          hintText: "Søk etter apparater",
          helperText: "Posisjon til apparater blir lagret",
          filled: true,
          contentPadding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
        ),
        findSuggestions: _findDevices,
        chipBuilder: (context, state, device) => DeviceChip(
          device: device,
          state: state,
        ),
        suggestionBuilder: (context, state, device) => DeviceTile(
          device: device,
          state: state,
        ),
        valueTransformer: (values) => values.map((device) => device).toList(),
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

  List<Device> _findDevices(String query) {
    if (query.length != 0) {
      var actual = _getActualDevices().map((device) => device.id);
      var local = _getLocalDevices().map((device) => device.id);
      var lowercaseQuery = query.toLowerCase();
      return _deviceBloc.devices.values
          .where((device) =>
              // Add locally removed devices
              actual.contains(device.id) && !local.contains(device.id) || _trackingBloc.contains(device) == false)
          .where((device) =>
              device.number.toLowerCase().contains(lowercaseQuery) ||
              device.type.toString().toLowerCase().contains(lowercaseQuery))
          .take(5)
          .toList(growable: false);
    }
    return const <Device>[];
  }

  Widget _buildPersonnelListField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
      child: FormBuilderChipsInput(
        attribute: 'personnel',
        maxChips: 15,
        initialValue: _getActualPersonnel(),
        onChanged: (personnel) => _personnel = List.from(personnel),
        decoration: InputDecoration(
          labelText: "Mannskap",
          hintText: "Søk etter mannskap",
          helperText: "Posisjon til mannskap blir lagret",
          filled: true,
          contentPadding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
        ),
        findSuggestions: _findPersonnel,
        chipBuilder: (context, state, personnel) => PersonnelChip(
          personnel: personnel,
          state: state,
        ),
        suggestionBuilder: (context, state, personnel) => PersonnelTile(
          personnel: personnel,
          state: state,
        ),
        valueTransformer: (values) => values.map((personnel) => personnel.toJson()).toList(),
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

  List<Personnel> _findPersonnel(String query) {
    if (query.length != 0) {
      var actual = _getActualPersonnel().map((personnel) => personnel.id);
      var local = _getLocalPersonnel().map((personnel) => personnel.id);
      var lowercaseQuery = query.toLowerCase();
      return _personnelBloc.personnel.values
          .where((personnel) =>
              // Add locally removed devices
              actual.contains(personnel.id) && !local.contains(personnel.id) ||
              _trackingBloc.aggregates.elementAt(personnel.tracking) == null)
          .where((personnel) =>
              personnel.name.toLowerCase().contains(lowercaseQuery) ||
              translatePersonnelStatus(personnel.status).toLowerCase().contains(lowercaseQuery))
          .take(5)
          .toList(growable: false);
    }
    return const <Personnel>[];
  }

  Widget _buildPointField() {
    final point = _toPoint();
    return PointField(
      attribute: 'point',
      initialValue: point,
      labelText: "Siste posisjon",
      hintText: 'Velg posisjon',
      errorText: 'Posisjon må oppgis',
      helperText: _toTrackingHelperText(point),
      controller: widget.controller,
      onChanged: (point) => setState(() {}),
    );
  }

  String _toTrackingHelperText(Point point) {
    return point != null
        ? (PointType.Manual == point.type
            ? 'Manuell lagt inn.'
            : 'Gjennomsnitt av siste posisjoner fra mannskap og apparater.')
        : '';
  }

  Point _toPoint() {
    final bloc = BlocProvider.of<TrackingBloc>(context);
    final tracking = bloc.tracking[widget?.unit?.tracking];
    return tracking?.point ?? widget.point;
  }

  List<Device> _getLocalDevices() => List.from(_devices ?? <Device>[]);

  List<Device> _getActualDevices() {
    return (widget?.unit?.tracking != null ? _trackingBloc.devices(widget?.unit?.tracking,
        // Include closed tracks
        exclude: []) : [])
      ..toList()
      ..addAll(widget.devices ?? []);
  }

  List<Personnel> _getLocalPersonnel() => List.from(_personnel ?? <Device>[]);

  List<Personnel> _getActualPersonnel() {
    return (widget?.unit?.personnel ?? []).toList()..addAll(widget.personnel ?? []);
  }

  Point _preparePoint() {
    final point = _formKey.currentState.value["point"] == null
        ? null
        : Point.fromJson(
            _formKey.currentState.value["point"],
          );
    // Only manually added points are allowed
    return PointType.Manual == point?.type ? point : null;
  }

  String _defaultNumber() {
    return "${widget?.unit?.number ?? _nextNumber()}";
  }

  int _nextNumber() {
    return _unitBloc.nextAvailableNumber(_appConfigBloc.config.callsignReuse);
  }

  String _actualNumber() {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('number') == true
        ? "${values['number']}" ?? "${widget?.unit?.number ?? _numberController.text}"
        : "${widget?.unit?.number ?? _numberController.text}";
  }

  UnitType _actualType(UnitType defaultValue) {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('type') == true
        ? Unit.fromJson(values).type ?? widget?.unit?.type ?? defaultValue
        : widget?.unit?.type ?? defaultValue;
  }

  String _defaultCallSign() {
    return "${widget?.unit?.callsign ?? _nextCallSign()}";
  }

  String _nextCallSign() {
    final String department = _departments[_appConfigBloc.config.depId];
    int number = _ensureCallSignSuffix();
    return toCallsign(department, number);
  }

  int _ensureCallSignSuffix() {
    final next = _nextNumber();
    final values = _formKey?.currentState?.value;
    final number = values?.containsKey('number') == true
        ? values['number'] ?? widget?.unit?.number ?? next
        : widget?.unit?.number ?? next;
    return 20 + number;
  }

  String _defaultPhone() {
    return widget?.unit?.phone;
  }

  void _submit() async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      var unit = widget.unit == null
          // Filter out empty text
          ? Unit.fromJson(_formKey.currentState.value)
          : widget.unit.withJson(_formKey.currentState.value);
      var response = true;
      if (UnitStatus.Retired == unit.status && unit.status != widget?.unit?.status) {
        response = await prompt(
          context,
          "Oppløs ${unit.name}",
          "Dette vil stoppe sporing og oppløse enheten. Vil du fortsette?",
        );
      }
      if (response) {
        Navigator.pop(
          context,
          UnitParams(
            unit: unit,
            devices: _devices,
            personnel: _personnel,
            point: _preparePoint(),
          ),
        );
      }
    } else {
      // Show errors
      setState(() {});
    }
  }
}
