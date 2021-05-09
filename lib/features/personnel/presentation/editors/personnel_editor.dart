import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/presentation/widgets/affiliation.dart';
import 'package:SarSys/core/presentation/widgets/descriptions.dart';
import 'package:SarSys/features/tracking/presentation/widgets/position_field.dart';

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

  static String findPersonnelPhone(BuildContext context, Personnel personnel) {
    var phone = personnel?.phone;
    if (personnel != null && phone == null) {
      if (personnel?.tracking != null) {
        final devices = context.bloc<TrackingBloc>().devices(
          personnel?.tracking?.uuid,
          // Include closed tracks
          exclude: [],
        ).toList();
        final userId = personnel?.person?.userId;
        final apps = devices.where((d) => d.type == DeviceType.app).where((a) => a.number != null);
        phone = apps.firstWhere((a) => a.networkId == userId, orElse: () => apps.first).number;
      }
    }
    return phone;
  }
}

class _PersonnelEditorState extends State<PersonnelEditor> {
  static const SPACING = 16.0;

  final _formKey = GlobalKey<FormBuilderState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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

  bool isTemporary(BuildContext context) => context.bloc<AffiliationBloc>().isTemporary(
        widget.personnel?.affiliation?.uuid,
      );

  @override
  Widget build(BuildContext context) {
    final caption = Theme.of(context).textTheme.caption;
    return keyboardDismisser(
      context: context,
      child: Scaffold(
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
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.only(left: 16.0, right: 16.0),
              ),
              child: Text(widget.personnel == null ? 'OPPRETT' : 'OPPDATER',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (isTemporary(context)) _buildTemporaryPersonnelWarning(context),
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
      ),
    );
  }

  Widget _buildTemporaryPersonnelWarning(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                  child: Chip(
                    elevation: 4.0,
                    label: Text(
                      'Mannskap er opprettet manuelt',
                      textAlign: TextAlign.end,
                    ),
                    labelPadding: EdgeInsets.only(right: 4.0),
                    backgroundColor: Colors.grey[100],
                    avatar: Icon(
                      Icons.warning,
                      size: 16.0,
                      color: Colors.orange,
                    ),
                  ),
                  onTap: () => alert(
                        context,
                        title: "Mannskap opprettet manuelt",
                        content: TemporaryPersonnelDescription(),
                      )),
            ],
          ),
          Divider(),
        ],
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
      text ?? '-',
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
            name: 'fname',
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
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(context, errorText: 'Må fylles inn'),
              (value) => _validateName(value, _fnameController.text),
            ]),
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
            name: 'lname',
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
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(context, errorText: 'Må fylles inn'),
              (value) => _validateName(value, _lnameController.text),
            ]),
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
      name: 'status',
      label: 'Status',
      initialValue: enumName(widget?.personnel?.status ?? PersonnelStatus.alerted),
      items: PersonnelStatus.values
          .map((status) => [enumName(status), translatePersonnelStatus(status)])
          .map((status) => DropdownMenuItem(value: status[0], child: Text("${status[1]}")))
          .toList(),
      validator: FormBuilderValidators.required(context, errorText: 'Status må velges'),
    );
  }

  Widget _buildFunctionField() {
    return buildDropDownField(
      name: 'function',
      label: 'Funksjon',
      initialValue: enumName(widget?.personnel?.function ?? OperationalFunctionType.personnel),
      items: OperationalFunctionType.values
          .map((function) => [enumName(function), translateOperationalFunction(function)])
          .map((function) => DropdownMenuItem(value: function[0], child: Text("${function[1]}")))
          .toList(),
      validator: FormBuilderValidators.required(context, errorText: 'Funksjon må velges'),
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
    return PersonnelEditor.findPersonnelPhone(context, widget?.personnel);
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
      emptyText: 'Fant ingen apparater',
      selectorTitle: 'Velg apparater',
      helperText: enabled ? 'Ingen tilgjengelige' : 'Spor blir kun lagret i aksjonen',
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
      category: 'Alle',
      options: _findDevices,
      items: () => _getLocalDevices(),
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
    final test = device.searchable;
    return test.toLowerCase().contains(query ?? '') &&
        (type?.toLowerCase() == 'alle' || enumName(device.type).contains(type?.toLowerCase()));
  }

  bool _canAddDevice(Iterable<String> actual, Device match) {
    if (actual.contains(match.uuid)) {
      return true;
    }
    final bloc = context.bloc<TrackingBloc>();
    if (widget.personnel?.tracking?.uuid != null) {
      // Was device tracked by this personnel earlier?
      final trackings = bloc.find(match).map((t) => t.uuid);
      if (trackings.contains(widget.personnel.tracking.uuid)) {
        return true;
      }
    }
    return !bloc.has(match);
  }

  Widget _buildPointField() {
    final point = _toPosition();
    return PositionField(
      name: 'position',
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

  bool get hasAvailableDevices =>
      context.bloc<TrackingBloc>().findAvailablePersonnel().isNotEmpty || _getActualDevices().isNotEmpty;

  List<Device> _getLocalDevices() =>
      _formKey.currentState == null || _formKey.currentState.fields['devices'].value == null
          ? _getActualDevices()
          : List<Device>.from(
              _formKey.currentState.fields['devices'].value ?? <Device>[],
            );

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
        affiliation: affiliation,
        fname: _formKey.currentState.value['fname'],
        lname: _formKey.currentState.value['lname'],
        phone: _formKey.currentState.value['phone'],
        // Backend will use this as tuuid to create new tracking
        tracking: AggregateRef.fromType<Tracking>(Uuid().v4()),
      );

  Personnel _updatePersonnel(Affiliation affiliation) =>
      widget.personnel.mergeWith(_formKey.currentState.value).copyWith(
            affiliation: affiliation,
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
