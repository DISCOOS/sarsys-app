import 'dart:async';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:SarSys/core/extensions.dart';

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
      child: SarSysIcons.of(affiliation.orgId, size: size),
      maxRadius: maxRadius,
      backgroundColor: Colors.white,
    );
  }
}

class AffiliationView extends StatelessWidget {
  const AffiliationView({
    @required this.future,
    @required this.affiliation,
    this.onMessage,
    this.onComplete,
    Key key,
  }) : super(key: key);

  final Affiliation affiliation;
  final VoidCallback onComplete;
  final MessageCallback onMessage;
  final FutureOr<Organization> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Organization>(
      future: future,
      builder: (context, snapshot) {
        return Row(
          children: <Widget>[
            Expanded(
              child: buildCopyableText(
                context: context,
                label: "Tilhørighet",
                icon: SarSysIcons.of(affiliation?.orgId),
                value: snapshot.hasData ? snapshot.data.toFullName(affiliation) : '-',
                onMessage: onMessage,
                onComplete: onComplete,
              ),
            ),
          ],
        );
      },
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

  Future<Organization> _future;
  ValueNotifier<Organization> _org = ValueNotifier(null);
  ValueNotifier<Division> _division = ValueNotifier(null);

  String _depId;

  @override
  void initState() {
    super.initState();
    _depId = widget.initialValue.depId;
  }

  @override
  void didChangeDependencies() {
    _future = FleetMapService().fetchOrganization(Defaults.orgId)..then(_resolve);
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(AffiliationForm oldWidget) {
    if (oldWidget.user != widget.user) {
      _future = FleetMapService().fetchOrganization(Defaults.orgId)..then(_resolve);
    }
    super.didUpdateWidget(oldWidget);
  }

  void _resolve(Organization org) {
    var division = org.divisions[widget.initialValue.divId];
    if (widget.user != null) {
      if (widget.user.division != null) {
        division = org.divisions.values.firstWhere(
          (match) => match.name == widget.user.division,
          orElse: () => null,
        );
        if (division != null) {
          if (widget.user.department != null) {
            _depId = division.departments.values.firstWhere(
              (match) => match == widget.user.department,
              orElse: () => null,
            );
          }
        }
      }
    }
    _org.value = org;
    _formKey.currentState.value['org'] = org.id;
    _division.value = division;
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
        future: _future,
        builder: (context, snapshot) {
          final org = snapshot.hasData ? snapshot.data : null;
          _update(ORG_FIELD, org?.id);
          return _buildReadOnly(
            context,
            ORG_FIELD,
            'Organisasjon',
            org?.name,
            org?.id,
          );
        });
  }

  static const ORG_FIELD = 'orgId';
  static const DIV_FIELD = 'divId';
  static const DEP_FIELD = 'depId';

  Widget _buildDivisionField() {
    return ValueListenableBuilder<Organization>(
      valueListenable: _org,
      builder: (context, org, _) {
        final divId = _update(DIV_FIELD, _ensureDivId(org));
        final division = org?.divisions?.elementAt(divId);
        return org != null && editable
            ? buildDropDownField<String>(
                attribute: DIV_FIELD,
                label: 'Distrikt',
                initialValue: divId,
                items: _ensureDivisions(org),
                onChanged: (selected) {
                  if (org != null) {
                    _division.value = org.divisions[selected];
                    _onChanged();
                  }
                },
                validators: [
                  FormBuilderValidators.required(errorText: 'Distrikt må velges'),
                ],
              )
            : _buildReadOnly(
                context,
                DIV_FIELD,
                'Distrikt',
                division?.name,
                divId,
              );
      },
    );
  }

  Widget _buildDepartmentField() {
    return ValueListenableBuilder<Division>(
        valueListenable: _division,
        builder: (context, division, _) {
          final depId = _update(DEP_FIELD, _ensureDepId(division));
          return editable
              ? buildDropDownField<String>(
                  attribute: DEP_FIELD,
                  label: 'Avdeling',
                  items: _ensureDepartments(division),
                  initialValue: _depId,
                  enabled: editable,
                  onChanged: (selected) {
                    _depId = selected;
                    _onChanged();
                  },
                  validators: [
                    FormBuilderValidators.required(errorText: 'Avdeling må velges'),
                  ],
                )
              : _buildReadOnly(
                  context,
                  DEP_FIELD,
                  'Avdeling',
                  _toDepartment(division, depId),
                  depId,
                );
        });
  }

  String _toDepartment(Division division, String depId) => division?.departments?.elementAt(depId) ?? '-';

  FormBuilderCustomField<String> _buildReadOnly(
    BuildContext context,
    String attribute,
    String label,
    String title,
    String value,
  ) {
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
              title ?? '-',
              style: Theme.of(context).textTheme.subtitle2,
            ),
          ),
        ),
      ),
    );
  }

  bool get editable => widget.user == null;

  String _update(String attribute, String value) {
    _formKey.currentState.value[attribute] = value;
    Future.microtask(() => _formKey.currentState.fields[attribute]?.currentState?.didChange(value));
    return value;
  }

  String _ensureDivId(Organization org) {
    final divId = _formKey.currentState.value[DIV_FIELD] ?? widget.initialValue?.divId ?? Defaults.depId;
    return org?.divisions?.containsKey(divId) == true ? divId : org?.divisions?.keys?.first;
  }

  String _ensureDepId(Division division) {
    final depId = _depId ?? widget.initialValue?.depId ?? Defaults.depId;
    return (division?.departments?.containsKey(depId) == true ? depId : division?.departments?.keys?.first);
  }

  List<DropdownMenuItem<String>> _ensureDivisions(Organization org) {
    return sortMapValues<String, Division, String>(org?.divisions ?? {}, (division) => division.name)
        .entries
        .map((division) => DropdownMenuItem<String>(
              value: "${division.key}",
              child: Text("${division.value.name}"),
            ))
        .toList();
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
