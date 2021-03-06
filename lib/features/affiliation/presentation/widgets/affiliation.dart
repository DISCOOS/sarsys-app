import 'dart:async';

import 'package:SarSys/core/callbacks.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/utils/ui.dart';

class AffiliationAvatar extends StatelessWidget {
  final Affiliation affiliation;
  final double size;
  final double maxRadius;

  AffiliationAvatar({
    Key key,
    @required this.affiliation,
    this.size = 8.0,
    this.maxRadius,
  }) : super(key: key) {
    assert(affiliation != null, "Affiliation is required");
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      child: SarSysIcons.of(
        context.read<AffiliationBloc>().orgs[affiliation.org?.uuid]?.prefix,
        size: size,
      ),
      maxRadius: maxRadius,
      backgroundColor: Colors.white,
    );
  }
}

class AffiliationView extends StatelessWidget {
  const AffiliationView({
    @required this.affiliation,
    this.onMessage,
    this.onComplete,
    Key key,
  }) : super(key: key);

  final Affiliation affiliation;
  final VoidCallback onComplete;
  final MessageCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Tilhørighet",
            icon: SarSysIcons.of(context.read<AffiliationBloc>().orgs[affiliation?.org?.uuid]?.prefix),
            value: context.read<AffiliationBloc>().toName(affiliation),
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
      ],
    );
  }
}

class AffiliationForm extends StatefulWidget {
  final User user;
  final Affiliation value;
  final ValueChanged<Affiliation> onChanged;

  const AffiliationForm({
    Key key,
    @required this.value,
    this.user,
    this.onChanged,
  }) : super(key: key);

  @override
  AffiliationFormState createState() => AffiliationFormState();
}

class AffiliationFormState extends State<AffiliationForm> {
  static const SPACING = 16.0;
  static const ORG_FIELD = 'orguuid';
  static const DIV_FIELD = 'divuuid';
  static const DEP_FIELD = 'depuuid';

  final _formKey = GlobalKey<FormBuilderState>();

  ValueNotifier<String> _org = ValueNotifier(null);
  ValueNotifier<String> _div = ValueNotifier(null);
  String _dep;
  Affiliation _affiliation;

  Department get dep => _dep == null ? null : toDep(_dep);
  Division get div => _div.value == null ? null : toDiv(_div.value);
  Organisation get org => _org.value == null ? null : toOrg(_org.value);

  Organisation toOrg(String ouuid) => context.read<AffiliationBloc>().orgs[ouuid];
  Division toDiv(String divuuid) => context.read<AffiliationBloc>().divs[divuuid];
  Department toDep(String depuuid) => context.read<AffiliationBloc>().deps[depuuid];

  @override
  void initState() {
    super.initState();
    _apply(widget.value);
  }

  @override
  void didUpdateWidget(AffiliationForm oldWidget) {
    if (oldWidget.user != widget.user) {
      _apply(context.read<AffiliationBloc>().findUserAffiliation(
            userId: widget.user.userId,
          ));
    }
    super.didUpdateWidget(oldWidget);
  }

