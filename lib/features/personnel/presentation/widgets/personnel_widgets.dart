import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/action_group.dart';
import 'package:SarSys/features/affiliation/presentation/widgets/affiliation.dart';
import 'package:SarSys/widgets/coordinate_view.dart';
import 'package:SarSys/widgets/tracking_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chips_input/flutter_chips_input.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PersonnelWidget extends StatelessWidget {
  final bool withName;
  final bool withHeader;
  final bool withActions;
  final Unit unit;
  final Tracking tracking;
  final Personnel personnel;
  final Iterable<Device> devices;
  final VoidCallback onDeleted;
  final MessageCallback onMessage;
  final ValueChanged<Point> onGoto;
  final ValueChanged<Personnel> onChanged;
  final ValueChanged<Personnel> onCompleted;

  const PersonnelWidget({
    Key key,
    @required this.unit,
    @required this.personnel,
    @required this.onMessage,
    this.tracking,
    this.devices,
    this.onGoto,
    this.onDeleted,
    this.onChanged,
    this.onCompleted,
    this.withName = false,
    this.withHeader = true,
    this.withActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Orientation orientation = MediaQuery.of(context).orientation;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (withHeader) _buildHeader(context, personnel, theme),
        if (withHeader) Divider() else SizedBox(height: 8.0),
        if (Orientation.portrait == orientation) _buildPortrait(context) else _buildLandscape(context),
        if (withActions) ...[
          Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text("Handlinger", textAlign: TextAlign.left, style: theme.caption),
          ),
          PersonnelActionGroup(
            unit: unit,
            personnel: personnel,
            type: ActionGroupType.buttonBar,
            onDeleted: onDeleted,
            onChanged: onChanged,
            onMessage: onMessage,
            onCompleted: onCompleted,
          ),
        ] else
          SizedBox(height: 16.0)
      ],
    );
  }

  Widget _buildPortrait(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (withName) _buildNameView(),
            _buildContactView(),
            _buildOperationalView(),
            _buildDivider(Orientation.portrait),
            if (isAffiliated(context)) ...[
              _buildAffiliationView(context),
              _buildDivider(Orientation.portrait),
            ],
            _buildLocationView(),
            _buildDivider(Orientation.portrait),
            _buildTrackingView(),
          ],
        ),
      );

  bool isAffiliated(BuildContext context) => context.bloc<AffiliationBloc>().repo[personnel.affiliation?.uuid] != null;

  Widget _buildLandscape(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (withName) _buildNameView(),
                  _buildContactView(),
                  if (!withName && isAffiliated(context)) _buildAffiliationView(context),
                  _buildLocationView(),
                ],
              ),
            ),
            _buildDivider(Orientation.landscape),
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildOperationalView(),
                  _buildTrackingView(),
                  if (withName && isAffiliated(context)) _buildAffiliationView(context),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDivider(Orientation orientation) => Orientation.portrait == orientation
      ? Divider(indent: 16.0, endIndent: 16.0)
      : VerticalDivider(indent: 16.0, endIndent: 16.0);

  Padding _buildHeader(BuildContext context, Personnel personnel, TextTheme theme) {
    return Padding(
      padding: EdgeInsets.only(left: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('${personnel.name}', style: theme.headline6),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => _onComplete(personnel),
          )
        ],
      ),
    );
  }

  Widget _buildNameView() => PersonnelNameView(
        personnel: personnel,
        onMessage: onMessage,
        onComplete: () => _onComplete(personnel),
      );

  Widget _buildLocationView() => CoordinateView(
        point: tracking?.position?.geometry,
        onMessage: onMessage,
        onGoto: onGoto,
        onComplete: () => _onComplete(personnel),
      );

  Widget _buildContactView() => PersonnelContactView(
        personnel: personnel,
        onMessage: onMessage,
        onComplete: () => _onComplete(personnel),
      );

  Widget _buildOperationalView() => PersonnelOperationalView(
        personnel: personnel,
        onMessage: _onMessage,
        onComplete: () => _onComplete(personnel),
      );

  Widget _buildAffiliationView(BuildContext context) => AffiliationView(
        onMessage: onMessage,
        affiliation: context.bloc<AffiliationBloc>().repo[personnel.affiliation?.uuid],
        onComplete: () => _onComplete(personnel),
      );

  TrackingView _buildTrackingView() => TrackingView(
        tuuid: tracking?.uuid,
        onMessage: onMessage,
        onComplete: () => _onComplete(personnel),
      );

  void _onMessage(String message) {
    if (onMessage != null) onMessage(message);
  }

  void _onComplete([personnel]) {
    if (onCompleted != null) onCompleted(personnel ?? this.personnel);
  }
}

class PersonnelActionGroup extends StatelessWidget {
  PersonnelActionGroup({
    @required this.personnel,
    @required this.type,
    this.unit,
    this.onDeleted,
    this.onMessage,
    this.onChanged,
    this.onCompleted,
  });
  final Unit unit;
  final Personnel personnel;
  final VoidCallback onDeleted;
  final ActionGroupType type;
  final MessageCallback onMessage;
  final ValueChanged<Personnel> onChanged;
  final ValueChanged<Personnel> onCompleted;

