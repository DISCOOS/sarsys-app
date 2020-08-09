import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/device/domain/usecases/device_use_cases.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/tracking/utils/tracking.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/widgets/action_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chips_input/flutter_chips_input.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeviceTile extends StatelessWidget {
  final Device device;
  final ChipsInputState state;
  const DeviceTile({
    Key key,
    @required this.device,
    this.state,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ObjectKey(device),
      leading: CircleAvatar(
        child: Icon(
          toDeviceIconData(device.type),
          color: Colors.white,
        ),
        backgroundColor: toPositionStatusColor(device.position),
      ),
      title: Text([device.number, device.alias].where((value) => emptyAsNull(value) != null).join(' ')),
      onTap: () => state.selectSuggestion(device),
    );
  }
}

class DeviceChip extends StatelessWidget {
  final Device device;
  final ChipsInputState state;

  const DeviceChip({
    Key key,
    @required this.device,
    this.state,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.caption;
    return InputChip(
      key: ObjectKey(device),
      labelPadding: EdgeInsets.only(left: 4.0),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            child: Icon(
              toDeviceIconData(device.type),
              size: 14.0,
              color: Colors.white,
            ),
            maxRadius: 10.0,
            backgroundColor: toPositionStatusColor(device.position),
          ),
          SizedBox(width: 6.0),
          Text(device.number, style: style),
        ],
      ),
      onDeleted: () => state.deleteChip(device),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class DeviceWidget extends StatelessWidget {
  final Unit unit;
  final Personnel personnel;
  final Device device;
  final bool withHeader;
  final bool withActions;
  final Tracking tracking;
  final ActionCallback onMessage;
  final ValueChanged<Point> onGoto;
  final ValueChanged<Device> onChanged;
  final ValueChanged<Device> onCompleted;
  final VoidCallback onDeleted;
  final Organisation organisation;

  const DeviceWidget({
    Key key,
    @required this.unit,
    @required this.personnel,
    @required this.device,
    @required this.tracking,
    @required this.onMessage,
    this.onGoto,
    this.onChanged,
    this.onCompleted,
    this.onDeleted,
    this.withHeader = true,
    this.withActions = true,
    this.organisation,
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
          if (withHeader) _buildHeader(theme, context),
          if (withHeader) Divider() else SizedBox(height: 8.0),
          if (Orientation.portrait == orientation) _buildPortrait(context, theme) else _buildLandscape(context, theme),
          if (withActions) ...[
            Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text("Handlinger", textAlign: TextAlign.left, style: theme.caption),
            ),
            DeviceActionGroup(
              type: ActionGroupType.buttonBar,
              unit: unit,
              device: device,
              personnel: personnel,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildData(context, theme),
      ));

  Widget _buildLandscape(BuildContext context, TextTheme theme) {
    final items = _buildData(context, theme);
    final median = items.length ~/ 2;
    return Padding(
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
              children: items.take(median).toList(),
            ),
          ),
          _buildDivider(Orientation.landscape),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items.skip(median).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildData(BuildContext context, TextTheme theme) => [
        _buildTypeAndStatusInfo(context),
        if (organisation != null && DeviceType.tetra == device.type) _buildTetraInfo(context),
        _buildDivider(Orientation.portrait),
        if (organisation != null && DeviceType.tetra == device.type) ...[
          _buildAffiliationInfo(context),
          _buildDivider(Orientation.portrait),
        ],
        _buildLocationInfo(context, theme),
        _buildDivider(Orientation.portrait),
        _buildTrackingInfo(context),
        _buildDivider(Orientation.portrait),
        _buildEffortInfo(context)
      ];

  Widget _buildDivider(Orientation orientation) => Orientation.portrait == orientation
      ? Divider(indent: 16.0, endIndent: 16.0)
      : VerticalDivider(indent: 16.0, endIndent: 16.0);

  Padding _buildHeader(TextTheme theme, BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Apparat ${device.name}', style: theme.headline6),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => _onComplete(device),
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
                  point: device.position?.geometry,
                  formatter: (point) => toUTM(
                    device.position?.geometry,
                    prefix: "",
                    empty: "Ingen",
                  ),
                ),
                buildCopyableLocation(
                  context,
                  label: "Desimalgrader (DD)",
                  icon: Icons.my_location,
                  point: device.position?.geometry,
                  formatter: (point) => toDD(
                    device.position?.geometry,
                    prefix: "",
                    empty: "Ingen",
                  ),
                ),
              ],
            ),
          ),
          if (device.position != null)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.navigation, color: Colors.black45),
                    onPressed: device.position == null
                        ? null
                        : () {
                            navigateToLatLng(
                              context,
                              toLatLng(device.position.geometry),
                            );
                            _onComplete(device);
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
    Point point,
    String label,
    IconData icon,
    String formatter(Point location),
  }) =>
      buildCopyableText(
        context: context,
        label: label,
        icon: Icon(icon),
        value: formatter(point),
        onMessage: onMessage,
        onComplete: _onComplete,
        onTap: () => _onGoto(point),
      );

  void _onGoto(Point location) {
    if (onGoto != null && location != null) onGoto(location);
  }

  Row _buildTypeAndStatusInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Type",
              icon: Icon(Icons.headset_mic),
              value: translateDeviceType(device.type),
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Status",
              icon: Icon(Icons.live_help),
              value: translateDeviceStatus(device.status),
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ],
      );

  Widget _buildTetraInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Number",
              icon: Icon(Icons.looks_one),
              value: device.number ?? 'Ingen',
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Funksjon",
              icon: Icon(Icons.functions),
              value: context.bloc<AffiliationBloc>().findFunction(device.number)?.name ?? 'Ingen',
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ],
      );

  Widget _buildAffiliationInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Tilhørighet",
              icon: SarSysIcons.of(organisation.prefix),
              value: context.bloc<AffiliationBloc>().findEntityName(device.number),
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ],
      );

  Row _buildTrackingInfo(BuildContext context) {
    final track = _toTrack(tracking);
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Knyttet til",
            icon: Icon(Icons.link),
            value: unit?.name ?? personnel?.formal ?? "Ingen",
            onMessage: onMessage,
            onComplete: _onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Avstand sporet",
            icon: Icon(MdiIcons.tapeMeasure),
            value: formatDistance(TrackingUtils.distance(track, tail: track.length)),
            onMessage: onMessage,
            onComplete: _onComplete,
          ),
        ),
      ],
    );
  }

  Iterable<Position> _toTrack(Tracking tracking) {
    return (tracking != null
            ? TrackingUtils.find(
                tracking.tracks,
                device.uuid,
              )?.positions
            : null) ??
        [];
  }

  Row _buildEffortInfo(BuildContext context) {
    final track = _toTrack(tracking);
    final effort = TrackingUtils.effort(track);
    final distance = TrackingUtils.distance(track, tail: track.length);
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Innsatstid",
            icon: Icon(Icons.timer),
            value: "${formatDuration(effort)}",
            onMessage: onMessage,
            onComplete: _onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Gj.snitthastiget",
            icon: Icon(MdiIcons.speedometer),
            value: "${(TrackingUtils.speed(distance, effort) * 3.6).toStringAsFixed(1)} km/t",
            onMessage: onMessage,
            onComplete: _onComplete,
          ),
        ),
      ],
    );
  }

  void _onComplete([device]) {
    if (onCompleted != null) onCompleted(device ?? this.device);
  }
}

