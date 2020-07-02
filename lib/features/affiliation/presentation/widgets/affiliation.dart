import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';

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
      child: SarSysIcons.of(
        context.bloc<AffiliationBloc>().orgs[affiliation.org.uuid]?.prefix,
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
            icon: SarSysIcons.of(context.bloc<AffiliationBloc>().orgs[affiliation.org.uuid].prefix),
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
  void didUpdateWidget(AffiliationForm oldWidget) {
    if (oldWidget.user != widget.user) {
      _affiliation = context.bloc<AffiliationBloc>().findUserAffiliation(
            user: widget.user,
          );
      _org.value = _affiliation.org.uuid;
      _div.value = _affiliation.div.uuid;
      _dep = _affiliation.dep.uuid;
    }
    super.didUpdateWidget(oldWidget);
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
    _update(ORG_FIELD, org?.prefix);
    return _buildReadOnly(
      context,
      ORG_FIELD,
      'Organisasjon',
      org?.name,
      org?.prefix,
    );
  }

  Widget _buildDivisionField() {
    return ValueListenableBuilder<String>(
      valueListenable: _org,
      builder: (context, ouuid, _) {
        final duuid = _update(DIV_FIELD, _ensureDiv(ouuid));
        return org != null && editable
            ? buildDropDownField<String>(
                attribute: DIV_FIELD,
                label: 'Distrikt',
                initialValue: duuid,
                items: _buildDivisionItems(toOrg(ouuid)),
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
            : _buildReadOnly(
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
          return editable
              ? buildDropDownField<String>(
                  attribute: DEP_FIELD,
                  label: 'Avdeling',
                  items: _buildDepartmentItems(toDiv(divuuid)),
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
              : _buildReadOnly(
                  context,
                  DEP_FIELD,
                  'Avdeling',
                  toDep(depuuid)?.name,
                  depuuid,
                );
        });
  }

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
    if (_formKey.currentState != null) {
      _formKey.currentState.value[attribute] = value;
      _formKey.currentState.fields[attribute].currentState.didChange(value);
      _formKey.currentState.save();
    }
    return value;
  }

  String _ensureDiv(String ouuid) {
    final org = context.bloc<AffiliationBloc>().orgs[ouuid];
    final divId = _formKey.currentState.value[DIV_FIELD] ?? widget.value?.div ?? Defaults.divId;
    return org?.divisions?.contains(divId) == true ? divId : org.divisions.first;
  }

  String _ensureDep(String divuuid) {
    final div = context.bloc<AffiliationBloc>().divs[divuuid];
    final depuuid = _dep ?? widget.value?.dep ?? Defaults.depId;
    return (div?.departments?.contains(depuuid) == true ? depuuid : div.departments.first);
  }

  List<DropdownMenuItem<String>> _buildDivisionItems(Organisation org) {
    final repo = context.bloc<AffiliationBloc>().divs;
    final divisions = org.divisions.map((uuid) => repo[uuid]);
    return sortMapValues<String, Division, String>(divisions ?? {}, (division) => division.name)
        .entries
        .map((division) => DropdownMenuItem<String>(
              value: "${division.key}",
              child: Text("${division.value.name}"),
            ))
        .toList();
  }

  List<DropdownMenuItem<String>> _buildDepartmentItems(Division division) {
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
