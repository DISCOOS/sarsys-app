

import 'dart:async';
import 'dart:io';

import 'package:SarSys/features/affiliation/affiliation_utils.dart';
import 'package:SarSys/features/affiliation/domain/entities/FleetMap.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Passcodes.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/core/app_controller.dart';
import 'package:SarSys/core/proj4d.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_search.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/core/domain/models/Location.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart' as sarsys;
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';
import 'package:SarSys/core/domain/models/converters.dart';
import 'package:SarSys/features/mapping/data/services/geocode_services.dart';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/tracking/presentation/widgets/position_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:SarSys/features/unit/presentation/widgets/unit_widgets.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/extensions.dart';

class OperationEditor extends StatefulWidget {
  final sarsys.Point? ipp;
  final Incident? incident;
  final Operation? operation;

  const OperationEditor({
    Key? key,
    this.ipp,
    this.incident,
    this.operation,
  }) : super(key: key);

  @override
  _OperationEditorState createState() => _OperationEditorState();
}

class _OperationEditorState extends State<OperationEditor> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormBuilderState>();
  final _tgCatalog = ValueNotifier(<String>[]);

  int _currentStep = 0;
  bool _isExercise = false;
  bool _rememberUnits = true;
  bool _rememberTalkGroups = true;

  Location? _ipp;
  Location? _meetup;

  MapSearchEngine? _engine;

  TextEditingController? _ippController;
  TextEditingController? _meetupController;

  List<String>? _templates;

  get createNew => widget.incident == null;

  @override
  void initState() {
    super.initState();
    _ippController = TextEditingController(text: _ipp?.description ?? '');
    _meetupController = TextEditingController(text: _meetup?.description ?? '');
    _templates ??= context.read<AppConfigBloc>().config!.units;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _engine = MapSearchEngine(
      Provider.of<Client>(context),
      Provider.of<AppController>(context),
    );
    _initLocation();
    _updateDescriptions();
    _isExercise = widget.incident?.exercise ?? false;

    final org = context.read<AffiliationBloc>().findUserOrganisation();
    final catalogs = (org!.fleetMap!.catalogs!.map((e) => e.name!) ?? []).toList()..sort();
    _tgCatalog.value = catalogs;
  }

  void _initLocation() {
    _ipp = widget?.operation?.ipp ?? _toLocation(_ipp, widget.ipp);
    _meetup = widget?.operation?.meetup ?? _toLocation(_meetup, widget.ipp);
  }

  void _setMeetupToMe() async {
    _meetup = _toLocation(
      _meetup,
      LocationService.toPoint(LocationService().current),
    );
    _updateField('meetup', toPosition(_meetup!.point));
    _meetup = await _updateDescriptionFromPoint(
      _meetup!,
      'meetup_description',
      _meetupController!,
      point: _meetup!.point,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _setIppToMe() async {
    _ipp = _toLocation(
      _ipp,
      LocationService.toPoint(LocationService().current),
    );
    _updateField('ipp', toPosition(_ipp!.point));
    _ipp = await _updateDescriptionFromPoint(
      _ipp!,
      'ipp_description',
      _ippController!,
      point: _ipp!.point,
    );
    if (mounted) {
      setState(() {});
    }
  }

  bool _isDescriptionEmpty(Location? location, TextEditingController controller) =>
      emptyAsNull(controller.text ?? location?.description) == null;

  void _updateDescriptions() async {
    if (_isDescriptionEmpty(_ipp, _ippController!) && _ipp?.point?.isNotEmpty == true) {
      _ipp = await _updateDescriptionFromPoint(
        _ipp!,
        'ipp_description',
        _ippController!,
        point: _ipp!.point,
      );
    }
    if (_isDescriptionEmpty(_meetup, _meetupController!) == null && _meetup?.point?.isNotEmpty == true) {
      _meetup = await _updateDescriptionFromPoint(
        _meetup!,
        'meetup_description',
        _meetupController!,
        point: _meetup!.point,
      );
    }
  }

  @override
  void dispose() {
    _ippController!.dispose();
    _meetupController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    return keyboardDismisser(
      context: context,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(createNew ? 'Ny aksjon' : 'Endre aksjon'),
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
              child: Text(createNew ? 'OPPRETT' : 'OPPDATER', style: TextStyle(fontSize: 14.0, color: Colors.white)),
              onPressed: () => _submit(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          reverse: _currentStep > 1,
          child: FormBuilder(
            key: _formKey,
            child: Column(
              children: <Widget>[
                Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  physics: ClampingScrollPhysics(),
                  onStepTapped: (int step) {
                    setState(() => _currentStep = step);
                    FocusScope.of(context).unfocus();
                  },
                  onStepContinue: _currentStep < 2 ? () => setState(() => _currentStep += 1) : null,
                  onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep -= 1) : null,
                  controlsBuilder: (BuildContext context, {VoidCallback? onStepContinue, VoidCallback? onStepCancel}) {
                    return Container();
                  },
                  steps: [
                    _buildGeneralStep(),
                    _buildPoiStep(),
                    _buildClassificationStep(),
                    if (_tgCatalog.value.isNotEmpty) _buildTGStep(),
                    if (createNew) _buildPreparationStep(),
                    _buildReferenceStep(),
                  ],
                ),
                Container(
                  padding: EdgeInsets.only(
                    bottom: mediaQuery.viewInsets.bottom / 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Step _buildReferenceStep() {
    return Step(
      title: Text('Referanser'),
      subtitle: Text('Oppgi hendelsesnummer oppgitt fra rekvirent'),
      content: _buildReferenceField(),
      isActive: _currentStep >= 0,
      state: _isValid(['reference'])
          ? (_currentStep > (createNew ? 5 : 4) ? StepState.complete : StepState.indexed)
          : StepState.error,
    );
  }

  Step _buildPreparationStep() {
    return Step(
      title: Text('Forberedelser'),
      subtitle: Text('Oppgi enheter som skal opprettes automatisk'),
      content: Column(
        children: <Widget>[
          _buildUnitsTemplateField(),
          _buildRememberUnitsField(),
        ],
      ),
      isActive: _currentStep >= 0,
      state: (_currentStep > 4 ? StepState.complete : StepState.indexed),
    );
  }

  Step _buildTGStep() {
    return Step(
      title: Text('Talegrupper'),
      subtitle: Text('Oppgi hvilke talegrupper som skal spores'),
      content: Column(
        children: <Widget>[
          _buildTGField(),
          SizedBox(height: 16.0),
          _buildRememberTalkGroupsField(),
        ],
      ),
      isActive: _currentStep >= 0,
      state: _isValid(['talkgroups']) ? (_currentStep > 3 ? StepState.complete : StepState.indexed) : StepState.error,
    );
  }

  Step _buildPoiStep() {
    return Step(
      title: Text('Plasseringer'),
      subtitle: Text('Oppgi hendelsens plasseringer'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _buildIPPField(),
          _buildIPPDescriptionField(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildCopyFromMeetupButton(),
              TextButton.icon(
                icon: Icon(Icons.my_location),
                label: Text("Min posisjon"),
                onPressed: () => _setIppToMe(),
              ),
            ],
          ),
          SizedBox(height: 16.0),
          _buildMeetupField(),
          _buildMeetupDescriptionField(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildCopyFromIppButton(),
              TextButton.icon(
                icon: Icon(Icons.my_location),
                label: Text("Min posisjon"),
                onPressed: () => _setMeetupToMe(),
              ),
            ],
          ),
        ],
      ),
      isActive: _currentStep >= 0,
      state:
          _isValid(['ipp', 'meetup']) ? (_currentStep > 2 ? StepState.complete : StepState.indexed) : StepState.error,
    );
  }

  Step _buildClassificationStep() {
    return Step(
      title: Text('Klassifisering'),
      subtitle: Text('Oppgi type og status'),
      content: Column(
        children: [
          buildTwoCellRow(_buildIncidentTypeField(), _buildIncidentStatusField()),
          SizedBox(height: 16.0),
          buildTwoCellRow(_buildOperationTypeField(), _buildOperationStatusField()),
        ],
      ),
      isActive: _currentStep >= 0,
      state: _isValid(['incident_type', 'incident_status']) && _isValid(['operation_type', 'operation_status'])
          ? (_currentStep > 1 ? StepState.complete : StepState.indexed)
          : StepState.error,
    );
  }

  Step _buildGeneralStep() {
    return Step(
      title: Text('Generelt'),
      subtitle: Text('Oppgi stedsnavn og begrunnelse'),
      content: Column(
        children: [
          _buildNameField(),
          SizedBox(height: 16.0),
          _buildJustificationField(),
          SizedBox(height: 16.0),
          _buildOccurredField(),
          SizedBox(height: 16.0),
          _buildExerciseField()
        ],
      ),
      isActive: _currentStep >= 0,
      state: _isValid(['name', 'justification', 'occurred'])
          ? (_currentStep > 0 ? StepState.complete : StepState.indexed)
          : StepState.error,
    );
  }

  FormBuilderDateTimePicker _buildOccurredField() {
    final now = DateTime.now();
    return FormBuilderDateTimePicker(
      name: "occurred",
//      initialTime: null,
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialValue: widget?.incident?.occurred ?? now,
      format: DateFormat("yyyy-MM-dd HH:mm"),
//      resetIcon: null,
      autocorrect: true,
      decoration: InputDecoration(
        labelText: "Hendelsestidspunkt",
        contentPadding: EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 12.0),
        filled: true,
      ),
      keyboardType: TextInputType.datetime,
      validator: FormBuilderValidators.compose([
        (value) {
          return value!.isAfter(DateTime.now()) ? "Du kan ikke sette klokkeslett frem i tid" : null;
        }
      ]),
      valueTransformer: (dt) => dt.toString(),
    );
  }

  Widget _buildExerciseField() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: ListTile(
              enabled: createNew,
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Øvelse",
                style: Theme.of(context).textTheme.bodyText2,
              ),
              subtitle: Text(
                "Kan ikke endres etter opprettelse",
              ),
            ),
          ),
          Switch(
            value: _isExercise,
            onChanged: createNew
                ? (value) => setState(() {
                      _isExercise = !_isExercise;
                    })
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return FormBuilderTextField(
      maxLines: 1,
      name: 'name',
      initialValue: widget?.incident?.name,
      decoration: new InputDecoration(
        labelText: 'Stedsnavn',
        hintText: 'Oppgi stedsnavn',
        filled: true,
      ),
      onChanged: (value) {
        if (emptyAsNull(_ipp?.description) == null) {
          _ipp = _toLocation(_ipp, widget.ipp);
          _updateDescription('ipp_description', value, _ippController);
        }
      },
      validator: FormBuilderValidators.required(context, errorText: 'Navn må fylles inn'),
      autocorrect: true,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 16.0),
    );
  }

  Widget _buildJustificationField() {
    return FormBuilderTextField(
      maxLines: 3,
      name: 'justification',
      initialValue: widget?.operation?.justification,
      decoration: new InputDecoration(
        labelText: 'Begrunnelse',
        hintText: 'Oppgi begrunnelse',
        filled: true,
      ),
      validator: FormBuilderValidators.required(context, errorText: 'Begrunnelse må fylles inn'),
      autocorrect: true,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 16.0),
    );
  }

  Widget _buildReferenceField() {
    return FormBuilderTextField(
      maxLines: 1,
      name: 'reference',
      initialValue: widget?.operation?.reference,
      decoration: new InputDecoration(
        hintText: 'SAR- eller AMIS-nummer',
        filled: true,
      ),
    );
  }

  Widget _buildIncidentTypeField() {
    return buildDropDownField<String>(
      name: 'incident_type',
      label: 'Type hendelse',
      initialValue: enumName(widget?.incident?.type ?? IncidentType.lost),
      items: IncidentType.values
          .map((type) => [enumName(type), translateIncidentType(type)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validator: FormBuilderValidators.required(context, errorText: 'Type må velges'),
    );
  }

  Widget _buildOperationTypeField() {
    return buildDropDownField(
      name: 'operation_type',
      label: 'Disiplin',
      initialValue: enumName(widget?.operation?.type ?? OperationType.search),
      items: OperationType.values
          .map((type) => [enumName(type), translateOperationType(type)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validator: FormBuilderValidators.required(context, errorText: 'Disiplin må velges'),
    );
  }

  Widget _buildIncidentStatusField() {
    return buildDropDownField(
      name: 'incident_status',
      label: 'Status',
      initialValue: enumName(widget?.incident?.status ?? IncidentStatus.registered),
      items: IncidentStatus.values
          .map((status) => [enumName(status), translateIncidentStatus(status)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validator: FormBuilderValidators.required(context, errorText: 'Status må velges'),
    );
  }

  Widget _buildOperationStatusField() {
    return buildDropDownField(
      name: 'operation_status',
      label: 'Fase',
      initialValue: enumName(widget?.operation?.status ?? OperationStatus.planned),
      items: OperationStatus.values
          .map((status) => [enumName(status), translateOperationStatus(status)])
          .map((type) => DropdownMenuItem(value: type[0], child: Text("${type[1]}")))
          .toList(),
      validator: FormBuilderValidators.required(context, errorText: 'Status må velges'),
    );
  }

  Widget _buildIPPField() => PositionField(
        name: 'ipp',
        initialValue: toPosition(
          _ipp?.point,
          defaultValue: widget.ipp,
        ),
        labelText: "IPP",
        hintText: 'Velg IPP',
        errorText: 'IPP må oppgis',
        optional: false,
        onChanged: (Position position) async {
          _ipp = _toLocation(_ipp, position.geometry);
          if (emptyAsNull(_ipp!.description) == null) {
            _ipp = await _updateDescriptionFromPoint(
              _ipp!,
              'ipp_description',
              _ippController!,
              point: position.geometry,
            );
          }
          _saveAndSetState();
        },
      );

  void _saveAndSetState() {
    if (mounted) {
      _formKey.currentState!.save();
      setState(() {});
    }
  }

  Widget _buildMeetupField() => PositionField(
        name: 'meetup',
        initialValue: toPosition(
          _meetup?.point,
          defaultValue: widget.ipp,
        ),
        labelText: "Oppmøtested",
        hintText: 'Velg oppmøtested',
        errorText: 'Oppmøtested må oppgis',
        optional: false,
        onChanged: (Position position) async {
          _meetup = _toLocation(_meetup, position.geometry);
          _meetup = await _updateDescriptionFromPoint(
            _meetup!,
            'meetup_description',
            _meetupController!,
            point: position.geometry,
          );
          _saveAndSetState();
        },
      );

  Widget _buildIPPDescriptionField() => FormBuilderTextField(
        maxLines: 1,
        name: 'ipp_description',
        controller: _ippController,
        decoration: InputDecoration(
          labelText: "Stedsnavn",
          filled: true,
          suffixIcon: GestureDetector(
            child: Icon(Icons.search),
            onTap: () async {
              if (_ipp!.point is sarsys.Point) {
                _ipp = await _updateDescriptionFromPoint(
                  _ipp!,
                  'ipp_description',
                  _ippController!,
                  search: true,
                );
                if (mounted) {
                  setState(() {});
                }
              }
            },
          ),
        ),
        autocorrect: true,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 16.0),
      );

  Widget _buildMeetupDescriptionField() => FormBuilderTextField(
        maxLines: 1,
        name: 'meetup_description',
        controller: _meetupController,
        decoration: InputDecoration(
            labelText: "Stedsnavn",
            filled: true,
            suffixIcon: GestureDetector(
              child: Icon(Icons.search),
              onTap: () async {
                if (_meetup!.point is sarsys.Point) {
                  _meetup = await _updateDescriptionFromPoint(
                    _meetup!,
                    'meetup_description',
                    _meetupController!,
                    search: true,
                  );
                }
                if (mounted) {
                  setState(() {});
                }
              },
            )),
        autocorrect: true,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 16.0),
      );

  Widget _buildCopyFromIppButton() => TextButton.icon(
        icon: Icon(Icons.content_copy),
        label: Text("IPP"),
        onPressed: _ipp is Location
            ? () {
                _meetup = _ipp!.cloneWith();
                _updateField('meetup', toPosition(_meetup!.point));
                _updateDescription(
                  'meetup_description',
                  _meetup!.description,
                  _meetupController,
                );
                setState(() {});
              }
            : null,
      );

  Widget _buildCopyFromMeetupButton() => TextButton.icon(
        icon: Icon(Icons.content_copy),
        label: Text("Oppmøte"),
        onPressed: _meetup is Location
            ? () {
                _ipp = _meetup!.cloneWith();
                _updateField('ipp', toPosition(_ipp!.point));
                _updateDescription(
                  'ipp_description',
                  _ipp!.description,
                  _ippController,
                );
                setState(() {});
              }
            : null,
      );

  Widget _buildTGField() {
    final config = context.read<AppConfigBloc>().config!;
    final catalogs = widget?.operation?.talkgroups ??
        FleetMapTalkGroupConverter.toList(
          config.talkGroups,
        );
    return buildChipsField<TalkGroup>(
      name: 'talkgroups',
      labelText: 'Lytt til',
      hintText: 'Velg talegrupper',
      selectorLabel: 'Lytt til',
      selectorTitle: 'Velg talegrupper',
      emptyText: 'Ingen talegrupper tilgjengelig',
      builder: (context, tg) => Chip(label: Text(tg.name!)),
      categories: catalogs.map(
        (c) => DropdownMenuItem<String>(
          value: c.name,
          child: Text(c.name!),
        ),
      ),
      category: config.talkGroupCatalog,
      items: () =>
          widget?.operation?.talkgroups ??
          FleetMapTalkGroupConverter.toList(
            config.talkGroups,
          ),
      options: (String? category, String? query) {
        final fleetMap = getFleetMap();
        if (fleetMap != null) {
          if (query?.isNotEmpty == true) {
            return AffiliationUtils.findTalkGroups(
              AffiliationUtils.findCatalog(fleetMap, category),
              query!,
            );
          }
          return getTgGroups(
            category ?? _formKey.currentState!.fields["tgCatalog"]!.value ?? config.talkGroupCatalog,
          );
        }
        return <TalkGroup>[];
      },
    );
  }

  FleetMap? getFleetMap() {
    return context.read<AffiliationBloc>().findUserOrganisation()?.fleetMap;
  }

  List<TalkGroup> getTgGroups(String catalog) {
    return getFleetMap()?.catalogs?.firstWhereOrNull((c) => c.name == catalog)?.groups ?? <TalkGroup>[];
  }

  Widget _buildRememberTalkGroupsField() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Husk talegrupper",
                style: Theme.of(context).textTheme.bodyText2,
              ),
              subtitle: Text(
                "Liste kan endres i Nødnettsoppsett",
              ),
            ),
          ),
          Switch(
            value: _rememberTalkGroups,
            onChanged: (value) => setState(() {
              _rememberTalkGroups = !_rememberTalkGroups;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitsTemplateField() {
    final enabled = true; //hasAvailableDevices;
    final types = List.from(UnitType.values)
      ..sort(
        (a, b) => enumName(a).compareTo(enumName(b)),
      );
    return buildChipsField<String>(
      name: 'units',
      enabled: enabled,
      labelText: 'Enheter',
      selectorLabel: 'Enheter',
      hintText: 'Søk etter enheter',
      selectorTitle: 'Velg enheter',
      emptyText: 'Fant ingen enheter',
      helperText: 'Listen kan endres i Hendelsesopppsett',
      builder: (context, unit) => UnitTemplateChip(unit: unit),
      categories: [
        DropdownMenuItem<String>(
          value: 'alle',
          child: Text('Alle'),
        ),
        ...types.map(
          (type) => DropdownMenuItem<String>(
            value: enumName(translateUnitType(type)),
            child: Text(translateUnitType(type).capitalize()),
          ),
        ),
      ],
      category: 'alle',
      options: _findUnits,
      items: () => _templates,
      onChanged:  (templates) => _templates!
        ..clear()
        ..addAll(templates!),

    );
  }

  List<String> _findUnits(String? type, String? query) {
    var lowercaseQuery = query!.toLowerCase();
    final templates = asUnitTemplates(query, 15);
    return templates
        .where((template) =>
            (template.toLowerCase().contains(type!.toLowerCase())) || type.contains('alle'))
        .where((template) => template.toLowerCase().contains(lowercaseQuery))
        .toList(growable: false);
  }

  Widget _buildRememberUnitsField() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                "Husk enheter",
                style: Theme.of(context).textTheme.bodyText2,
              ),
            ),
          ),
          Switch(
            value: _rememberUnits,
            onChanged: (value) => setState(() {
              _rememberUnits = !_rememberUnits;
            }),
          ),
        ],
      ),
    );
  }

  Location _toLocation(Location? location, sarsys.Point? point) {
    return location?.cloneWith(
          point: point,
        ) ??
        Location(point: point);
  }

  Future<Location> _updateDescriptionFromPoint(
    Location location,
    String attribute,
    TextEditingController controller, {
    sarsys.Point? point,
    bool search = false,
  }) async {
    try {
      final description = await _lookup(
        point ?? location.point,
        search: search,
        query: emptyAsNull(controller.text) ?? toUTM(location.point, empty: null),
      );
      if (mounted) {
        _updateDescription(attribute, description, controller);
      }
      return location.cloneWith(
        description: description,
      );
    } on SocketException {
      // Discard connection errors
    }
    return location;
  }

  void _updateField<T>(
    String name,
    T value,
  ) {
    if (_formKey.currentState != null) {
      _formKey.currentState!.patchValue({name: value});
      _formKey.currentState!.fields[name]!.didChange(value);
      _formKey.currentState!.save();
    }
  }

  void _updateDescription(
    String attribute,
    String? description,
    TextEditingController? controller,
  ) {
    _updateField(attribute, description);
    setText(controller, description);
  }

  Future<String?> _lookup(sarsys.Point? point, {bool search = false, String? query}) async {
    if (point?.isNotEmpty == true) {
      if (search) {
        final result = await showSearch(
            context: context,
            query: emptyAsNull(query) == null ? toUTM(point, empty: null) : query,
            delegate: MapSearchDelegate(
              engine: _engine,
              center: toLatLng(point),
              controller: MapWidgetController(),
            ));
        return _toAddress(result);
      }
      final results = await _engine!.lookup(point!);
      if (results.isNotEmpty) {
        var idx = 0;
        var current = 0;
        var distance = double.infinity;
        results.forEach((result) {
          final next = ProjMath.eucledianDistance(
            point.lat!,
            point.lon!,
            result.latitude!,
            result.longitude!,
          );
          if (next < distance) {
            current = idx;
            distance = next;
          }
          idx++;
        });
        final closest = results.elementAt(current);
        return _toAddress(closest);
      }
    }
    return null;
  }

  String? _toAddress(GeocodeResult? closest) {
    return closest != null
        ? '${[
            closest.title,
            closest.address,
          ].where((element) => element != null).join(', ')}'
        : null;
  }

  Position? toPosition(sarsys.Point? point, {sarsys.Point? defaultValue}) {
    return point is sarsys.Point
        ? Position.fromPoint(
            point ?? defaultValue!,
            source: PositionSource.manual,
          )
        : null;
  }

  _isValid(List<String> fields) {
    var state = _formKey.currentState;
    return _formKey.currentState == null ||
        fields.where((name) => state!.fields[name] == null || !state.fields[name]!.hasError).length == fields.length;
  }

  Map<String, dynamic> _toIncidentJson(
    Map<String, dynamic> json, {
    Incident? current,
  }) {
    return {
      'type': json['incident_type'],
      'status': json['incident_status'],
      'summary': json['justification'],
      'resolution': enumName(current?.resolution ?? IncidentResolution.unresolved),
    }..addAll(json);
  }

  Map<String, dynamic> _toOperationJson(
    Map<String, dynamic> json, {
    Operation? current,
  }) {
    var id = 0;
    // Ensure EntityObject contract is fulfilled
    json.addAll({
      'talkgroups': List.from(json['talkgroups'] ?? [])
          .map((tg) => Map.from((tg as TalkGroup).toJson())..addAll({'id': '${id++}'}))
          .toList()
    });

    return {
      'type': json['operation_type'],
      'status': json['operation_status'],
      'resolution': enumName(current?.resolution ?? OperationResolution.unresolved),
      'passcodes': current?.passcodes?.toJson() ?? Passcodes.random(5).toJson(),
    }..addAll(json);
  }

  Map<String, dynamic> _toJson({String? uuid}) {
    Map<String, dynamic> json = Map.from(_formKey.currentState!.value);
    if (uuid != null) {
      json['uuid'] = uuid;
    }
    json['ipp'] = Location(
      point: Position.fromJson(json['ipp']).geometry,
      description: emptyAsNull(json['ipp_description']),
    ).toJson();
    json['meetup'] = Location(
      point: Position.fromJson(json['meetup']).geometry,
      description: emptyAsNull(json['meetup_description']),
    ).toJson();
    json['exercise'] = _isExercise;
    return json;
  }

  void _submit(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_rememberTalkGroups) {
        final list = _formKey.currentState!.value['talkgroups'] ?? <String>[];
        final talkGroups = List<String>.from(
          list.map((tg) => tg.name),
        );
        await context.read<AppConfigBloc>().updateWith(
              talkGroups: talkGroups,
            );
      }

      if (createNew) {
        await _submitNew(context);
      } else {
        await _submitUpdate(context);
      }
    } else {
      // Show errors
      setState(() {});
    }
  }

  Future _submitNew(BuildContext context) async {
    final units = List<String>.from(_formKey.currentState!.value['units']);
    if (_rememberUnits) {
      await context.read<AppConfigBloc>().updateWith(units: units);
    }
    final incident = _createIncident();
    Navigator.pop(
      context,
      OperationEditorResult(
        incident: incident,
        operation: _createOperation(incident.uuid),
        units: units,
      ),
    );
  }

  Future _submitUpdate(BuildContext context) async {
    final incident = widget.incident!.mergeWith(_toIncidentJson(
      _toJson(),
      current: widget.incident,
    ));
    final operation = widget.operation!.mergeWith(_toOperationJson(
      _toJson(),
      current: widget.operation,
    ));
    if (_shouldCancel(incident.resolution)) {
      await _prompt(
        context,
        title: 'Bekreft kansellering',
        message: 'Dette vil stoppe alle sporinger og sette status til Kansellert',
        incident: incident,
        operation: operation,
      );
    } else if (_shouldResolve(incident.resolution)) {
      await _prompt(
        context,
        title: "Bekreft løsning",
        message: "Dette vil stoppe alle sporinger og sette status til Løst",
        incident: incident,
        operation: operation,
      );
    } else {
      Navigator.pop<OperationEditorResult>(
        context,
        OperationEditorResult(
          incident: incident,
          operation: operation,
        ),
      );
    }
  }

  Future _prompt(
    BuildContext context, {
    required String title,
    required String message,
    required Incident incident,
    required Operation operation,
  }) async {
    final proceed = await prompt(
      context,
      "Bekreft løsning",
      "Dette vil stoppe alle sporinger og sette status til Løst",
    );
    if (proceed) {
      Navigator.pop<OperationEditorResult>(
        context,
        OperationEditorResult(
          incident: incident,
          operation: operation,
        ),
      );
    }
  }

  bool _shouldResolve(IncidentResolution? next) =>
      IncidentStatus.closed != widget?.incident?.status && IncidentResolution.resolved == next;

  bool _shouldCancel(IncidentResolution? next) =>
      IncidentStatus.closed != widget?.incident?.status && IncidentResolution.cancelled == next;

  Incident _createIncident() => IncidentModel.fromJson(_toIncidentJson(_toJson(
        uuid: Uuid().v4(),
      )));

  Operation _createOperation(String? iuuid) => OperationModel.fromJson(_toOperationJson(_toJson(
        uuid: Uuid().v4(),
      )))
          .withAuthor(
            context.read<UserBloc>().userId,
          )
          .copyWith(
            incident: AggregateRef.fromType<Incident>(iuuid!),
          );
}

class OperationEditorResult {
  OperationEditorResult({
    required this.incident,
    required this.operation,
    this.units,
  });
  final Incident incident;
  final Operation operation;
  final List<String>? units;
}
