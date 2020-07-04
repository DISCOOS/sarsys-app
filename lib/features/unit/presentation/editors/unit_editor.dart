import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/utils/tracking_utils.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:SarSys/features/personnel/presentation/widgets/personnel_widgets.dart';
import 'package:SarSys/widgets/position_field.dart';

class UnitEditor extends StatefulWidget {
  final Unit unit;
  final Position position;
  final Iterable<Device> devices;
  final Iterable<Personnel> personnels;

  final UnitType type;

  const UnitEditor({
    Key key,
    this.unit,
    this.position,
    this.type = UnitType.team,
    this.devices = const [],
    this.personnels = const [],
  }) : super(key: key);

  @override
  _UnitEditorState createState() => _UnitEditorState();
}

class _UnitEditorState extends State<UnitEditor> {
  static const SPACING = 16.0;

//  final Map<String, String> _departments = {};

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();

  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _callsignController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<Device> _devices;
  List<Personnel> _personnels;

  String _editedName;

  @override
  void initState() {
    super.initState();
    _set();
    _init();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _callsignController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _set();
  }

  void _set() {
    _devices ??= _getActualDevices();
    _personnels ??= _getActualPersonnel();
  }

  void _init() async {
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
        _actualType(widget.type),
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
      resizeToAvoidBottomInset: true,
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
                _buildPositionField(),
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
          style: Theme.of(context).textTheme.subtitle2,
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
    final type = _actualType(widget.type);
    Unit unit = context
        .bloc<UnitBloc>()
        .units
        .values
        .where(
          (unit) => widget.unit?.uuid != unit.uuid,
        )
        .where(
          (unit) => UnitStatus.retired != unit.status,
        )
        .firstWhere(
          (Unit unit) => isSameNumber(unit, type, number),
          orElse: () => null,
        );
    return unit != null ? "Lag $number finnes allerede" : null;
  }