class DeviceActionGroup extends StatelessWidget {
  DeviceActionGroup({
    @required this.type,
    @required this.device,
    this.unit,
    this.personnel,
    this.onDeleted,
    this.onMessage,
    this.onChanged,
    this.onCompleted,
  });
  final Unit unit;
  final Device device;
  final Personnel personnel;
  final VoidCallback onDeleted;
  final ActionGroupType type;
  final MessageCallback onMessage;
  final ValueChanged<Device> onChanged;
  final ValueChanged<Device> onCompleted;

  @override
  Widget build(BuildContext context) {
    return ActionGroupBuilder(
      type: type,
      builder: _buildActionItems,
    );
  }

  List<ActionMenuItem> _buildActionItems(BuildContext context) {
    final isSelected = context.bloc<OperationBloc>().isSelected;

    return <ActionMenuItem>[
      ActionMenuItem(
        child: IgnorePointer(child: _buildEditButton(context)),
        onPressed: _onEdit,
      ),
      if (unit != null)
        ActionMenuItem(
          child: IgnorePointer(child: _buildRemoveFromUnitAction(context)),
          onPressed: _onRemoveFromUnit,
        )
      else if (personnel != null)
        ActionMenuItem(
          child: IgnorePointer(child: _buildRemoveFromPersonnelAction(context)),
          onPressed: _onRemoveFromPersonnel,
        )
      else if (isSelected)
        ActionMenuItem(
          child: IgnorePointer(child: _buildAddToUnitAction(context)),
          onPressed: _onAddToUnit,
        ),
      if (device.manual == true && context.bloc<UserBloc>().user.isAdmin)
        ActionMenuItem(
          child: IgnorePointer(child: _buildDeleteAction(context)),
          onPressed: _onDelete,
        ),
    ];
  }

