import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/unit_use_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'action_group.dart';

class UnitWidget extends StatelessWidget {
  final Unit unit;
  final Tracking tracking;
  final Iterable<Device> devices;
  final bool withHeader;
  final bool withActions;
  final ValueChanged<Point> onGoto;
  final ValueChanged<Unit> onChanged;
  final ValueChanged<Unit> onCompleted;
  final VoidCallback onDeleted;
  final ActionCallback onMessage;

  const UnitWidget({
    Key key,
    @required this.unit,
    @required this.tracking,
    @required this.devices,
    @required this.onMessage,
    this.onGoto,
    this.onChanged,
    this.onCompleted,
    this.onDeleted,
    this.withHeader = true,
    this.withActions = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Orientation orientation = MediaQuery.of(context).orientation;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: orientation == Orientation.portrait ? 300.0 : 600.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (withHeader) _buildHeader(unit, theme, context),
          if (withHeader) Divider() else SizedBox(height: 8.0),
          if (Orientation.portrait == orientation) _buildPortrait(context, theme) else _buildLandscape(context, theme),
          if (withActions) ...[
            Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text("Handlinger", textAlign: TextAlign.left, style: theme.caption),
            ),
            UnitActionGroup(
              unit: unit,
              type: ActionGroupType.buttonBar,
              onDeleted: onDeleted,
              onChanged: onChanged,
              onMessage: onMessage,
              onCompleted: onCompleted,
            ),
          ] else
            SizedBox(height: 16.0)
        ],
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, TextTheme theme) => Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetaInfo(context),
            _buildContactInfo(context),
            _buildPersonnelInfo(context),
            _buildDivider(Orientation.portrait),
            _buildLocationInfo(context, theme),
            _buildDivider(Orientation.portrait),
            _buildTrackingInfo(context),
            _buildEffortInfo(context)
          ],
        ),
      );

  Widget _buildLandscape(BuildContext context, TextTheme theme) => Padding(
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
                  _buildMetaInfo(context),
                  _buildContactInfo(context),
                  _buildPersonnelInfo(context),
                ],
              ),
            ),
            _buildDivider(Orientation.landscape),
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildLocationInfo(context, theme),
                  _buildTrackingInfo(context),
                  _buildEffortInfo(context),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDivider(Orientation orientation) => Orientation.portrait == orientation
      ? Divider(indent: 16.0, endIndent: 16.0)
      : VerticalDivider(indent: 16.0, endIndent: 16.0);

  Padding _buildHeader(Unit unit, TextTheme theme, BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('${unit.name}', style: theme.headline6),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => _onComplete(unit),
            )
          ],
        ),
      );

  Row _buildLocationInfo(BuildContext context, TextTheme theme) => Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Column(
              children: <Widget>[
                buildCopyableLocation(
                  context,
                  label: "UTM",
                  icon: Icons.my_location,
                  tracking: tracking,
                  formatter: (point) => toUTM(
                    tracking?.position?.geometry,
                    prefix: "",
                    empty: "Ingen",
                  ),
                ),
                buildCopyableLocation(
                  context,
                  label: "Desimalgrader (DD)",
                  icon: Icons.my_location,
                  tracking: tracking,
                  formatter: (point) => toDD(
                    tracking?.position?.geometry,
                    prefix: "",
                    empty: "Ingen",
                  ),
                ),
              ],
            ),
          ),
          if (tracking?.position != null)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.navigation, color: Colors.black45),
                    onPressed: tracking?.position == null
                        ? null
                        : () {
                            navigateToLatLng(
                              context,
                              toLatLng(
                                tracking?.position?.geometry,
                              ),
                            );
                            _onComplete();
                          },
                  ),
                  Text("Naviger", style: theme.caption),
                ],
              ),
            ),
        ],
      );

  Widget buildCopyableLocation(
    BuildContext context, {
    Tracking tracking,
    String label,
    IconData icon,
    String formatter(Point location),
  }) =>
      buildCopyableText(
        context: context,
        label: label,
        icon: Icon(icon),
        value: formatter(tracking?.position?.geometry),
        onTap: () => _onGoto(tracking?.position?.geometry),
        onMessage: onMessage,
        onComplete: _onComplete,
      );

  Row _buildMetaInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Navn",
              icon: Icon(Icons.people),
              value: unit.name,
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Status",
              icon: Icon(Icons.people_outline),
              value: translateUnitStatus(unit.status),
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ],
      );

  void _onGoto(Point location) {
    if (onGoto != null && location != null) onGoto(location);
  }

  Row _buildContactInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Kallesignal",
              icon: Icon(Icons.headset_mic),
              value: unit.callsign,
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
          Expanded(
            child: GestureDetector(
              child: buildCopyableText(
                context: context,
                label: "Mobil",
                icon: Icon(Icons.phone),
                value: unit.phone ?? "Ukjent",
                onMessage: onMessage,
                onComplete: _onComplete,
              ),
              onTap: () {
                final number = unit?.phone ?? '';
                if (number.isNotEmpty) launch("tel:$number");
              },
            ),
          ),
        ],
      );

  Row _buildPersonnelInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Mannskaper",
              icon: Icon(Icons.group_work),
              value: _toPersonnel(),
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ],
      );

  String _toPersonnel() {
    final personnel = unit?.personnels?.map((p) => p.formal)?.join(', ');
    return personnel?.isEmpty == true ? 'Ingen' : personnel;
  }

  Row _buildTrackingInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Apparater",
              icon: Icon(MdiIcons.cellphoneBasic),
              value: _toDeviceNumbers(),
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Avstand sporet",
              icon: Icon(MdiIcons.tapeMeasure),
              value: formatDistance(tracking?.distance),
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ],
      );

  String _toDeviceNumbers() {
    final numbers = devices?.map((device) => device.number);
    return numbers?.isNotEmpty == true ? numbers.join(', ') : 'Ingen';
  }

  Row _buildEffortInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Innsatstid",
              icon: Icon(Icons.timer),
              value: "${formatDuration(tracking?.effort)}",
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Gj.snitthastiget",
              icon: Icon(MdiIcons.speedometer),
              value: "${(tracking?.speed ?? 0.0 * 3.6).toStringAsFixed(1)} km/t",
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ],
      );

  void _onComplete([unit]) {
    if (onCompleted != null) onCompleted(unit ?? this.unit);
  }
}