  bool isSameNumber(Unit unit, UnitType type, String number) =>
      unit != widget.unit && unit.type == type && unit.number == int.tryParse(number);

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
    Unit unit = context
        .bloc<UnitBloc>()
        .units
        .values
        .where(
          (unit) => UnitStatus.retired != unit.status,
        )
        .firstWhere(
          (Unit unit) => _isSameCallsign(unit, callsign),
          orElse: () => null,
        );
    return unit != null ? "${unit.name} har samme" : null;
  }

  bool _isSameCallsign(Unit unit, String callsign) {
    return callsign?.isNotEmpty == true &&
        unit?.uuid != widget?.unit?.uuid &&
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
    Unit unit = context
        .bloc<UnitBloc>()
        .units
        .values
        .where(
          (unit) => UnitStatus.retired != unit.status,
        )
        .firstWhere(
          (Unit unit) => _isSamePhone(unit, phone),
          orElse: () => null,
        );
    return unit != null ? "${unit.name} har samme" : null;
  }

  bool _isSamePhone(Unit unit, String phone) {
    return phone?.isNotEmpty == true &&
        unit?.uuid != widget?.unit?.uuid &&
        unit?.phone?.toLowerCase()?.replaceAll(RegExp(r'\s|-'), '') ==
            phone?.toLowerCase()?.replaceAll(RegExp(r'\s|-'), '');
  }

  void _setText(TextEditingController controller, String value) {
    setText(controller, value);
    _formKey?.currentState?.save();
  }

  void _onTypeOrNumberEdit(UnitType type, String number, bool update) {
    _formKey?.currentState?.save();
    final name = translateUnitType(type ?? widget.type);
    if (number.isEmpty) number = "${_nextNumber(type ?? widget.type)}";
    _editedName = "$name $number";
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
        UnitType.values.firstWhere(
          (test) => enumName(test) == value,
          orElse: () => widget.type,
        ),
        _actualNumber(),
        true,
      ),
    );
  }

  Widget _buildStatusField() {
    return buildDropDownField(
      attribute: 'status',
      label: 'Status',
      initialValue: enumName(widget?.unit?.status ?? UnitStatus.mobilized),
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
        textStyle: TextStyle(height: 1.8, fontSize: 16.0),
        inputType: TextInputType.text,
        keyboardAppearance: Brightness.dark,
        inputAction: TextInputAction.done,
        autocorrect: true,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  List<Device> _findDevices(String query) {
    if (query.length != 0) {
      var actual = _getActualDevices().map((device) => device.uuid);
      var local = _getLocalDevices().map((device) => device.uuid);
      var lowercaseQuery = query.toLowerCase();
      return context
          .bloc<DeviceBloc>()
          .devices
          .values
          .where((device) =>
              // Add locally removed devices
              _canAddDevice(
                actual,
                device,
                local,
              ))
          .where((device) =>
              device.number.toLowerCase().contains(lowercaseQuery) ||
              device.type.toString().toLowerCase().contains(lowercaseQuery))
          .take(5)
          .toList(growable: false);
    }
    return const <Device>[];
  }

  /*

    bool _canAddPersonnel(
      Iterable<String> actual, Personnel personnel, Iterable<String> local, TrackableQuery<Unit> units) {
    return actual.contains(personnel.uuid) && !local.contains(personnel.uuid) || units.find(personnel) == null;
  }


   */

  bool _canAddDevice(Iterable<String> actual, Device device, Iterable<String> local) {
    return actual.contains(device.uuid) && !local.contains(device.uuid) || !context.bloc<TrackingBloc>().has(device);
  }

  Widget _buildPersonnelListField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
      child: FormBuilderChipsInput(
        attribute: 'personnels',
        maxChips: 15,
        initialValue: _getActualPersonnel(),
        actionLabel: "Testing",
        onChanged: (personnel) => _personnels = List.from(personnel),
        decoration: InputDecoration(
          labelText: "Mannskap",
          hintText: "Søk etter mannskap",
          helperText: "Posisjon til mannskap blir lagret",
          filled: true,
          alignLabelWithHint: true,
          hintMaxLines: 3,
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
        inputType: TextInputType.text,
        keyboardAppearance: Brightness.dark,
        inputAction: TextInputAction.done,
        autocorrect: true,
        textCapitalization: TextCapitalization.sentences,
        textStyle: TextStyle(height: 1.8, fontSize: 16.0),
      ),
    );
  }

  List<Personnel> _findPersonnel(String query) {
    if (query.length != 0) {
      final actual = _getActualPersonnel().map((personnel) => personnel.uuid);
      final local = _getLocalPersonnel().map((personnel) => personnel.uuid);
      final lowercaseQuery = query.toLowerCase();
      final units = context.bloc<TrackingBloc>().units;
      final found = context
          .bloc<PersonnelBloc>()
          .personnels
          .values
          .where((personnel) => _canAddPersonnel(
                actual,
                personnel,
                local,
                units,
              ))
          .where((personnel) =>
              personnel.name.toLowerCase().contains(lowercaseQuery) ||
              translatePersonnelStatus(personnel.status).toLowerCase().contains(lowercaseQuery))
          .take(5)
          .toList(growable: false);
      return found;
    }
    return const <Personnel>[];
  }

  bool _canAddPersonnel(
      Iterable<String> actual, Personnel personnel, Iterable<String> local, TrackableQuery<Unit> units) {
    return actual.contains(personnel.uuid) && !local.contains(personnel.uuid) || units.find(personnel) == null;
  }

  Widget _buildPositionField() {
    final position = _toPosition();
    return PositionField(
      attribute: 'position',
      initialValue: position,
      labelText: "Siste posisjon",
      hintText: 'Velg posisjon',
      errorText: 'Posisjon må oppgis',
      helperText: _toTrackingHelperText(position),
      onChanged: (point) => setState(() {}),
    );
  }

  String _toTrackingHelperText(Position position) {
    return position != null
        ? (PositionSource.manual == position.source
            ? 'Manuell lagt inn.'
            : 'Gjennomsnitt av siste posisjoner fra mannskap og apparater.')
        : '';
  }

  Position _toPosition() {
    final tracking = context.bloc<TrackingBloc>().trackings[tuuid];
    return tracking?.position ?? widget.position;
  }

  String get tuuid => widget?.unit?.tracking?.uuid;

  List<Device> _getLocalDevices() => List.from(_devices ?? <Device>[]);

  List<Device> _getActualDevices() {
    return (widget?.unit?.tracking != null ? context.bloc<TrackingBloc>().devices(tuuid,
        // Include closed tracks
        exclude: []) : [])
      ..toList()
      ..addAll(widget.devices ?? []);
  }

  List<Personnel> _getLocalPersonnel() => List.from(_personnels ?? <Device>[]);

  List<Personnel> _getActualPersonnel() =>
      List<Personnel>.from(widget?.unit?.personnels ?? []).toList()..addAll(widget.personnels ?? []);

  Position _preparePosition() {
    final position = _formKey.currentState.value['position'] == null
        ? null
        : Position.fromJson(
            _formKey.currentState.value['position'],
          );
    // Only manually added points are allowed
    return PositionSource.manual == position?.source ? position : null;
  }

  String _defaultNumber() {
    return "${widget?.unit?.number ?? _nextNumber(_actualType(widget.type))}";
  }

  int _nextNumber(UnitType type) => context.bloc<UnitBloc>().nextAvailableNumber(
        type,
        reuse: context.bloc<AppConfigBloc>().config.callsignReuse,
      );

  String _actualNumber() {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('number') == true
        ? "${values['number']}" ?? "${widget?.unit?.number ?? _numberController.text}"
        : "${widget?.unit?.number ?? _numberController.text}";
  }

  UnitType _actualType(UnitType defaultValue) {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('type') == true
        ? UnitModel.fromJson(values).type ?? widget?.unit?.type ?? defaultValue
        : widget?.unit?.type ?? defaultValue;
  }

  String _defaultCallSign() {
    return "${widget?.unit?.callsign ?? _nextCallSign()}";
  }

  String _nextCallSign() {
    int number = _ensureCallSignSuffix();
    UnitType type = _actualType(widget.type);
    Department dep = context.bloc<AffiliationBloc>().findUserDepartment();
    return toCallsign(type, dep?.name, number);
  }

  int _ensureCallSignSuffix() {
    final next = _nextNumber(_actualType(widget.type));
    final values = _formKey?.currentState?.value;
    final number = values?.containsKey('number') == true
        ? values['number'] ?? widget?.unit?.number ?? next
        : widget?.unit?.number ?? next;
    return number;
  }

  String _defaultPhone() {
    return widget?.unit?.phone;
  }

  void _submit() async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      var response = true;
      final create = widget.unit == null;
      var unit = create ? _createdUnit() : _updatedUnit();
      if (_changedToRetired(unit)) {
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
            personnels: _personnels,
            position: _preparePosition(),
          ),
        );
      }
    } else {
      // Show errors
      setState(() {});
    }
  }

  bool _changedToRetired(Unit unit) => UnitStatus.retired == unit.status && unit.status != widget?.unit?.status;

  Unit _createdUnit() => UnitModel.fromJson(_formKey.currentState.value).copyWith(
        uuid: Uuid().v4(),
        tracking: TrackingUtils.newRef(),
      );

  Unit _updatedUnit() => widget.unit.mergeWith(_formKey.currentState.value);
}
