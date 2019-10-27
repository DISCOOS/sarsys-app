import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

class AffiliationAvatar extends StatelessWidget {
  final Affiliation affiliation;
  final double size;
  final double maxRadius;

  const AffiliationAvatar({
    Key key,
    @required this.affiliation,
    this.size = 8.0,
    this.maxRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      child: SarSysIcons.of(affiliation.organization, size: size),
      maxRadius: maxRadius,
      backgroundColor: Colors.white,
    );
  }
}

class AffiliationForm extends StatefulWidget {
  final Affiliation initialValue;
  final ValueChanged<Affiliation> onChanged;

  const AffiliationForm({
    Key key,
    @required this.initialValue,
    this.onChanged,
  }) : super(key: key);

  @override
  AffiliationFormState createState() => AffiliationFormState();
}

class AffiliationFormState extends State<AffiliationForm> {
  static const SPACING = 16.0;

  final _formKey = GlobalKey<FormBuilderState>();

  Future<Organization> _organization;
  ValueNotifier<Division> _division = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _organization = AssetsService().fetchOrganization(Defaults.organization)
      ..then((org) => _division.value = org.divisions[widget.initialValue.division]);
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildOrganizationField(),
          SizedBox(height: SPACING),
          _buildDivisionField(),
          SizedBox(height: SPACING),
          _buildDepartmentField(),
        ],
      ),
    );
  }

  Widget _buildOrganizationField() {
    return FutureBuilder<Organization>(
        future: _organization,
        builder: (context, snapshot) {
          final org = snapshot.hasData ? snapshot.data : null;
          _update('organization', Defaults.organization);
          return FormBuilderCustomField<String>(
            attribute: 'organization',
            formField: FormField<String>(
              enabled: false,
              initialValue: org?.name,
              builder: (FormFieldState<String> field) => InputDecorator(
                decoration: InputDecoration(
                  labelText: "Organisasjon",
                  filled: true,
                  enabled: false,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    org?.name ?? "-",
                    style: Theme.of(context).textTheme.subhead,
                  ),
                ),
              ),
            ),
          );
        });
  }

  Widget _buildDivisionField() {
    return FutureBuilder<Organization>(
        future: _organization,
        builder: (context, snapshot) {
          final org = snapshot.hasData ? snapshot.data : null;
          final division = _update('division', _ensureDivision(org));
          return buildDropDownField<String>(
            attribute: 'division',
            label: 'Distrikt',
            initialValue: division,
            items: _ensureDivisions(org),
            onChanged: (value) {
              if (org != null) {
                _division.value = org.divisions[value];
                _onChanged();
              }
            },
            validators: [
              FormBuilderValidators.required(errorText: 'Distrikt må velges'),
            ],
          );
        });
  }

  String _update(String attribute, String value) {
    _formKey.currentState.value[attribute] = value;
    Future.microtask(() => _formKey.currentState.fields[attribute].currentState.didChange(value));
    return value;
  }

  String _ensureDivision(Organization org) => org?.divisions?.containsKey(widget.initialValue?.division) == true
      ? widget.initialValue?.division
      : org?.divisions?.keys?.first ?? Defaults.division;

  List<DropdownMenuItem<String>> _ensureDivisions(Organization org) {
    return sortMapValues<String, Division, String>(org?.divisions ?? {}, (division) => division.name)
        .entries
        .map((division) => DropdownMenuItem<String>(
              value: "${division.key}",
              child: Text("${division.value.name}"),
            ))
        .toList();
  }

  Widget _buildDepartmentField() {
    return ValueListenableBuilder<Division>(
        valueListenable: _division,
        builder: (context, division, _) {
          _update('department', _ensureDepartment(division));
          final field = buildDropDownField<String>(
            attribute: 'department',
            label: 'Avdeling',
            items: _ensureDepartments(division),
            initialValue: null,
            onChanged: (_) => _onChanged(),
            validators: [
              FormBuilderValidators.required(errorText: 'Avdeling må velges'),
            ],
          );
          return field;
        });
  }

  String _ensureDepartment(Division division) =>
      (division?.departments?.containsKey(widget.initialValue?.department) == true
          ? widget.initialValue?.department
          : division?.departments?.keys?.first ?? Defaults.department);

  List<DropdownMenuItem<String>> _ensureDepartments(Division division) {
    return sortMapValues<String, String, String>(division?.departments ?? {})
        .entries
        .map((department) => DropdownMenuItem<String>(
              value: "${department.key}",
              child: Text("${department.value}"),
            ))
        .toList();
  }

  Affiliation save() {
    _formKey.currentState.save();
    final json = _formKey.currentState.value;
    final affiliation = Affiliation.fromJson(json);
    return affiliation;
  }

  bool validate() {
    return _formKey.currentState.validate();
  }

  void _onChanged() {
    if (widget.onChanged != null) widget.onChanged(save());
  }
}
