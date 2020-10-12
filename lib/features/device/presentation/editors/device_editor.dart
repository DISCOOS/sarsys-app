import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/tracking/presentation/widgets/position_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:uuid/uuid.dart';

class DeviceEditor extends StatefulWidget {
  final Device device;
  final DeviceType type;

  const DeviceEditor({
    Key key,
    this.device,
    this.type = DeviceType.tetra,
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

  Organisation get organisation => context.bloc<AffiliationBloc>().findUserOrganisation();

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final actualType = _getActualType(widget.type);
    return keyboardDismisser(
      context: context,
      child: Scaffold(
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: FormBuilder(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  buildTwoCellRow(_buildNameField(), _buildTypeField(), spacing: SPACING),
                  SizedBox(height: SPACING),
                  buildTwoCellRow(_buildNumberField(), _buildAliasField(), spacing: SPACING),
                  if (DeviceType.tetra == actualType) ...[
                    SizedBox(height: SPACING),
                    buildTwoCellRow(
                      _buildOrgAliasField(),
                      _buildFunctionField(),
                      spacing: SPACING,
                    ),
                    SizedBox(height: SPACING),
                    _buildAffiliationInfo(),
                  ],
                  SizedBox(height: SPACING),
                  _buildPointField(),
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

  String _defaultName() => widget?.device?.name ?? "";

  Widget _buildNumberField() {
    final originalNumber = widget.device?.number;
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
        labelText: _toNumberFieldLabelText(),
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
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      keyboardType: TextInputType.number,
      valueTransformer: (value) => emptyAsNull(value),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validators: [
        FormBuilderValidators.required(errorText: 'Påkrevd'),
        (number) {
          Device device = context.bloc<DeviceBloc>().values.firstWhere(
                (Device device) => isSameNumber(device, number),
                orElse: () => null,
              );
          return device != null ? "Finnes allerede" : null;
        },
      ],
    );
  }

  String _toNumberFieldLabelText() {
    final currentType = _getActualType(widget.type);
    switch (currentType) {
      case DeviceType.tetra:
        return 'ISSI nummer';
      case DeviceType.app:
        return 'Mobilnummer';
      case DeviceType.aprs:
        return 'APRS SSID';
      case DeviceType.ais:
        return 'AIS MMSI';
      case DeviceType.spot:
        return 'SPOT ID';
      case DeviceType.inreach:
        return 'inReach IMEI';
    }
    return 'Nummer';
  }

  bool isSameNumber(Device device, String number) =>
      number?.isNotEmpty == true && device?.uuid != widget?.device?.uuid && device.number?.toString() == number;

  Widget _buildAffiliationInfo() => InputDecorator(
        decoration: InputDecoration(
          labelText: "Tilhørighet",
          filled: true,
          enabled: false,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            _editedAffiliation ?? _defaultAffiliation(),
            style: Theme.of(context).textTheme.subtitle2,
          ),
        ),
      );

  String _defaultAffiliation() => context.bloc<AffiliationBloc>().findEntityName(widget?.device?.number);

  InputDecorator _buildOrgAliasField() => InputDecorator(
        decoration: InputDecoration(
          labelText: "Kortnavn org.",
          filled: true,
          enabled: false,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            _editedOrgAlias ?? _defaultOrgAlias(),
            style: Theme.of(context).textTheme.subtitle2,
          ),
        ),
      );

  String _defaultOrgAlias() => organisation?.fleetMap?.alias ?? '-';

  InputDecorator _buildFunctionField() => InputDecorator(
        decoration: InputDecoration(
          labelText: "Kortnavn",
          filled: true,
          enabled: false,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            _editedFunction ?? _defaultFunction(),
            style: Theme.of(context).textTheme.subtitle2,
          ),
        ),
      );

  String _defaultFunction() => context.bloc<AffiliationBloc>().findFunction(widget?.device?.number)?.name;

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
          Device device = context.bloc<DeviceBloc>().values.firstWhere(
                (Device device) => _isSameAlias(device, alias),
                orElse: () => null,
              );
          return device != null ? "Finnes allerede" : null;
        },
      ],
    );
  }

  bool _isSameAlias(Device device, String alias) =>
      alias?.isNotEmpty == true && device?.uuid != widget?.device?.uuid && device.alias == alias;

  void _setText(TextEditingController controller, String value) {
    setText(controller, value);
    _formKey?.currentState?.save();
  }

  void _onNumberOrAliasEdit(
    String alias,
    String number, {
    bool update = true,
  }) {
    alias = emptyAsNull(alias);
    number = emptyAsNull(number);
    _editedName = alias ?? number ?? _defaultName();
    _editedAffiliation = affiliations.findEntityName(number, empty: '-') ?? _editedAffiliation;
    _editedOrgAlias = affiliations.findOrganisation(number).fleetMap?.alias ?? _editedOrgAlias;
    _editedFunction = affiliations.findFunction(number) ?? _editedFunction;
    if (update) setState(() {});
  }

  AffiliationBloc get affiliations => context.bloc<AffiliationBloc>();

  Widget _buildTypeField() {
    final defaultValue = widget.type;
    final actualValue = _getActualType(defaultValue);
    return buildDropDownField(
      attribute: 'type',
      label: 'Type enhet',
      enabled: false,
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
        );
        _formKey.currentState.save();
      },
    );
  }

  Widget _buildPointField() => PositionField(
        attribute: 'point',
        initialValue: widget?.device?.position,
        labelText: "Siste posisjon",
        hintText: 'Ingen posisjon',
        errorText: 'Posisjon må oppgis',
        enabled: false,
      );

  DeviceType _getActualType(DeviceType defaultValue) {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('type') == true
        ? DeviceModel.fromJson(values).type ?? defaultValue
        : widget?.device?.type ?? defaultValue;
  }

  String _getActualAlias() {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('alias') == true
        ? DeviceModel.fromJson(values).alias ?? widget?.device?.alias
        : widget?.device?.alias;
  }

  String _getActualNumber() {
    final values = _formKey?.currentState?.value;
    return values?.containsKey('number') == true
        ? DeviceModel.fromJson(values).number ?? widget?.device?.number
        : widget?.device?.number;
  }

  void _submit(BuildContext context) async {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      final create = widget.device == null;
      var device = create ? _createDevice() : _updateDevice();
      Navigator.pop(context, device);
    } else {
      // Show errors
      setState(() {});
    }
  }

  Device _createDevice() {
    return DeviceModel.fromJson(_formKey.currentState.value).copyWith(
      uuid: Uuid().v4(),
      status: DeviceStatus.available,
    );
  }

  Device _updateDevice() => widget.device.mergeWith(_formKey.currentState.value);
}