class UnitActionGroup extends StatelessWidget {
  UnitActionGroup({
    @required this.unit,
    @required this.type,
    this.onDeleted,
    this.onMessage,
    this.onChanged,
    this.onCompleted,
  });
  final Unit unit;
  final VoidCallback onDeleted;
  final ActionGroupType type;
  final MessageCallback onMessage;
  final ValueChanged<Unit> onChanged;
  final ValueChanged<Unit> onCompleted;

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
      if (context.bloc<UserBloc>().user.isAdmin)
        ActionMenuItem(
          child: IgnorePointer(child: _buildDeleteAction(context)),
          onPressed: _onDelete,
        ),
    ];
  }

  ActionMenuItem _buildTransitionActionItem(BuildContext context) {
    switch (unit.status) {
      case UnitStatus.Retired:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildMobilizeAction(context),
          ),
          onPressed: () => _onTransition(
            UnitStatus.Mobilized,
          ),
        );
      case UnitStatus.Mobilized:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildDeployedAction(context),
          ),
          onPressed: () => _onTransition(
            UnitStatus.Deployed,
          ),
        );
      case UnitStatus.Deployed:
      default:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildRetireAction(context),
          ),
          onPressed: () => _onTransition(
            UnitStatus.Retired,
          ),
        );
    }
  }

  Widget _buildEditButton(BuildContext context) => Tooltip(
        message: "Endre enhet",
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
    final result = await editUnit(unit);
    if (result.isRight()) {
      final actual = result.toIterable().first;
      if (actual != unit) {
        _onMessage("${actual.name} er oppdatert");
        _onChanged(actual);
      }
      _onCompleted();
    }
  }

  Widget _buildMobilizeAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    final color = toUnitStatusColor(UnitStatus.Mobilized);
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
          UnitStatus.Mobilized,
        ),
      ),
    );
  }

  Widget _buildDeployedAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    final color = toUnitStatusColor(UnitStatus.Deployed);
    return Tooltip(
      message: "Registrer som deployert",
      child: FlatButton.icon(
        icon: Icon(
          Icons.check,
          color: color,
        ),
        label: Text(
          "Deployert",
          textAlign: TextAlign.center,
          style: button.copyWith(
            color: color,
          ),
        ),
        onPressed: () => _onTransition(
          UnitStatus.Deployed,
        ),
      ),
    );
  }

  void _onTransition(UnitStatus status) async {
    switch (status) {
      case UnitStatus.Mobilized:
        final result = await mobilizeUnit(unit);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er registert mobilisert");
          _onChanged(actual);
          _onCompleted();
        }
        break;
      case UnitStatus.Deployed:
        final result = await deployUnit(unit);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er registert ankommet");
          _onChanged(actual);
          _onCompleted();
        }
        break;
      case UnitStatus.Retired:
        final result = await retireUnit(unit);
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
    final color = toUnitStatusColor(UnitStatus.Retired);
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
          UnitStatus.Retired,
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
    final result = await deleteUnit(unit);
    if (result.isRight()) {
      _onMessage("${unit.name} er slettet");
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
    if (onCompleted != null) onCompleted(personnel ?? this.unit);
  }

  void _onDeleted() {
    if (onDeleted != null) onDeleted();
  }
}
