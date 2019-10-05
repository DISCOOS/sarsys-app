import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class DeviceEditor extends StatefulWidget {
  final Device device;
  final DeviceType type;

  const DeviceEditor({
    Key key,
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

  final _aliasController = TextEditingController();
  final _numberController = TextEditingController();

  String _editedName;
  String _editedDistrict;
  String _editedFunction;
  DeviceBloc _deviceBloc;
  Future<Organization> _organization;

  @override
  void initState() {
    super.initState();
    _aliasController.text = widget.device?.alias ?? "";
    _aliasController.addListener(
      () => _onNumberOrAliasEdit(_aliasController.text, _numberController.text),
    );
    _numberController.text = widget.device?.number ?? "";
    _numberController.addListener(
      () => _onNumberOrAliasEdit(_aliasController.text, _numberController.text),
    );
    _organization = AssetsService().fetchOrganization(Defaults.orgId);
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: FutureBuilder<Organization>(
              future: _organization,
              builder: (context, snapshot) {
                return FormBuilder(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      buildTwoCellRow(_buildNameField(), _buildNumberField(), spacing: SPACING),
                      SizedBox(height: SPACING),
                      buildTwoCellRow(_buildTypeField(snapshot.data), _buildAliasField(), spacing: SPACING),
                      if (DeviceType.Tetra == actualType) ...[
                        SizedBox(height: SPACING),
                        buildTwoCellRow(_buildDistrictField(snapshot.data), _buildFunctionField(snapshot.data),
                            spacing: SPACING),
                      ],
                      SizedBox(height: MediaQuery.of(context).size.height / 2),
                    ],
                  ),
                );
              }),
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
          _editedName ?? widget?.device?.name ?? "${translateDeviceType(widget.type)}",
          style: Theme.of(context).textTheme.subhead,
        ),
      ),
    );
  }

  FormBuilderTextField _buildNumberField() {
    var originalNumber = widget.device?.number ?? "";
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'number',
      maxLength: 12,
      autofocus: true,
      maxLengthEnforced: true,
      textInputAction: TextInputAction.next,
      initialValue: originalNumber,
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
            originalNumber,
          ),
        ),
      ),
      keyboardType: TextInputType.numberWithOptions(),
      validators: [
        FormBuilderValidators.required(errorText: 'Nummer må fylles inn'),
        FormBuilderValidators.numeric(errorText: "Må være et nummer"),
        (value) {
          Device device = _deviceBloc.devices.values.firstWhere(
            (Device device) => device != widget.device && device.number == value,
            orElse: () => null,
          );
          return device != null ? "Finnes allerede" : null;
        },
      ],
    );
  }

  InputDecorator _buildDistrictField(Organization org) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "Distrikt",
        filled: true,
        enabled: false,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          _editedDistrict ?? org == null ? '-' : org.toDistrict(widget?.device?.number),
          style: Theme.of(context).textTheme.subhead,
        ),
      ),
    );
  }

  InputDecorator _buildFunctionField(Organization org) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: "Funksjon",
        filled: true,
        enabled: false,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(
          _editedFunction ?? org == null ? '-' : org.toFunction(widget?.device?.number),
          style: Theme.of(context).textTheme.subhead,
        ),
      ),
    );
  }

  FormBuilderTextField _buildAliasField() {
    var originalValue = widget.device?.alias ?? "";
    return FormBuilderTextField(
      maxLines: 1,
      attribute: 'alias',
      initialValue: originalValue,
      textInputAction: TextInputAction.done,
      controller: _aliasController,
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
      validators: [
        (value) {
          Device device = _deviceBloc.devices.values.firstWhere(
            (Device device) => device != widget.device && device.alias == value,
            orElse: () => null,
          );
          return (value == null || device == null) == false ? "Finnes allerede" : null;
        },
      ],
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

  void _onNumberOrAliasEdit(
    String alias,
    String number, {
    bool update = true,
    Organization org,
  }) {
    if (alias.isEmpty) alias = null;
    if (number.isEmpty) number = null;
    _editedName = alias ?? number ?? widget.device?.name ?? _editedName ?? translateDeviceType(widget.type);
    _editedDistrict = org == null ? _editedDistrict : org.toDistrict(number);
    _editedFunction = org == null ? _editedFunction : org.toFunction(number);
    if (update) setState(() {});
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

  void _submit(BuildContext context) async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      var device = widget.device == null
          ? Device.fromJson(_formKey.currentState.value)
          : widget.device.withJson(_formKey.currentState.value);
      Navigator.pop(context, device);
    } else {
      // Show errors
      setState(() {});
    }
  }

  DeviceType _getActualType(DeviceType defaultValue) {
    final values = _formKey?.currentState?.value;
    return (values == null ? widget?.device?.type ?? defaultValue : Device.fromJson(values).type) ??
        widget?.device?.type ??
        defaultValue;
  }

  String _getActualAlias() {
    final values = _formKey?.currentState?.value;
    return (values == null ? widget?.device?.alias ?? "" : Device.fromJson(values).alias) ??
        widget?.device?.alias ??
        "";
  }

  String _getActualNumber() {
    final values = _formKey?.currentState?.value;
    return (values == null ? "${widget?.device?.number}" ?? "" : Device.fromJson(values).number) ??
        widget?.device?.number ??
        "";
  }
}