  void _apply(Affiliation affiliation) {
    _affiliation = affiliation;
    _org.value = _affiliation.org?.uuid;
    _div.value = _affiliation.div?.uuid;
    _dep = _affiliation.dep?.uuid;
  }

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildOrganisationField(),
          SizedBox(height: SPACING),
          _buildDivisionField(),
          SizedBox(height: SPACING),
          _buildDepartmentField(),
        ],
      ),
    );
  }

  Widget _buildOrganisationField() {
    final ouuid = _update(ORG_FIELD, org?.uuid);
    final orgs = _buildOrgItems();
    return editable
        ? buildDropDownField<String>(
            name: ORG_FIELD,
            label: 'Organisasjon',
            initialValue: ouuid,
            items: orgs,
            onChanged: (String selected) {
              _org.value = selected;
              _onChanged();
            },
            validator: FormBuilderValidators.required(context, errorText: 'Organisasjon må velges'),
          )
        : buildReadOnlyField<String>(
            context,
            ORG_FIELD,
            'Organisasjon',
            org?.name,
            org?.uuid,
          );
  }

  Widget _buildDivisionField() {
    return ValueListenableBuilder<String>(
      valueListenable: _org,
      builder: (context, ouuid, _) {
        final duuid = _update(DIV_FIELD, _ensureDiv(ouuid));
        final divisions = _buildDivItems(toOrg(ouuid));
        // scheduleMicrotask(() => _div.value = duuid);
        return editable & divisions.isNotEmpty
            ? buildDropDownField<String>(
                name: DIV_FIELD,
                label: 'Distrikt',
                initialValue: duuid,
                items: divisions,
                onChanged: (String selected) {
                  _div.value = selected;
                  _onChanged();
                },
                validator: FormBuilderValidators.required(context, errorText: 'Distrikt må velges'),
              )
            : buildReadOnlyField<String>(
                context,
                DIV_FIELD,
                'Distrikt',
                toDiv(duuid)?.name,
                duuid,
              );
      },
    );
  }

  Widget _buildDepartmentField() {
    return ValueListenableBuilder<String>(
        valueListenable: _div,
        builder: (context, divuuid, _) {
          final depuuid = _update(DEP_FIELD, _ensureDep(divuuid));
          final departments = _buildDepItems(toDiv(divuuid));
          // scheduleMicrotask(() => _dep = depuuid);
          return editable && departments.isNotEmpty
              ? buildDropDownField<String>(
                  name: DEP_FIELD,
                  label: 'Avdeling',
                  items: departments,
                  initialValue: _dep,
                  enabled: editable,
                  onChanged: (selected) {
                    _dep = selected;
                    _onChanged();
                  },
                  validator: FormBuilderValidators.required(context, errorText: 'Avdeling må velges'),
                )
              : buildReadOnlyField<String>(
                  context,
                  DEP_FIELD,
                  'Avdeling',
                  toDep(depuuid)?.name,
                  depuuid,
                );
        });
  }

  bool get editable => widget.user == null && (_affiliation?.isAffiliate != true || isTemporary());

  bool isTemporary() => context.read<AffiliationBloc>().isTemporary(
        _affiliation?.uuid,
      );

  String _update(String attribute, String value) {
    if (_formKey.currentState != null) {
      scheduleMicrotask(() {
        _formKey.currentState.setInternalFieldValue(attribute, value);
      });
    }
    return value;
  }

  String _ensureDiv(String ouuid) {
    final org = context.read<AffiliationBloc>().orgs[ouuid];
    final duuid = _formKey.currentState.value[DIV_FIELD] ?? _div.value ?? widget.value?.div;
    return org?.divisions?.contains(duuid) == true ? duuid : org?.divisions?.first;
  }

  String _ensureDep(String divuuid) {
    final div = context.read<AffiliationBloc>().divs[divuuid];
    final depuuid = _dep ?? widget.value?.dep;
    return (div?.departments?.contains(depuuid) == true ? depuuid : div?.departments?.first);
  }

  List<DropdownMenuItem<String>> _buildOrgItems() {
    final orgs = context.read<AffiliationBloc>().getOrganisations();
    return orgs
        .map((org) => DropdownMenuItem<String>(
              value: "${org.uuid}",
              child: Row(
                children: <Widget>[
                  SarSysIcons.of(org.prefix),
                  SizedBox(width: 16.0),
                  Text("${org.name}"),
                ],
              ),
            ))
        .toList();
  }

  List<DropdownMenuItem<String>> _buildDivItems(Organisation org) {
    final divs = context.read<AffiliationBloc>().getDivisions(org?.uuid);
    return divs
        .map((div) => DropdownMenuItem<String>(
              value: "${div.uuid}",
              child: Row(
                children: <Widget>[
                  SarSysIcons.of(org.prefix),
                  SizedBox(width: 16.0),
                  Text("${div.name}"),
                ],
              ),
            ))
        .toList();
  }

  List<DropdownMenuItem<String>> _buildDepItems(Division div) {
    final deps = context.read<AffiliationBloc>().getDepartments(div?.uuid);
    return deps
        .map((dep) => DropdownMenuItem<String>(
              value: "${dep.uuid}",
              child: Row(
                children: <Widget>[
                  SarSysIcons.of(org?.prefix),
                  SizedBox(width: 16.0),
                  Text("${dep.name}"),
                ],
              ),
            ))
        .toList();
  }

  Affiliation save() {
    _formKey?.currentState?.save();
    final json = _formKey.currentState.value;
    final affiliation = AffiliationModel(
      uuid: _affiliation?.uuid,
      person: _affiliation?.person,
      org: AggregateRef.fromType<OrganisationModel>(json[ORG_FIELD]),
      div: AggregateRef.fromType<DivisionModel>(json[DIV_FIELD]),
      dep: AggregateRef.fromType<DepartmentModel>(json[DEP_FIELD]),
      type: _affiliation?.type ?? _inferType(json),
      status: _affiliation?.status ?? AffiliationStandbyStatus.available,
    );
    return affiliation;
  }

  bool validate() {
    return _formKey.currentState.validate();
  }

  void _onChanged() {
    if (widget.onChanged != null) widget.onChanged(save());
  }

  AffiliationType _inferType(Map<String, dynamic> json) =>
      (json[ORG_FIELD] ?? json[DIV_FIELD] ?? json[DEP_FIELD]) == null
          ? AffiliationType.volunteer
          : AffiliationType.member;
}