  @override
  Widget build(BuildContext context) {
    return ActionGroupBuilder(
      type: type,
      builder: _buildActionItems,
    );
  }

  List<ActionMenuItem> _buildActionItems(BuildContext context) {
    return <ActionMenuItem>[
      ActionMenuItem(
        child: IgnorePointer(child: _buildEditButton(context)),
        onPressed: _onEdit,
      ),
      _buildTransitionActionItem(context),
      if (unit != null)
        ActionMenuItem(
          child: IgnorePointer(child: _buildRemoveFromUnitAction(context)),
          onPressed: _onRemoveFromUnit,
        )
      else
        ActionMenuItem(
          child: IgnorePointer(child: _buildAddToUnitAction(context)),
          onPressed: _onAddToUnit,
        ),
      if (context.bloc<UserBloc>().user.isAdmin)
        ActionMenuItem(
          child: IgnorePointer(child: _buildDeleteAction(context)),
          onPressed: _onDelete,
        ),
    ];
  }

  ActionMenuItem _buildTransitionActionItem(BuildContext context) {
    switch (personnel.status) {
      case PersonnelStatus.retired:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildMobilizeAction(context),
          ),
          onPressed: () => _onTransition(
            PersonnelStatus.alerted,
          ),
        );
      case PersonnelStatus.alerted:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildOnSceneAction(context),
          ),
          onPressed: () => _onTransition(
            PersonnelStatus.onscene,
          ),
        );
      case PersonnelStatus.onscene:
      default:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildRetireAction(context),
          ),
          onPressed: () => _onTransition(
            PersonnelStatus.retired,
          ),
        );
    }
  }

  Widget _buildEditButton(BuildContext context) => Tooltip(
        message: "Endre mannskap",
        child: FlatButton.icon(
          icon: Icon(Icons.edit),
          label: Text(
            "ENDRE",
            textAlign: TextAlign.center,
          ),
          onPressed: _onEdit,
        ),
      );

  void _onEdit() async {
    final result = await editPersonnel(personnel);
    if (result.isRight()) {
      final actual = result.toIterable().first;
      if (actual != personnel) {
        _onMessage("${actual.name} er oppdatert");
        _onChanged(actual);
      }
      _onCompleted();
    }
  }

  Widget _buildAddToUnitAction(BuildContext context) => Tooltip(
        message: "Knytt mannskap til enhet",
        child: FlatButton.icon(
          icon: Icon(Icons.people),
          label: Text(
            'KNYTT',
            textAlign: TextAlign.center,
          ),
          onPressed: _onAddToUnit,
        ),
      );

  void _onAddToUnit() async {
    final result = await addToUnit(personnels: [personnel], unit: unit);
    if (result.isRight()) {
      var actual = result.toIterable().first;
      _onMessage("${personnel.name} er tilknyttet ${actual.name}");
      _onChanged(personnel);
    }
  }

  Widget _buildRemoveFromUnitAction(BuildContext context) => Tooltip(
        message: "Fjern mannskap fra enhet",
        child: FlatButton.icon(
          icon: Icon(Icons.people),
          label: Text(
            'FJERN',
            textAlign: TextAlign.center,
          ),
          onPressed: _onRemoveFromUnit,
        ),
      );

  void _onRemoveFromUnit() async {
    final result = await removeFromUnit(unit, personnels: [personnel]);
    if (result.isRight()) {
      _onMessage("${personnel.name} er fjernet fra ${unit.name}");
      _onChanged(personnel);
    }
  }

  Widget _buildMobilizeAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    final color = toPersonnelStatusColor(PersonnelStatus.alerted);
    return Tooltip(
      message: "Registrer som mobilisert",
      child: FlatButton.icon(
        icon: Icon(
          Icons.check,
          color: color,
        ),
        label: Text(
          "MOBILISERT",
          textAlign: TextAlign.center,
          style: button.copyWith(
            color: color,
          ),
        ),
        onPressed: () => _onTransition(
          PersonnelStatus.alerted,
        ),
      ),
    );
  }

  Widget _buildOnSceneAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    final color = toPersonnelStatusColor(PersonnelStatus.onscene);
    return Tooltip(
      message: "Registrer som ankommet",
      child: FlatButton.icon(
        icon: Icon(
          Icons.check,
          color: color,
        ),
        label: Text(
          "ANKOMMET",
          textAlign: TextAlign.center,
          style: button.copyWith(
            color: color,
          ),
        ),
        onPressed: () => _onTransition(
          PersonnelStatus.onscene,
        ),
      ),
    );
  }

  void _onTransition(PersonnelStatus status) async {
    switch (status) {
      case PersonnelStatus.none:
      case PersonnelStatus.alerted:
        final result = await mobilizePersonnel(personnel);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er registert mobilisert");
          _onChanged(actual);
          _onCompleted();
        }
        break;
      case PersonnelStatus.enroute:
        final result = await mobilizePersonnel(personnel);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er registert på vei");
          _onChanged(actual);
          _onCompleted();
        }
        break;
      case PersonnelStatus.onscene:
        final result = await checkInPersonnel(personnel);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er registert ankommet");
          _onChanged(actual);
          _onCompleted();
        }
        break;
      case PersonnelStatus.leaving:
        final result = await retirePersonnel(personnel);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er dimmitert");
          _onChanged(actual);
          _onCompleted();
        }
        break;
      case PersonnelStatus.retired:
        final result = await retirePersonnel(personnel);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er dimmitert");
          _onChanged(actual);
          _onCompleted();
        }
        break;
    }
  }

  Widget _buildRetireAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    final color = toPersonnelStatusColor(PersonnelStatus.retired);
    return Tooltip(
      message: "Dimitter og avslutt sporing",
      child: FlatButton.icon(
        icon: Icon(
          Icons.archive,
          color: color,
        ),
        label: Text(
          "DIMITTERT",
          textAlign: TextAlign.center,
          style: button.copyWith(color: color),
        ),
        onPressed: () => _onTransition(
          PersonnelStatus.retired,
        ),
      ),
    );
  }

  Widget _buildDeleteAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Slett mannskap",
      child: FlatButton.icon(
        icon: Icon(
          Icons.delete,
          color: Colors.red,
        ),
        label: Text(
          'SLETT',
          textAlign: TextAlign.center,
          style: button.copyWith(color: Colors.red),
        ),
        onPressed: _onDelete,
      ),
    );
  }

  void _onDelete() async {
    final result = await deletePersonnel(personnel);
    if (result.isRight()) {
      _onMessage("${personnel.name} er slettet");
      _onDeleted();
      _onCompleted();
    }
  }

  void _onMessage(String message) {
    if (onMessage != null) onMessage(message);
  }

  void _onChanged([personnel]) {
    if (onChanged != null) onChanged(personnel);
  }

  void _onCompleted([personnel]) {
    if (onCompleted != null) onCompleted(personnel ?? this.personnel);
  }

  void _onDeleted() {
    if (onDeleted != null) onDeleted();
  }
}

