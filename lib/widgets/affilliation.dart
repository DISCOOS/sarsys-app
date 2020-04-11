import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/fleet_map_service.dart';
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
  final User user;
  final Affiliation initialValue;
  final ValueChanged<Affiliation> onChanged;

  const AffiliationForm({
    Key key,
    @required this.initialValue,
    this.user,
    this.onChanged,
  }) : super(key: key);

  @override
  AffiliationFormState createState() => AffiliationFormState();
}

class AffiliationFormState extends State<AffiliationForm> {
  static const SPACING = 16.0;

  final _formKey = GlobalKey<FormBuilderState>();

  ValueNotifier<Organization> _organization = ValueNotifier(null);
  ValueNotifier<Division> _division = ValueNotifier(null);

  String _department;

  @override
  void initState() {
    super.initState();
    _department = widget.initialValue.department;
    FleetMapService().fetchOrganization(Defaults.organization)..then(_resolve);
  }

  void _resolve(Organization org) {
    if (widget.user != null) {
      if (widget.user.division != null) {
        final division = org.divisions.values.firstWhere(
          (match) => match.name == widget.user.division,
          orElse: () => null,
        );
        if (division != null) {
          if (widget.user.department != null) {
            _department = division.departments.values.firstWhere(
              (match) => match == widget.user.department,
              orElse: () => null,
            );
          }
          _organization.value = org;
          _division.value = division;
        }
      }
    } else {
      _organization.value = org;
      _division.value = org.divisions[widget.initialValue.division];
    }
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
    return ValueListenableBuilder<Organization>(
        valueListenable: _organization,
        builder: (context, org, _) {
          _update('organization', Defaults.organization);
          return _buildReadOnly(
            context,
            'organization',
            'Organisasjon',
            org?.name ?? "-",
          );
        });
  }

  FormBuilderCustomField<String> _buildReadOnly(BuildContext context, String attribute, String title, String value) {
    return FormBuilderCustomField<String>(
      attribute: attribute,
      formField: FormField<String>(
        enabled: false,
        initialValue: value,
        builder: (FormFieldState<String> field) => InputDecorator(
          decoration: InputDecoration(
            labelText: title,
            filled: true,
            enabled: false,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              value,
              style: Theme.of(context).textTheme.subhead,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivisionField() {
    return ValueListenableBuilder<Organization>(
      valueListenable: _organization,
      builder: (context, org, _) {
        final division = _update('division', _ensureDivision(org));
        return widget.user == null
            ? buildDropDownField<String>(
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
              )
            : _buildReadOnly(
                context,
                'division',
                'Distrikt',
                _division?.value?.name ?? '-',
              );
      },
    );
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
          final department = _ensureDepartment(division);
          _update('department', department);
          return widget.user == null
              ? buildDropDownField<String>(
                  attribute: 'department',
                  label: 'Avdeling',
                  items: _ensureDepartments(division),
                  initialValue: null,
                  enabled: widget.user == null,
                  onChanged: (_) => _onChanged(),
                  validators: [
                    FormBuilderValidators.required(errorText: 'Avdeling må velges'),
                  ],
                )
              : _buildReadOnly(
                  context,
                  'department',
                  'Avdeling',
                  _division?.value?.departments?.elementAt(department) ?? '-',
                );
        });
  }

  String _ensureDepartment(Division division) {
    final department = _department ?? widget.initialValue?.department;
    return (division?.departments?.containsKey(department) == true
        ? department
        : division?.departments?.keys?.first ?? Defaults.department);
  }

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
    _formKey?.currentState?.save();
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
