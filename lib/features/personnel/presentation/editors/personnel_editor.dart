import 'dart:async';

import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/features/affiliation/presentation/widgets/affiliation.dart';
import 'package:SarSys/widgets/descriptions.dart';
import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:SarSys/widgets/position_field.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:uuid/uuid.dart';

class PersonnelEditor extends StatefulWidget {
  const PersonnelEditor({
    Key key,
    this.personnel,
    this.affiliation,
    this.devices = const [],
    this.status = PersonnelStatus.alerted,
  }) : super(key: key);

  final Personnel personnel;
  final Affiliation affiliation;
  final Iterable<Device> devices;

  final PersonnelStatus status;

  @override
  _PersonnelEditorState createState() => _PersonnelEditorState();
}

class _PersonnelEditorState extends State<PersonnelEditor> {
  static const SPACING = 16.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();
  var _affiliationKey = GlobalKey<AffiliationFormState>();

  final TextEditingController _fnameController = TextEditingController();
  final TextEditingController _lnameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  ValueNotifier<String> _editedName = ValueNotifier(null);
  List<Device> _devices;

  bool get managed => widget.personnel?.userId != null;

  void _explainManaged() => alert(
        context,
        title: "Persondata",
        content: ManagedProfileDescription(),
      );

  @override
  void initState() {
    super.initState();
    _initFNameController();
    _initLNameController();
    _initPhoneController();
  }

  @override
  void dispose() {
    _fnameController.dispose();
    _lnameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _devices ??= _getActualDevices();
  }

  void _initFNameController() {
    _setText(_fnameController, _defaultFName());
    _fnameController.addListener(
      () => _onNameEdit(
        _fnameController.text,
        _lnameController.text,
      ),
    );
  }

  void _initLNameController() {
    _setText(_lnameController, _defaultLName());
    _lnameController.addListener(
      () => _onNameEdit(
        _fnameController.text,
        _lnameController.text,
      ),
    );
  }