class PersonnelNameView extends StatelessWidget {
  const PersonnelNameView({
    Key key,
    this.personnel,
    this.onMessage,
    this.onComplete,
  }) : super(key: key);

  final Personnel personnel;
  final VoidCallback onComplete;
  final MessageCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Fornavn",
            icon: Icon(Icons.person),
            value: personnel.fname,
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Etternavn",
            icon: Icon(Icons.person_outline),
            value: personnel.lname,
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
      ],
    );
  }
}

class PersonnelContactView extends StatelessWidget {
  const PersonnelContactView({
    Key key,
    this.personnel,
    this.onMessage,
    this.onComplete,
  }) : super(key: key);

  final Personnel personnel;
  final VoidCallback onComplete;
  final MessageCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final units = context.bloc<UnitBloc>().find(personnel);
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Enhet",
            icon: Icon(Icons.supervised_user_circle),
            value: units.isNotEmpty ? units.map((unit) => unit.name).join(', ') : 'Ingen',
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Mobil",
            icon: Icon(Icons.phone),
            value: personnel.phone ?? "Ukjent",
            onMessage: onMessage,
            onComplete: onComplete,
            onTap: () {
              final number = personnel.phone ?? '';
              if (number.isNotEmpty) launch("tel:$number");
            },
          ),
        ),
      ],
    );
  }
}

class PersonnelOperationalView extends StatelessWidget {
  const PersonnelOperationalView({
    Key key,
    this.personnel,
    this.onMessage,
    this.onComplete,
  }) : super(key: key);

  final Personnel personnel;
  final VoidCallback onComplete;
  final MessageCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Funksjon",
            icon: Icon(Icons.functions),
            value: translateOperationalFunction(personnel.function),
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Status",
            icon: Icon(MdiIcons.accountQuestionOutline),
            value: translatePersonnelStatus(personnel.status),
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
      ],
    );
  }
}

class PersonnelTile extends StatelessWidget {
  final Personnel personnel;
  final ChipsInputState state;

  const PersonnelTile({
    Key key,
    @required this.personnel,
    this.state,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ObjectKey(personnel),
      leading: AffiliationAvatar(
        affiliation: context.bloc<AffiliationBloc>().repo[personnel?.affiliation?.uuid],
        size: 10.0,
      ),
      title: Text(personnel.name),
      onTap: state != null ? () => state.selectSuggestion(personnel) : null,
    );
  }
}

class PersonnelChip extends StatelessWidget {
  final Personnel personnel;
  final ChipsInputState state;

  const PersonnelChip({
    Key key,
    @required this.personnel,
    this.state,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.caption;
    return InputChip(
      key: ObjectKey(personnel),
      labelPadding: EdgeInsets.only(left: 4.0),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AffiliationAvatar(
            affiliation: context.bloc<AffiliationBloc>().repo[personnel.affiliation?.uuid],
            size: 6.0,
            maxRadius: 10.0,
          ),
          SizedBox(width: 6.0),
          Text(personnel.formal, style: style),
        ],
      ),
      onDeleted: () => state.deleteChip(personnel),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
