import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/point_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class DeviceEditor extends StatefulWidget {
  final Device device;
  final DeviceType type;
  final PermissionController controller;

  const DeviceEditor({
    Key key,
    @required this.controller,
    this.device,
    this.type = DeviceType.Tetra,
  }) : super(key: key);

  @override
  _DeviceEditorState createState() => _DeviceEditorState();
}

class _DeviceEditorState extends State<DeviceEditor> {
  static const SPACING = 16.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();

  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();

  String _editedName;
  String _editedOrgAlias;
  String _editedAffiliation;
  String _editedFunction;
  DeviceBloc _deviceBloc;
  Future<Organization> _organization;

  @override
  void initState() {
    super.initState();
    _organization = AssetsService().fetchOrganization(Defaults.organization);
    _initAliasController();
    _initNumberController();
  }

  void _initAliasController() {
    _setText(_aliasController, widget.device?.alias);
    _aliasController.addListener(
      () => _onNumberOrAliasEdit(_aliasController.text, _numberController.text),
    );
  }

  void _initNumberController() {
    _setText(_numberController, widget.device?.number);
    _numberController.addListener(
      () => _onNumberOrAliasEdit(_aliasController.text, _numberController.text),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    final actualType = _getActualType(widget.type);
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.device == null ? 'Nytt apparat' : 'Endre apparat'),
        centerTitle: false,
        leading: GestureDetector(
          child: Icon(Icons.close),
          onTap: () {
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          FlatButton(
            child: Text(widget.device == null ? 'OPPRETT' : 'OPPDATER',
                style: TextStyle(fontSize: 14.0, color: Colors.white)),
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            onPressed: () => _submit(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: FutureBuilder<Organization>(
            future: _organization,
            builder: (context, snapshot) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: FormBuilder(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      buildTwoCellRow(_buildNameField(), _buildNumberField(), spacing: SPACING),
                      SizedBox(height: SPACING),
                      buildTwoCellRow(_buildTypeField(snapshot.data), _buildAliasField(), spacing: SPACING),
                      if (DeviceType.Tetra == actualType) ...[
                        SizedBox(height: SPACING),
                        buildTwoCellRow(
                          _buildOrgAliasField(snapshot.data),
                          _buildFunctionField(snapshot.data),
                          spacing: SPACING,
                        ),
                        SizedBox(height: SPACING),
                        _buildAffiliationInfo(snapshot.data),
                      ],
                      SizedBox(height: SPACING),
                      _buildPointField(),
                      SizedBox(height: MediaQuery.of(context).size.height / 2),
                    ],
                  ),
                ),
              );
            }),
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

  String _defaultName() => widget?.device?.name ?? "";

  Widget _buildNumberField() {
    var originalNumber = widget.device?.number;
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'number',
      maxLength: 12,
      maxLengthEnforced: true,
      controller: _numberController,
      onChanged: (value) => _setText(
        _numberController,
        value,
      ),
      decoration: InputDecoration(
        hintText: 'Skriv inn',
        filled: true,
        enabled: true,
        labelText: 'Nummer',
        suffix: GestureDetector(
          child: Icon(
            Icons.clear,
            color: Colors.grey,
            size: 20,
          ),
          onTap: () {
            _setText(
              _numberController,
              originalNumber,
            );
          },
        ),
      ),
      keyboardType: TextInputType.numberWithOptions(),
      valueTransformer: (value) => emptyAsNull(value),
      validators: [
        FormBuilderValidators.required(errorText: 'Nummer må fylles inn'),
        FormBuilderValidators.numeric(errorText: "Må være et nummer"),
        (number) {
          Device device = _deviceBloc.devices.values.firstWhere(
            (Device device) => isSameNumber(device, number),
            orElse: () => null,
          );
          return device != null ? "Finnes allerede" : null;
        },
      ],
    );
  }

  bool isSameNumber(Device device, String number) =>
      number?.isNotEmpty == true && device?.id != widget?.device?.id && device.number?.toString() == number;