  void _initPhoneController() {
    _setText(_phoneController, _defaultPhone());
  }

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context).textTheme.caption;
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      appBar: AppBar(
        title: Text(widget.personnel == null ? 'Nytt mannskap' : 'Endre mannskap'),
        centerTitle: false,
        leading: GestureDetector(
          child: Icon(Icons.close),
          onTap: () {
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          FlatButton(
            child: Text(widget.personnel == null ? 'OPPRETT' : 'OPPDATER',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                buildTwoCellRow(_buildNameField(), _buildStatusField(), spacing: SPACING),
                SizedBox(height: SPACING),
                buildTwoCellRow(_buildFNameField(), _buildLNameField(), spacing: SPACING),
                SizedBox(height: SPACING),
                buildTwoCellRow(_buildFunctionField(), _buildPhoneField(), spacing: SPACING),
                SizedBox(height: SPACING),
                Divider(),
                if (!managed) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text("Tilhørighet", style: caption),
                  ),
                  SizedBox(height: SPACING),
                ],
                managed
                    ? GestureDetector(
                        child: AffiliationView(
                          affiliation: _currentAffiliation(),
                        ),
                        onTap: _explainManaged,
                      )
                    : AffiliationForm(
                        key: _affiliationKey,
                        value: _ensureAffiliation(),
                      ),
                SizedBox(height: SPACING),
                Divider(),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text("Posisjonering", style: caption),
                ),
                SizedBox(height: SPACING),
                _buildDeviceListField(),
                SizedBox(height: SPACING),
                _buildPointField(),
                SizedBox(height: MediaQuery.of(context).size.height * 0.75),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AffiliationBloc get affiliationBloc => context.bloc<AffiliationBloc>();
  Affiliation _currentAffiliation() => widget.affiliation ?? affiliationBloc.repo[widget.personnel?.affiliation?.uuid];

  Affiliation _ensureAffiliation() {
    final affiliation = _affiliationKey?.currentState?.save() ?? _currentAffiliation();
    if (affiliation == null) {
      final use = affiliationBloc.findUserAffiliation();
      if (!use.isEmpty) {
        return AffiliationModel(
          org: use.org,
          div: use.div,
          dep: use.dep,
        );
      }
    }
    return affiliation;
  }

  Widget _buildNameField() {
    return _buildDecorator(
      label: "Kortnavn",
      child: ValueListenableBuilder<String>(
          valueListenable: _editedName,
          builder: (context, name, _) {
            return _buildReadOnlyText(context, name ?? _defaultName() ?? '');
          }),
    );
  }

  Text _buildReadOnlyText(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.subtitle2,
    );
  }

  Widget _buildDecorator({
    String label,
    Widget child,
    VoidCallback onTap,
  }) {
    return GestureDetector(
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          enabled: false,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: child,
        ),
      ),
      onTap: onTap,
    );
  }

  String _defaultName() => widget?.personnel?.formal;

  Widget _buildFNameField() {
    return managed
        ? _buildDecorator(
            label: 'Fornavn',
            onTap: _explainManaged,
            child: _buildReadOnlyText(context, _defaultFName()),
          )
        : FormBuilderTextField(
            maxLines: 1,
            attribute: 'fname',
            controller: _fnameController,
            decoration: InputDecoration(
              hintText: 'Skriv inn',
              filled: true,
              labelText: 'Fornavn',
              suffix: GestureDetector(
                child: Icon(
                  Icons.clear,
                  color: Colors.grey,
                  size: 20,
                ),
                onTap: () => _setText(
                  _fnameController,
                  _defaultFName(),
                ),
              ),
            ),
            keyboardType: TextInputType.text,
            valueTransformer: (value) => emptyAsNull(value),
            validators: [
              FormBuilderValidators.required(errorText: 'Må fylles inn'),
              (value) => _validateName(value, _fnameController.text),
            ],
            autocorrect: true,
            textCapitalization: TextCapitalization.sentences,
          );
  }

  Widget _buildLNameField() {
    return managed
        ? _buildDecorator(
            label: 'Fornavn',
            onTap: _explainManaged,
            child: _buildReadOnlyText(context, _defaultLName()),
          )
        : FormBuilderTextField(
            maxLines: 1,
            attribute: 'lname',
            controller: _lnameController,
            decoration: InputDecoration(
              hintText: 'Skriv inn',
              filled: true,
              labelText: 'Etternavn',
              suffix: GestureDetector(
                child: Icon(
                  Icons.clear,
                  color: Colors.grey,
                  size: 20,
                ),
                onTap: () => _setText(
                  _lnameController,
                  _defaultLName(),
                ),
              ),
            ),
            keyboardType: TextInputType.text,
            valueTransformer: (value) => emptyAsNull(value),
            validators: [
              FormBuilderValidators.required(errorText: 'Må fylles inn'),
              (value) => _validateName(value, _lnameController.text),
            ],
            autocorrect: true,
            textCapitalization: TextCapitalization.sentences,
          );
  }

  String _validateName(String fname, String lname) {
    Personnel personnel = context
        .bloc<PersonnelBloc>()
        .repo
        .map
        .values
        .where(
          (personnel) => PersonnelStatus.retired != personnel.status,
        )
        .firstWhere(
          (Personnel personnel) => _isSameName(personnel, _defaultName()),
          orElse: () => null,
        );
    return personnel != null ? "${personnel.name} har samme" : null;
  }

  bool _isSameName(Personnel personnel, String name) {
    return name?.isNotEmpty == true &&
        personnel?.uuid != widget?.personnel?.uuid &&
        personnel?.name?.toLowerCase() == name?.toLowerCase();
  }

  void _setText(TextEditingController controller, String value) {
    setText(controller, value);
    _formKey?.currentState?.save();
  }

  void _onNameEdit(String fname, String lname) {
    _formKey?.currentState?.save();
    _editedName.value = _toShort(fname, lname);
  }

  String _toShort(String fname, String lname) {
    fname ??= '';
    lname ??= '';
    final short = fname?.isNotEmpty == true ? fname.substring(0, 1).toUpperCase() : '';
    return "${short.isNotEmpty ? '$short.' : short} $lname";
  }

  Widget _buildStatusField() {
    return buildDropDownField(
      attribute: 'status',
      label: 'Status',
      initialValue: enumName(widget?.personnel?.status ?? PersonnelStatus.alerted),
      items: PersonnelStatus.values
          .map((status) => [enumName(status), translatePersonnelStatus(status)])
          .map((status) => DropdownMenuItem(value: status[0], child: Text("${status[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Status må velges'),
      ],
    );
  }

  Widget _buildFunctionField() {
    return buildDropDownField(
      attribute: 'function',
      label: 'Funksjon',
      initialValue: enumName(widget?.personnel?.function ?? OperationalFunctionType.personnel),
      items: OperationalFunctionType.values
          .map((function) => [enumName(function), translateOperationalFunction(function)])
          .map((function) => DropdownMenuItem(value: function[0], child: Text("${function[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Funksjon må velges'),
      ],
    );
  }

  Widget _buildPhoneField() {
    return managed
        ? _buildDecorator(
            label: 'Mobiltelefon',
            onTap: _explainManaged,
            child: _buildReadOnlyText(context, _defaultPhone()),
          )
        : FormBuilderTextField(
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
    Personnel match = context
        .bloc<PersonnelBloc>()
        .repo
        .map
        .values
        .where(
          (unit) => PersonnelStatus.retired != unit.status,
        )
        .firstWhere(
          (Personnel personnel) => _isSamePhone(personnel, phone),
          orElse: () => null,
        );
    return match != null ? "${match.name} har samme" : null;
  }

  bool _isSamePhone(Personnel personnel, String phone) {
    return phone?.isNotEmpty == true &&
        personnel?.uuid != widget?.personnel?.uuid &&
        personnel?.phone?.toLowerCase()?.replaceAll(RegExp(r'\s|-'), '') ==
            phone?.toLowerCase()?.replaceAll(RegExp(r'\s|-'), '');
  }

  String _defaultPhone() {
    return widget?.personnel?.phone;
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
          helperText: "Spor blir kun lagret i aksjonen",
          filled: true,
          contentPadding: EdgeInsets.fromLTRB(12.0, 8.0, 8.0, 16.0),
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
        autocorrect: true,
        inputType: TextInputType.text,
        inputAction: TextInputAction.done,
        keyboardAppearance: Brightness.dark,
        textCapitalization: TextCapitalization.sentences,
        textStyle: TextStyle(height: 1.8, fontSize: 16.0),
      ),
    );
  }

  FutureOr<List<Device>> _findDevices(String query) async {
    if (query.length != 0) {
      var actual = _getActualDevices().map((device) => device.uuid);
      var local = _getLocalDevices().map((device) => device.uuid);
      var pattern = query.toLowerCase();
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
          .where((device) => _deviceMatch(device, pattern))
          .take(5)
          .toList(growable: false);
    }
    return const <Device>[];
  }

  bool _deviceMatch(Device device, String pattern) => [
        device.number,
        device.alias,
        device.type,
      ].join().toLowerCase().contains(pattern);

  bool _canAddDevice(Iterable<String> actual, Device device, Iterable<String> local) {
    return actual.contains(device.uuid) && !local.contains(device.uuid) || !context.bloc<TrackingBloc>().has(device);
  }

  Widget _buildPointField() {
    final point = _toPosition();
    return PositionField(
      attribute: 'position',
      initialValue: point,
      labelText: "Siste posisjon",
      hintText: 'Velg posisjon',
      errorText: 'Posisjon må oppgis',
      helperText: _toTrackingHelperText(point),
      onChanged: (point) => setState(() {}),
    );
  }

  String _toTrackingHelperText(Position position) {
    return PositionSource.manual == position?.source
        ? 'Manuell lagt inn'
        : 'Gjennomsnitt av siste posisjon til apparater';
  }

  Position _toPosition() {
    final tracking = context.bloc<TrackingBloc>().trackings[widget?.personnel?.tracking?.uuid];
    return tracking?.position;
  }

  List<Device> _getLocalDevices() => List.from(_formKey.currentState.value['devices'] ?? <Device>[]);

  List<Device> _getActualDevices() {
    return (widget?.personnel?.tracking != null
        ? context.bloc<TrackingBloc>().devices(
            widget?.personnel?.tracking?.uuid,
            // Include closed tracks
            exclude: [],
          )
        : [])
      ..toList()
      ..addAll(widget.devices ?? []);
  }

  void _submit() async {
    if (_formKey.currentState.validate() && (managed || _affiliationKey.currentState.validate())) {
      _formKey.currentState.save();
      final isNew = widget.personnel == null;

      final affiliation = _toAffiliation();
      final personnel = isNew ? _createPersonnel(affiliation) : _updatePersonnel(affiliation);

      var response = true;
      if (PersonnelStatus.retired == personnel.status && personnel.status != widget?.personnel?.status) {
        response = await prompt(
          context,
          "Dimittere ${personnel.name}",
          "Dette vil stoppe sporing og dimittere mannskapet. Vil du fortsette?",
        );
      }
      if (response) {
        List<Device> devices = List<Device>.from(_formKey.currentState.value["devices"]);
        Navigator.pop(
          context,
          PersonnelParams(
            devices: devices,
            personnel: personnel,
            affiliation: affiliation,
            position: devices.isEmpty ? _preparePosition() : null,
          ),
        );
      }
    } else {
      // Show errors
      setState(() {});
    }
  }

  Affiliation _toAffiliation() {
    if (managed) {
      return _currentAffiliation();
    }
    final next = _affiliationKey.currentState.save();
    return next.uuid == null ? next.copyWith(uuid: widget.personnel?.affiliation?.uuid ?? Uuid().v4()) : next;
  }

  Personnel _createPersonnel(Affiliation affiliation) => PersonnelModel.fromJson(_formKey.currentState.value).copyWith(
        uuid: Uuid().v4(),
        affiliation: affiliation.toRef(),
        fname: _formKey.currentState.value['fname'],
        lname: _formKey.currentState.value['lname'],
        phone: _formKey.currentState.value['phone'],
        // Backend will use this as tuuid to create new tracking
        tracking: AggregateRef.fromType<Tracking>(Uuid().v4()),
      );

  Personnel _updatePersonnel(Affiliation affiliation) =>
      widget.personnel.mergeWith(_formKey.currentState.value).copyWith(
            affiliation: affiliation.toRef(),
            fname: _formKey.currentState.value['fname'],
            lname: _formKey.currentState.value['lname'],
            phone: _formKey.currentState.value['phone'],
          );

  Position _preparePosition() {
    final position = _formKey.currentState.value['position'] == null
        ? null
        : Position.fromJson(_formKey.currentState.value['position']);
    // Only manually added points are allowed
    return PositionSource.manual == position?.source ? position : null;
  }

  String _defaultFName() {
    return widget?.personnel?.fname;
  }

  String _defaultLName() {
    return widget?.personnel?.lname;
  }
}
