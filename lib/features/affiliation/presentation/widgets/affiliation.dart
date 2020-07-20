import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/models/AggregateRef.dart';
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
import 'package:SarSys/utils/ui_utils.dart';

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
        context.bloc<AffiliationBloc>().orgs[affiliation.org?.uuid]?.prefix,
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
            icon: SarSysIcons.of(context.bloc<AffiliationBloc>().orgs[affiliation.org?.uuid]?.prefix),
            value: context.bloc<AffiliationBloc>().toName(affiliation),
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
  static const ORG_FIELD = 'orgId';
  static const DIV_FIELD = 'divId';
  static const DEP_FIELD = 'depId';

  final _formKey = GlobalKey<FormBuilderState>();

  ValueNotifier<String> _org = ValueNotifier(null);
  ValueNotifier<String> _div = ValueNotifier(null);
  String _dep;
  Affiliation _affiliation;

  Department get dep => _dep == null ? null : toDep(_dep);
  Division get div => _div.value == null ? null : toDiv(_div.value);
  Organisation get org => _org.value == null ? null : toOrg(_org.value);

  Organisation toOrg(String ouuid) => context.bloc<AffiliationBloc>().orgs[ouuid];
  Division toDiv(String divuuid) => context.bloc<AffiliationBloc>().divs[divuuid];
  Department toDep(String depuuid) => context.bloc<AffiliationBloc>().deps[depuuid];

  @override
  void initState() {
    super.initState();
    _apply(widget.value);
  }

  @override
  void didUpdateWidget(AffiliationForm oldWidget) {
    if (oldWidget.user != widget.user) {
      _apply(context.bloc<AffiliationBloc>().findUserAffiliation(
            userId: widget.user.userId,
          ));
    }
    super.didUpdateWidget(oldWidget);
  }

  void _apply(Affiliation affiliation) {
    _affiliation = affiliation;
    _org.value = _affiliation.org.uuid;
    _div.value = _affiliation.div.uuid;
    _dep = _affiliation.dep.uuid;
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
    _update(ORG_FIELD, org?.uuid);
    return buildReadOnlyField<String>(
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
        final divisions = _buildDivisionItems(toOrg(ouuid));
        return editable & divisions.isNotEmpty
            ? buildDropDownField<String>(
                attribute: DIV_FIELD,
                label: 'Distrikt',
                initialValue: duuid,
                items: divisions,
                onChanged: (String selected) {
                  if (org != null) {
                    _div.value = selected;
                    _onChanged();
                  }
                },
                validators: [
                  FormBuilderValidators.required(errorText: 'Distrikt må velges'),
                ],
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
          final departments = _buildDepartmentItems(toDiv(divuuid));
          return editable && departments.isNotEmpty
              ? buildDropDownField<String>(
                  attribute: DEP_FIELD,
                  label: 'Avdeling',
                  items: departments,
                  initialValue: _dep,
                  enabled: editable,
                  onChanged: (selected) {
                    _dep = selected;
                    _onChanged();
                  },
                  validators: [
                    FormBuilderValidators.required(errorText: 'Avdeling må velges'),
                  ],
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

  bool get editable => widget.user == null;

  String _update(String attribute, String value) {
    if (_formKey.currentState != null) {
      _formKey.currentState.value[attribute] = value;
    }
    return value;
  }

  String _ensureDiv(String ouuid) {
    final org = context.bloc<AffiliationBloc>().orgs[ouuid];
    final duuid = _formKey.currentState.value[DIV_FIELD] ?? _div.value ?? widget.value?.div;
    return org?.divisions?.contains(duuid) == true ? duuid : org?.divisions?.first;
  }

  String _ensureDep(String divuuid) {
    final div = context.bloc<AffiliationBloc>().divs[divuuid];
    final depuuid = _dep ?? widget.value?.dep;
    return (div?.departments?.contains(depuuid) == true ? depuuid : div?.departments?.first);
  }

  List<DropdownMenuItem<String>> _buildDivisionItems(Organisation org) {
    final divisions = context.bloc<AffiliationBloc>().getDivisions(org?.uuid);
    return divisions
        .map((division) => DropdownMenuItem<String>(
              value: "${division.uuid}",
              child: Text("${division.name}"),
            ))
        .toList();
  }

  List<DropdownMenuItem<String>> _buildDepartmentItems(Division div) {
    final departments = context.bloc<AffiliationBloc>().getDepartments(div?.uuid);
    return departments
        .map((department) => DropdownMenuItem<String>(
              value: "${department.uuid}",
              child: Text("${department.name}"),
            ))
        .toList();
  }

  Affiliation save() {
    _formKey?.currentState?.save();
    final json = _formKey.currentState.value;
    final affiliation = AffiliationModel(
      uuid: _affiliation?.uuid,
      org: AggregateRef.fromType<Organisation>(json[ORG_FIELD]),
      div: AggregateRef.fromType<Division>(json[DIV_FIELD]),
      dep: AggregateRef.fromType<Department>(json[DEP_FIELD]),
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