  Widget _buildAffiliationInfo(Organization org) => InputDecorator(
        decoration: InputDecoration(
          labelText: "Tilhørighet",
          filled: true,
          enabled: false,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            _editedAffiliation ?? _defaultAffiliation(org),
            style: Theme.of(context).textTheme.subhead,
          ),
        ),
      );

  String _defaultAffiliation(Organization org) => org?.toAffiliationAsString(widget?.device?.number) ?? '-';

  InputDecorator _buildOrgAliasField(Organization org) => InputDecorator(
        decoration: InputDecoration(
          labelText: "Kortnavn org.",
          filled: true,
          enabled: false,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            _editedOrgAlias ?? _defaultOrgAlias(org),
            style: Theme.of(context).textTheme.subhead,
          ),
        ),
      );

  String _defaultOrgAlias(Organization org) => org?.alias ?? '-';

  InputDecorator _buildFunctionField(Organization org) => InputDecorator(
        decoration: InputDecoration(
          labelText: "Kortnavn",
          filled: true,
          enabled: false,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            _editedFunction ?? _defaultFunction(org),
            style: Theme.of(context).textTheme.subhead,
          ),
        ),
      );

  String _defaultFunction(Organization org) => org?.toFunction(widget?.device?.number) ?? '-';

  FormBuilderTextField _buildAliasField() {
    var originalValue = widget.device?.alias;
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'alias',
      textInputAction: TextInputAction.done,
      controller: _aliasController,
      onChanged: (value) => _setText(
        _aliasController,
        value,
      ),
      decoration: InputDecoration(
        hintText: 'Skriv inn',
        filled: true,
        labelText: 'Alias',
        suffix: GestureDetector(
          child: Icon(
            Icons.clear,
            color: Colors.grey,
            size: 20,
          ),
          onTap: () => _setText(_aliasController, originalValue),
        ),
      ),
      keyboardType: TextInputType.text,
      valueTransformer: (value) => emptyAsNull(value),
      validators: [
        (alias) {
          Device device = _deviceBloc.devices.values.firstWhere(
            (Device device) => _isSameAlias(device, alias),
            orElse: () => null,
          );
          return device != null ? "Finnes allerede" : null;
        },
      ],
    );
  }

  bool _isSameAlias(Device device, String alias) =>
      alias?.isNotEmpty == true && device?.id != widget?.device?.id && device.alias == alias;

  void _setText(TextEditingController controller, String value) {
    setText(controller, value);
    _formKey?.currentState?.save();
  }

  void _onNumberOrAliasEdit(
    String alias,
    String number, {
    bool update = true,
    Organization org,
  }) {
    if (org == null)
      _organization.then(
        (org) => _onNumberOrAliasEdit(alias, number, update: update, org: org),
      );
    else {
      alias = emptyAsNull(alias);
      number = emptyAsNull(number);
      _editedName = alias ?? number ?? _defaultName();
      _editedAffiliation = org?.toAffiliationAsString(number, empty: '-') ?? _editedAffiliation;
      _editedOrgAlias = org?.alias ?? _editedOrgAlias;
      _editedFunction = org?.toFunction(number) ?? _editedFunction;
      if (update) setState(() {});
    }
  }

  Widget _buildTypeField(Organization org) {
    final defaultValue = widget.type;
    final actualValue = _getActualType(defaultValue);
    return buildDropDownField(
      attribute: 'type',
      label: 'Type enhet',
      initialValue: enumName(actualValue),
      items: DeviceType.values
          .map((type) => [enumName(type), translateDeviceType(type)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validators: [
        FormBuilderValidators.required(errorText: 'Type må velges'),
      ],
      onChanged: (_) {
        _onNumberOrAliasEdit(
          _getActualAlias(),
          _getActualNumber(),
          org: org,
        );
        _formKey.currentState.save();
      },
    );
  }

  Widget _buildPointField() => PointField(
        attribute: 'point',
        initialValue: widget?.device?.point,
        labelText: "Siste posisjon",
        hintText: 'Velg posisjon',
        errorText: 'Posisjon må oppgis',
        controller: widget.controller,
        onChanged: (point) => setState(() {}),
      );

  void _submit(BuildContext context) async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      var device = widget.device == null
          ? Device.fromJson(_formKey.currentState.value).cloneWith(
              status: DeviceStatus.Attached,
            )
          : widget.device.withJson(_formKey.currentState.value);
      Navigator.pop(context, device);
    } else {
      // Show errors
      setState(() {});
    }
  }

  DeviceType _getActualType(DeviceType defaultValue) {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('type') == true
        ? Device.fromJson(values).type ?? defaultValue
        : widget?.device?.type ?? defaultValue;
  }

  String _getActualAlias() {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('alias') == true
        ? Device.fromJson(values).alias ?? widget?.device?.alias
        : widget?.device?.alias;
  }

  String _getActualNumber() {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('number') == true
        ? Device.fromJson(values).number ?? widget?.device?.number
        : widget?.device?.number;
  }
}
