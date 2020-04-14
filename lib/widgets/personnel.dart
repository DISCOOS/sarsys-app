import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/usecase/personnel.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/affilliation.dart';
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
  final Tracking tracking;
  final Personnel personnel;
  final Iterable<Device> devices;
  final VoidCallback onDelete;
  final MessageCallback onMessage;
  final ValueChanged<Point> onGoto;
  final ValueChanged<Personnel> onChanged;
  final Future<Organization> organization;
  final ValueChanged<Personnel> onComplete;

  const PersonnelWidget({
    Key key,
    @required this.personnel,
    @required this.onMessage,
    this.tracking,
    this.devices,
    this.onGoto,
    this.onDelete,
    this.onChanged,
    this.onComplete,
    this.withName = false,
    this.withHeader = true,
    this.withActions = true,
    this.organization,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Orientation orientation = MediaQuery.of(context).orientation;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (withHeader) ...[
          _buildHeader(personnel, theme, context),
          Divider(),
        ] else
          SizedBox(height: 8.0),
        if (Orientation.portrait == orientation) _buildPortrait() else _buildLandscape(),
        if (withActions) ...[
          Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text("Handlinger", textAlign: TextAlign.left, style: theme.caption),
          ),
          _buildActions(context, personnel)
        ] else
          SizedBox(height: 16.0)
      ],
    );
  }

  Widget _buildPortrait() => Padding(
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
            if (organization != null) ...[
              _buildAffiliationView(),
              _buildDivider(Orientation.portrait),
            ],
            _buildLocationView(),
            _buildDivider(Orientation.portrait),
            _buildTrackingView(),
          ],
        ),
      );

  Widget _buildLandscape() => Padding(
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
                  if (!withName && organization != null) _buildAffiliationView(),
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
                  if (withName && organization != null) _buildAffiliationView(),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDivider(Orientation orientation) => Orientation.portrait == orientation
      ? Divider(indent: 16.0, endIndent: 16.0)
      : VerticalDivider(indent: 16.0, endIndent: 16.0);

  Padding _buildHeader(Personnel personnel, TextTheme theme, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('${personnel.name}', style: theme.title),
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
        point: tracking?.point,
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

  Widget _buildAffiliationView() => AffiliationView(
        future: organization,
        onMessage: onMessage,
        affiliation: personnel.affiliation,
        onComplete: () => _onComplete(personnel),
      );

  TrackingView _buildTrackingView() => TrackingView(
        tuuid: tracking?.id,
        onMessage: onMessage,
        onComplete: () => _onComplete(personnel),
      );

  Widget _buildActions(BuildContext context, Personnel personnel1) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ButtonBarTheme(
        // make buttons use the appropriate styles for cards
        child: ButtonBar(
          alignment: MainAxisAlignment.start,
          children: <Widget>[
            _buildEditAction(context),
            if (devices?.isNotEmpty == true) _buildRemoveAction(context),
            _buildTransitionAction(context),
            _buildDeleteAction(context),
          ],
        ),
        data: ButtonBarThemeData(
          layoutBehavior: ButtonBarLayoutBehavior.constrained,
          buttonPadding: EdgeInsets.all(0.0),
        ),
      ),
    );
  }

  Widget _buildEditAction(BuildContext context) => Tooltip(
        message: "Endre mannskap",
        child: FlatButton(
          child: Text(
            "ENDRE",
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await editPersonnel(personnel);
            if (result.isRight()) {
              final actual = result.toIterable().first;
              if (actual != personnel) {
                _onMessage("${actual.name} er oppdatert");
                _onChanged(actual);
              }
              _onComplete();
            }
          },
        ),
      );

  Widget _buildRemoveAction(BuildContext context) => Tooltip(
        message: "Fjern apparater fra mannskap",
        child: FlatButton(
          child: Text(
            "FJERN",
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await removeFromPersonnel(personnel, devices: devices.toList());
            if (result.isRight()) {
              _onMessage("Apparater fjernet fra ${personnel.name}");
              _onChanged(personnel);
              _onComplete();
            }
          },
        ),
      );

  Widget _buildTransitionAction(BuildContext context) {
    switch (personnel.status) {
      case PersonnelStatus.Retired:
        return _buildMobilizeAction(context);
      case PersonnelStatus.Mobilized:
        return _buildOnSceneAction(context);
      case PersonnelStatus.OnScene:
      default:
        return _buildRetireAction(context);
    }
  }

  Widget _buildMobilizeAction(BuildContext context) => Tooltip(
        message: "Registrer som mobilisert",
        child: FlatButton(
          child: Text(
            "MOBILISERT",
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await mobilizePersonnel(personnel);
            if (result.isRight()) {
              final actual = result.toIterable().first;
              _onMessage("${actual.name} er registert mobilisert");
              _onChanged(actual);
              _onComplete();
            }
          },
        ),
      );

  Widget _buildOnSceneAction(BuildContext context) => Tooltip(
        message: "Registrer som ankommet",
        child: FlatButton(
          child: Text(
            "ANKOMMET",
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await checkInPersonnel(personnel);
            if (result.isRight()) {
              final actual = result.toIterable().first;
              _onMessage("${actual.name} er registert ankommet");
              _onChanged(actual);
              _onComplete();
            }
          },
        ),
      );

  Widget _buildRetireAction(BuildContext context) => Tooltip(
        message: "Dimitter og avslutt sporing",
        child: FlatButton(
          child: Text(
            "DIMITTERT",
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await retirePersonnel(personnel);
            if (result.isRight()) {
              final actual = result.toIterable().first;
              _onMessage("${actual.name} er dimmitert");
              _onChanged(actual);
              _onComplete();
            }
          },
        ),
      );

  Widget _buildDeleteAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Slett mannskap",
      child: FlatButton(
          child: Text(
            'SLETT',
            textAlign: TextAlign.center,
            style: button.copyWith(color: Colors.red),
          ),
          onPressed: () async {
            final result = await deletePersonnel(personnel);
            if (result.isRight()) {
              _onMessage("${personnel.name} er slettet");
              _onDelete();
              _onComplete();
            }
          }),
    );
  }

  void _onMessage(String message) {
    if (onMessage != null) onMessage(message);
  }

  void _onChanged([personnel]) {
    if (onChanged != null) onChanged(personnel);
  }

  void _onComplete([personnel]) {
    if (onComplete != null) onComplete(personnel ?? this.personnel);
  }

  void _onDelete() {
    if (onDelete != null) onDelete();
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
    final units = BlocProvider.of<UnitBloc>(context).find(personnel);
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
        affiliation: personnel?.affiliation,
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
            affiliation: personnel.affiliation,
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
