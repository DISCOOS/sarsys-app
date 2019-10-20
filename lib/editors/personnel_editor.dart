import 'dart:async';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/usecase/personnel.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/affilliation_form.dart';
import 'package:SarSys/widgets/point_field.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class PersonnelEditor extends StatefulWidget {
  final Personnel personnel;
  final Iterable<Device> devices;
  final PermissionController controller;

  final PersonnelStatus status;

  const PersonnelEditor({
    Key key,
    @required this.controller,
    this.personnel,
    this.status = PersonnelStatus.Mobilized,
    this.devices = const [],
  }) : super(key: key);

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

  ValueNotifier<String> _editedName = ValueNotifier(null);
  ValueNotifier<List<Device>> _devices;

  DeviceBloc _deviceBloc;
  TrackingBloc _trackingBloc;
  PersonnelBloc _personnelBloc;
  AppConfigBloc _appConfigBloc;

  @override
  void initState() {
    super.initState();
    _initFNameController();
    _initLNameController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _appConfigBloc = BlocProvider.of<AppConfigBloc>(context);
    _personnelBloc = BlocProvider.of<PersonnelBloc>(context);
    _devices ??= ValueNotifier(_getActualDevices());
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

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context).textTheme.caption;
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
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
                Divider(),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text("Tilhørighet", style: caption),
                ),
                SizedBox(height: SPACING),
                AffiliationForm(
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

  Affiliation _ensureAffiliation() =>
      widget.personnel?.affiliation ??
      Affiliation(
        organization: Defaults.organization,
        division: _appConfigBloc.config.division,
        department: _appConfigBloc.config.department,
      );

  InputDecorator _buildNameField() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "Kortnavn",
        filled: true,
        enabled: false,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: ValueListenableBuilder<String>(
            valueListenable: _editedName,
            builder: (context, name, _) {
              return Text(
                name ?? _defaultName() ?? '',
                style: Theme.of(context).textTheme.subhead,
              );
            }),
      ),
    );
  }

  String _defaultName() => widget?.personnel?.formal;

  FormBuilderTextField _buildFNameField() {
    return FormBuilderTextField(
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
        (value) => _validateName(value, _lnameController.text),
      ],
    );
  }

  FormBuilderTextField _buildLNameField() {
    return FormBuilderTextField(
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
    Personnel personnel = _personnelBloc.personnel.values
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
        personnel?.id != widget?.personnel?.id &&
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

  Widget _buildDeviceListField() {
    final style = Theme.of(context).textTheme.caption;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
      child: FormBuilderChipsInput(
        attribute: 'devices',
        maxChips: 5,
        initialValue: _getActualDevices(),
        onChanged: (devices) => _devices.value = List.from(devices),
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

  Widget _buildPointField() {
    return ValueListenableBuilder<List<Device>>(
        valueListenable: _devices,
        builder: (context, devices, _) {
          return PointField(
            attribute: 'point',
            enabled: devices.isEmpty,
            initialValue: _toPoint(),
            labelText: "Siste posisjon",
            hintText: devices.isEmpty ? 'Velg posisjon' : 'Ingen',
            errorText: 'Posisjon må oppgis',
            helperText:
                devices.isEmpty ? "Klikk på posisjon for å endre" : "Kan kun endres når sporing ikke er oppgitt",
            controller: widget.controller,
            onChanged: (point) => setState(() {}),
          );
        });
  }

  Point _toPoint() {
    final bloc = BlocProvider.of<TrackingBloc>(context);
    final tracking = bloc.tracking[widget?.personnel?.tracking];
    return tracking?.point;
  }

  List<Device> _getLocalDevices() => List.from(_formKey.currentState.value['devices'] ?? <Device>[]);

  List<Device> _getActualDevices() {
    return (widget?.personnel?.tracking != null
        ? _trackingBloc.devices(
            widget?.personnel?.tracking,
            // Include closed tracks
            exclude: [],
          )
        : [])
      ..addAll(widget.devices);
  }

  void _submit() async {
    if (_formKey.currentState.validate() && _affiliationKey.currentState.validate()) {
      _formKey.currentState.save();
      final affiliation = _affiliationKey.currentState.save();

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
            context,
            personnel: personnel,
            devices: devices,
            point: devices.isEmpty ? _preparePoint() : null,
          ),
        );
      }
    } else {
      // Show errors
      setState(() {});
    }
  }

  Point _preparePoint() {
    final point =
        _formKey.currentState.value["point"] == null ? null : Point.fromJson(_formKey.currentState.value["point"]);
    // Only manually added points are allowed
    return PointType.Manual == point?.type ? point : null;
  }

  String _defaultFName() {
    return widget?.personnel?.fname;
  }

  String _defaultLName() {
    return widget?.personnel?.lname;
  }
}
