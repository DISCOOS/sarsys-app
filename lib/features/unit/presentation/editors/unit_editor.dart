import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/personnel/presentation/editors/personnel_editor.dart';
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
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:SarSys/features/personnel/presentation/widgets/personnel_widgets.dart';
import 'package:SarSys/features/tracking/presentation/widgets/position_field.dart';

class UnitEditor extends StatefulWidget {
  final Unit unit;
  final Position position;
  final Operation operation;
  final Iterable<Device> devices;
  final Iterable<Personnel> personnels;

  final UnitType type;

  const UnitEditor({
    Key key,
    this.unit,
    this.position,
    this.operation,
    this.type = UnitType.team,
    this.devices = const [],
    this.personnels = const [],
  }) : super(key: key);

  @override
  _UnitEditorState createState() => _UnitEditorState();

  static String findUnitPhone(BuildContext context, Unit unit) {
    var phone = unit?.phone;
    if (unit != null && phone == null) {
      if (unit?.tracking != null) {
        final devices = context.bloc<TrackingBloc>().devices(
          unit?.tracking?.uuid,
          // Include closed tracks
          exclude: [],
        ).toList();
        final apps = <Device>[];
        apps.addAll(devices.where((a) => a.number != null));
        if (apps.isEmpty) {
          // Search for personnel number
          final bloc = context.bloc<PersonnelBloc>();
          for (var puuid in unit.personnels) {
            phone = PersonnelEditor.findPersonnelPhone(context, bloc.repo.get(puuid));
            if (phone != null) {
              return phone;
            }
          }
        } else {
          phone = apps.first.number;
        }
      }
    }
    return phone;
  }
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

  bool get hasAvailablePersonnel =>
      context
          .bloc<UnitBloc>()
          .findAvailablePersonnel(
            context.bloc<PersonnelBloc>().repo,
          )
          .isNotEmpty ||
      _getActualPersonnels().isNotEmpty;

