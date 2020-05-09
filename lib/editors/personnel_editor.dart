import 'dart:async';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/usecase/personnel.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/affilliation.dart';
import 'package:SarSys/widgets/descriptions.dart';
import 'package:SarSys/widgets/position_field.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class PersonnelEditor extends StatefulWidget {
  const PersonnelEditor({
    Key key,
    @required this.controller,
    this.personnel,
    this.devices = const [],
    this.status = PersonnelStatus.Mobilized,
  }) : super(key: key);

  final Personnel personnel;
  final Iterable<Device> devices;
  final PermissionController controller;

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

  Future<Organization> _future;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _devices ??= _getActualDevices();
    if (managed) {
      _future = FleetMapService().fetchOrganization(widget.personnel.affiliation.orgId);
    }
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
                        child: FutureBuilder<Organization>(
                            future: _future,
                            builder: (context, snapshot) {
                              return AffiliationView(
                                future: _future,
                                affiliation: widget.personnel.affiliation,
                              );
                            }),
                        onTap: _explainManaged,
                      )
                    : AffiliationForm(
                        key: _affiliationKey,
                        initialValue: _ensureAffiliation(),
                      ),
                SizedBox(height: SPACING),
                Divider(),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text("Poisisjonering", style: caption),
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

  Affiliation _ensureAffiliation() {
    final config = context.bloc<AppConfigBloc>().config;
    return _affiliationKey?.currentState?.save() ??
        widget.personnel?.affiliation ??
        Affiliation(
          orgId: Defaults.orgId,
          divId: config.divId,
          depId: config.depId,
        );
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
          );
  }

  String _validateName(String fname, String lname) {
    Personnel personnel = context
        .bloc<PersonnelBloc>()
        .personnels
        .values
        .where(
          (personnel) => PersonnelStatus.Retired != personnel.status,
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
      initialValue: enumName(widget?.personnel?.status ?? PersonnelStatus.Mobilized),
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
      initialValue: enumName(widget?.personnel?.function ?? OperationalFunction.Personnel),
      items: OperationalFunction.values
          .map((function) => [enumName(function), translateOperationalFunction(function)])
          .map((function) => DropdownMenuItem(value: function[0], child: Text("${function[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Funksjon må velges'),
      ],
    );
  }

  FormBuilderTextField _buildPhoneField() {
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'phone',
      maxLength: 12,
      maxLengthEnforced: true,
      controller: _phoneController,
      initialValue: _defaultPhone(),
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
        .personnels
        .values
        .where(
          (unit) => PersonnelStatus.Retired != unit.status,
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
    final style = Theme.of(context).textTheme.caption;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
      child: FormBuilderChipsInput(
        attribute: 'devices',
        maxChips: 5,
        initialValue: _getActualDevices(),
        onChanged: (devices) => _devices = List.from(devices),
        decoration: InputDecoration(
          labelText: "Sporing",
          hintText: "Søk etter apparater",
          helperText: "Posisjon beregnes som gjennomsnitt",
          filled: true,
          contentPadding: EdgeInsets.fromLTRB(12.0, 8.0, 8.0, 16.0),
        ),
        findSuggestions: _findDevices,
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
              child: Text(enumName(device.status).substring(0, 1)),
            ),
            title: Text(device.number),
            onTap: () => state.selectSuggestion(device),
          );
        },
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

  FutureOr<List<Device>> _findDevices(String query) async {
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
              actual.contains(device.uuid) && !local.contains(device.uuid) ||
              context.bloc<TrackingBloc>().has(device) == false)
          .where((device) =>
              device.number.toLowerCase().contains(lowercaseQuery) ||
              device.type.toString().toLowerCase().contains(lowercaseQuery))
          .take(5)
          .toList(growable: false);
    }
    return const <Device>[];
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
      controller: widget.controller,
      onChanged: (point) => setState(() {}),
    );
  }

  String _toTrackingHelperText(Position position) {
    return position != null
        ? (PositionSource.manual == position.source
            ? 'Manuell lagt inn.'
            : 'Gjennomsnitt av siste posisjoner fra apparater.')
        : '';
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
      final affiliation = managed ? widget.personnel.affiliation : _affiliationKey.currentState.save();

      // Get personnel from current state
      var personnel = (widget.personnel == null
              ? Personnel.fromJson(_formKey.currentState.value)
              : widget.personnel.withJson(_formKey.currentState.value))
          .cloneWith(affiliation: affiliation);

      var response = true;
      if (PersonnelStatus.Retired == personnel.status && personnel.status != widget?.personnel?.status) {
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
            personnel: personnel,
            devices: devices,
            position: devices.isEmpty ? _preparePosition() : null,
          ),
        );
      }
    } else {
      // Show errors
      setState(() {});
    }
  }

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
