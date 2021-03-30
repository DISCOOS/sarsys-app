import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/personnel/domain/repositories/personnel_repository.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/widgets/action_group.dart';

class UnitWidget extends StatelessWidget {
  UnitWidget({
    Key key,
    @required this.unit,
    @required this.tracking,
    @required this.devices,
    @required this.onMessage,
    this.onGoto,
    this.onChanged,
    this.onCompleted,
    this.onDeleted,
    this.withMap = false,
    this.withHeader = true,
    this.withActions = true,
    MapWidgetController controller,
  })  : this.controller = controller ?? MapWidgetController(),
        super(key: key);

  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 2.0;

  final Unit unit;
  final Tracking tracking;
  final Iterable<Device> devices;
  final bool withMap;
  final bool withHeader;
  final bool withActions;
  final ValueChanged<Point> onGoto;
  final ValueChanged<Unit> onChanged;
  final ValueChanged<Unit> onCompleted;
  final VoidCallback onDeleted;
  final ActionCallback onMessage;
  final MapWidgetController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Orientation orientation = MediaQuery.of(context).orientation;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (withHeader) _buildHeader(context, theme),
          if (withHeader) Divider() else SizedBox(height: 8.0),
          if (withMap) _buildMap(context),
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

  Widget _buildPortrait(BuildContext context, TextTheme theme) => Column(
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
      );

  Widget _buildLandscape(BuildContext context, TextTheme theme) => Row(
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
      );

  Widget _buildDivider(Orientation orientation) => Orientation.portrait == orientation
      ? Divider(indent: 16.0, endIndent: 16.0)
      : VerticalDivider(indent: 16.0, endIndent: 16.0);

  ListTile _buildHeader(BuildContext context, TextTheme theme) => ListTile(
      selected: true,
      title: Text('Enhet', style: theme.headline6),
      subtitle: Text('${unit.name}'),
      trailing: IconButton(
        icon: Icon(Icons.close),
        onPressed: () => _onComplete(unit),
      ));

  Widget _buildMap(BuildContext context) {
    final center = tracking?.position?.toLatLng();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Material(
        elevation: ELEVATION,
        borderRadius: BorderRadius.circular(CORNER),
        child: Container(
          height: 240.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CORNER),
            child: GestureDetector(
              child: MapWidget(
                key: ObjectKey(unit.uuid),
                center: center,
                zoom: 16.0,
                withRead: true,
                withWrite: true,
                withUnits: true,
                withDevices: false,
                interactive: false,
                withScaleBar: true,
                withControls: true,
                withPersonnel: false,
                withControlsZoom: true,
                withControlsLayer: true,
                withControlsBaseMap: true,
                withControlsOffset: 16.0,
                showRetired: UnitStatus.retired == unit.status,
                showLayers: [
                  MapWidgetState.LAYER_POI,
                  MapWidgetState.LAYER_PERSONNEL,
                  MapWidgetState.LAYER_TRACKING,
                  MapWidgetState.LAYER_SCALE,
                ],
                mapController: controller,
              ),
              onTap: center != null ? () => jumpToLatLng(context, center: center) : null,
            ),
          ),
        ),
      ),
    );
  }

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
              value: _toPersonnel(context.bloc<PersonnelBloc>().repo),
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ],
      );

  String _toPersonnel(PersonnelRepository repo) {
    final personnel = unit?.personnels?.map((puuid) => repo[puuid]?.formal ?? 'Mannskap')?.join(', ');
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
      case UnitStatus.retired:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildMobilizeAction(context),
          ),
          onPressed: () => _onTransition(
            UnitStatus.mobilized,
          ),
        );
      case UnitStatus.mobilized:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildDeployedAction(context),
          ),
          onPressed: () => _onTransition(
            UnitStatus.deployed,
          ),
        );
      case UnitStatus.deployed:
      default:
        return ActionMenuItem(
          child: IgnorePointer(
            child: _buildRetireAction(context),
          ),
          onPressed: () => _onTransition(
            UnitStatus.retired,
          ),
        );
    }
  }

  Widget _buildEditButton(BuildContext context) => Tooltip(
        message: "Endre enhet",
        child: TextButton.icon(
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
    final color = toUnitStatusColor(UnitStatus.mobilized);
    return Tooltip(
      message: "Registrer som mobilisert",
      child: TextButton.icon(
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
          UnitStatus.mobilized,
        ),
      ),
    );
  }

  Widget _buildDeployedAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    final color = toUnitStatusColor(UnitStatus.deployed);
    return Tooltip(
      message: "Registrer som deployert",
      child: TextButton.icon(
        icon: Icon(
          Icons.check,
          color: color,
        ),
        label: Text(
          "DEPLOYERT",
          textAlign: TextAlign.center,
          style: button.copyWith(
            color: color,
          ),
        ),
        onPressed: () => _onTransition(
          UnitStatus.deployed,
        ),
      ),
    );
  }

  void _onTransition(UnitStatus status) async {
    switch (status) {
      case UnitStatus.mobilized:
        final result = await mobilizeUnit(unit);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er registert mobilisert");
          _onChanged(actual);
          _onCompleted();
        }
        break;
      case UnitStatus.deployed:
        final result = await deployUnit(unit);
        if (result.isRight()) {
          final actual = result.toIterable().first;
          _onMessage("${actual.name} er registert ankommet");
          _onChanged(actual);
          _onCompleted();
        }
        break;
      case UnitStatus.retired:
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
    final color = toUnitStatusColor(UnitStatus.retired);
    return Tooltip(
      message: "Dimitter og avslutt sporing",
      child: TextButton.icon(
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
          UnitStatus.retired,
        ),
      ),
    );
  }

  Widget _buildDeleteAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Slett mannskap",
      child: TextButton.icon(
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