  Widget _buildEditButton(BuildContext context) => Tooltip(
        message: "Endre apparat",
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
    final result = await editDevice(device);
    if (result.isRight()) {
      final actual = result.toIterable().first;
      if (actual != device) {
        _onMessage("${actual.name} er oppdatert");
        _onChanged(actual);
      }
      _onCompleted();
    }
  }

  Widget _buildAddToUnitAction(BuildContext context) => Tooltip(
        message: "Knytt apparat til mannskap",
        child: FlatButton.icon(
          icon: Icon(Icons.person),
          label: Text(
            'KNYTT',
            textAlign: TextAlign.center,
          ),
          onPressed: _onAddToUnit,
        ),
      );

  Future _onAddToUnit() async {
    final result = await addToPersonnel([device], personnel: personnel);
    if (result.isRight()) {
      var actual = result.toIterable().first;
      _onMessage("${device.name} er tilknyttet ${actual.left.name}");
      _onChanged(device);
    }
  }

  Widget _buildRemoveFromUnitAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Fjern apparat fra unit",
      child: FlatButton.icon(
        icon: Icon(
          Icons.people,
          color: Colors.red,
        ),
        label: Text(
          'FJERN',
          textAlign: TextAlign.center,
          style: button.copyWith(
            color: Colors.red,
          ),
        ),
        onPressed: _onRemoveFromUnit,
      ),
    );
  }

  Future _onRemoveFromUnit() async {
    final result = await removeFromUnit(unit, devices: [device]);
    if (result.isRight()) {
      _onMessage("${device.name} er fjernet fra ${unit.name}");
      _onChanged(device);
    }
  }

  Widget _buildRemoveFromPersonnelAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Fjern apparat fra mannskap",
      child: FlatButton.icon(
        icon: Icon(
          Icons.person,
          color: Colors.red,
        ),
        label: Text(
          'FJERN',
          textAlign: TextAlign.center,
          style: button.copyWith(
            color: Colors.red,
          ),
        ),
        onPressed: _onRemoveFromPersonnel,
      ),
    );
  }

  Future _onRemoveFromPersonnel() async {
    final result = await removeFromPersonnel(personnel, devices: [device]);
    if (result.isRight()) {
      _onMessage("${device.name} er fjernet fra ${unit.name}");
      _onChanged(device);
    }
  }

  Widget _buildDeleteAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Slett apparat lagt til manuelt",
      child: FlatButton.icon(
          icon: Icon(MdiIcons.cellphoneBasic),
          label: Text(
            'SLETT',
            textAlign: TextAlign.center,
            style: button.copyWith(color: Colors.red),
          ),
          onPressed: () async {
            final result = await deleteDevice(device);
            if (result.isRight()) {
              _onMessage("${device.name} er slettet");
              _onDelete();
            }
          }),
    );
  }

  void _onDelete() async {
    final result = await deleteDevice(device);
    if (result.isRight()) {
      _onMessage("${device.name} er slettet");
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
    if (onCompleted != null) onCompleted(personnel ?? this.device);
  }

  void _onDeleted() {
    if (onDeleted != null) onDeleted();
  }
}