  bool get hasAvailableDevices =>
      context.bloc<TrackingBloc>().findAvailablePersonnel().isNotEmpty || _getActualDevices().isNotEmpty;

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
    _personnels ??= _getActualPersonnels(init: true);
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
    return keyboardDismisser(
      context: context,
      child: Scaffold(
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
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.only(left: 16.0, right: 16.0),
              ),
              child: Text(widget.unit == null ? 'OPPRETT' : 'OPPDATER',
                  style: TextStyle(fontSize: 14.0, color: Colors.white)),
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
      name: 'number',
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
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      keyboardType: TextInputType.number,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      valueTransformer: (value) => int.tryParse(emptyAsNull(value) ?? _defaultNumber()),
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(context, errorText: 'Må fylles inn'),
        FormBuilderValidators.numeric(context, errorText: "Må være et nummer"),
        _validateNumber,
      ]),
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
      name: 'callsign',
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
      keyboardType: TextInputType.text,
      valueTransformer: (value) => emptyAsNull(value),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: FormBuilderValidators.compose([
        FormBuilderValidators.required(context, errorText: 'Må fylles inn'),
        _validateCallsign,
      ]),
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
      name: 'phone',
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
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      keyboardType: TextInputType.number,
      valueTransformer: (value) => emptyAsNull(value),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: FormBuilderValidators.compose([
        _validatePhone,
        FormBuilderValidators.numeric(context, errorText: "Kun talltegn"),
        (value) => emptyAsNull(value) != null
            ? FormBuilderValidators.minLength(context, 8, errorText: "Minimum åtte tegn")(value)
            : null,
      ]),
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
      name: 'type',
      label: 'Type enhet',
      initialValue: enumName(actualValue),
      items: UnitType.values
          .map((type) => [enumName(type), translateUnitType(type)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validator: FormBuilderValidators.required(context, errorText: 'Type må velges'),
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
      name: 'status',
      label: 'Status',
      initialValue: enumName(widget?.unit?.status ?? UnitStatus.mobilized),
      items: UnitStatus.values
          .map((status) => [enumName(status), translateUnitStatus(status)])
          .map((status) => DropdownMenuItem(value: status[0], child: Text("${status[1]}")))
          .toList(),
      validator: FormBuilderValidators.required(context, errorText: 'Status må velges'),
    );
  }

  Widget _buildDeviceListField() {
    final enabled = hasAvailableDevices;
    final types = List.from(DeviceType.values)
      ..sort(
        (a, b) => enumName(a).compareTo(enumName(b)),
      );
    return buildChipsField<Device>(
      name: 'devices',
      enabled: enabled,
      labelText: 'Apparater',
      selectorLabel: 'Apparater',
      hintText: 'Søk etter apparater',
      selectorTitle: 'Velg apparater',
      emptyText: 'Fant ingen apparater',
      helperText: enabled ? 'Spor blir kun lagret i aksjonen' : 'Ingen tilgjengelige',
      builder: (context, device) => DeviceChip(device: device),
      categories: [
        DropdownMenuItem<String>(
          value: 'alle',
          child: Text('Alle'),
        ),
        ...types.map(
          (type) => DropdownMenuItem<String>(
            value: enumName(type),
            child: Text(translateDeviceType(type).capitalize()),
          ),
        ),
      ],
      category: 'alle',
      options: _findDevices,
      items: () => _getLocalDevices(),
      onChanged: (devices) => _devices
        ..clear()
        ..addAll(devices),
    );
  }

  List<Device> _findDevices(String type, String query) {
    var actual = _getActualDevices().map((device) => device.uuid);
    return context
        .bloc<DeviceBloc>()
        .values
        .where((device) => _canAddDevice(actual, device))
        .where((device) => _deviceMatch(device, type, query))
        .take(5)
        .toList(growable: false);
  }

  bool _deviceMatch(Device device, String type, String query) {
    final test = [device.number, device.alias, device.name].join();
    return test.toLowerCase().contains(query ?? '') &&
        (type?.toLowerCase() == 'alle' || enumName(device.type).contains(type?.toLowerCase()));
  }

  bool _canAddDevice(Iterable<String> actual, Device match) {
    if (actual.contains(match.uuid)) {
      return true;
    }
    final bloc = context.bloc<TrackingBloc>();
    if (widget.unit?.tracking?.uuid != null) {
      // Was device tracked by this unit earlier?
      final trackings = bloc.find(match).map((t) => t.uuid);
      if (trackings.contains(widget.unit.tracking.uuid)) {
        return true;
      }
    }
    return !bloc.has(match);
  }

  Widget _buildPersonnelListField() {
    final enabled = hasAvailableDevices;
    final statuses = List.from(PersonnelStatus.values)
      ..sort(
        (a, b) => enumName(a).compareTo(enumName(b)),
      );
    return buildChipsField<Personnel>(
      name: 'personnels',
      enabled: enabled,
      labelText: 'Mannskap',
      selectorLabel: 'Mannskap',
      hintText: 'Søk etter mannskap',
      selectorTitle: 'Velg mannskap',
      emptyText: 'Fant ingen mannskap',
      helperText: enabled ? 'Spor blir kun lagret i aksjonen' : 'Ingen tilgjengelige',
      builder: (context, personnel) => PersonnelChip(personnel: personnel),
      categories: [
        DropdownMenuItem<String>(
          value: 'alle',
          child: Text('Alle'),
        ),
        DropdownMenuItem<String>(
          value: 'tilgjengelig',
          child: Text('Tilgjengelig'),
        ),
        ...statuses.map(
          (type) => DropdownMenuItem<String>(
            value: enumName(type),
            child: Text(translatePersonnelStatus(type).capitalize()),
          ),
        ),
      ],
      category: 'tilgjengelig',
      options: _findPersonnels,
      items: () => _getLocalPersonnel(),
    );
  }

  List<Personnel> _findPersonnels(String status, String query) {
    var actual = _getActualPersonnels().map((personnel) => personnel.uuid);
    return context
        .bloc<PersonnelBloc>()
        .values
        .where((personnel) => _canAddPersonnel(actual, personnel))
        .where((personnel) => _personnelMatch(personnel, status, query))
        .take(5)
        .toList(growable: false);
  }

  bool _personnelMatch(Personnel personnel, String status, String query) {
    final test = personnel.searchable;
    return test.toLowerCase().contains(query ?? '') &&
        (status?.toLowerCase() == 'alle' ||
            status?.toLowerCase() == 'tilgjengelig' && personnel.isAvailable ||
            enumName(personnel.status).contains(status?.toLowerCase()));
  }

  bool _canAddPersonnel(Iterable<String> actual, Personnel match) {
    if (actual.contains(match.uuid)) {
      return true;
    }
    final bloc = context.bloc<TrackingBloc>();
    if (widget.unit?.tracking?.uuid != null) {
      // Was personnel tracked by this unit earlier?
      final trackings = bloc.find(match).map((t) => t.uuid);
      if (trackings.contains(widget.unit.tracking.uuid)) {
        return true;
      }
    }
    return !bloc.has(match);
  }

  Widget _buildPositionField() {
    final position = _toPosition();
    return PositionField(
      name: 'position',
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

  List<Device> _getLocalDevices() =>
      _formKey.currentState == null || _formKey.currentState.fields['devices'].value == null
          ? _getActualDevices()
          : List<Device>.from(
              _formKey.currentState.fields['devices'].value ?? <Device>[],
            );

  List<Device> _getActualDevices() {
    return (widget?.unit?.tracking != null ? context.bloc<TrackingBloc>().devices(tuuid,
        // Include closed tracks
        exclude: []) : [])
      ..toList()
      ..addAll(widget.devices ?? []);
  }

  List<Personnel> _getLocalPersonnel() {
    if (_formKey.currentState == null || _formKey.currentState.fields['personnels'].value == null) {
      return _getActualPersonnels();
    }
    return _formKey.currentState.fields['personnels'].value ?? <Personnel>[];
  }

  List<Personnel> _getActualPersonnels({bool init = false}) {
    final puuids = List<String>.from(widget?.unit?.personnels ?? <String>[]);
    if (init) {
      puuids.addAll(widget.personnels?.map((p) => p.uuid) ?? <String>[]);
    }
    final personnels =
        context.bloc<PersonnelBloc>().values.where((p) => p.isAvailable).where((p) => puuids.contains(p.uuid)).toList();
    return personnels;
  }

  Position _preparePosition() {
    final position = _toJson()['position'] == null
        ? null
        : Position.fromJson(
            _toJson()['position'],
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
    return UnitEditor.findUnitPhone(context, widget.unit);
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

  Unit _createdUnit() => UnitModel.fromJson(_toJson()).copyWith(
        uuid: Uuid().v4(),
        tracking: TrackingUtils.newRef(),
        operation: widget.operation.toRef(),
      );

  Unit _updatedUnit() => widget.unit.mergeWith(_toJson()).copyWith(
        operation: widget.operation?.toRef() ?? widget.unit.operation,
      );

  Map<String, dynamic> _toJson() {
    final json = Map<String, dynamic>.from(_formKey.currentState.value);
    json['personnels'] = (json['personnels'] as List<Personnel>).map((p) => p.uuid).toList();
    return json;
  }
}
