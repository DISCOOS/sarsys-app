import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'package:SarSys/core/callbacks.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/tracking/presentation/widgets/coordinate_widget.dart';
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

class DeviceTile extends StatelessWidget {
  const DeviceTile({
    Key key,
    @required this.device,
    this.status,
    this.units,
    this.personnel,
  }) : super(key: key);
  final Device device;
  final TrackingStatus status;
  final Map<String, Unit> units;
  final Map<String, Personnel> personnel;

  @override
  Widget build(BuildContext context) {
    final person = context.bloc<AffiliationBloc>().persons.findUser(
          device.networkId,
        );
    String title = _toDeviceTitle(
      context,
      person,
      device,
    );

    return ListTile(
      key: ObjectKey(device),
      leading: CircleAvatar(
        backgroundColor: toPositionStatusColor(
          device.position,
        ),
        child: Icon(toDeviceIconData(
          device.type,
        )),
        foregroundColor: Colors.white,
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(title),
                labelPadding: EdgeInsets.only(right: 4.0),
                backgroundColor: Colors.grey[100],
                avatar: Icon(
                  toDialerIconData(device.type),
                  size: 16.0,
                  color: Colors.black38,
                ),
              ),
            ),
          ),
          Container(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                  label: Text(_toUsage(units, personnel, device)),
                  labelPadding: EdgeInsets.only(right: 4.0),
                  backgroundColor: Colors.grey[100],
                  avatar: Icon(
                    Icons.my_location,
                    size: 16.0,
                    color: toPositionStatusColor(device?.position),
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceChip extends StatelessWidget {
  const DeviceChip({
    Key key,
    @required this.device,
  }) : super(key: key);

  final Device device;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.caption;
    final person = context.bloc<AffiliationBloc>().persons.findUser(
          device.networkId,
        );
    final name = _toDeviceTitle(
      context,
      person,
      device,
    );
    return Chip(
      key: ObjectKey(device),
      labelPadding: EdgeInsets.symmetric(horizontal: 4.0),
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
          if (name != null) Text(name, style: style),
        ],
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class DeviceWidget extends StatelessWidget {
  DeviceWidget({
    Key key,
    @required this.unit,
    @required this.device,
    @required this.tracking,
    @required this.onMessage,
    this.person,
    this.personnel,
    this.organisation,
    this.onGoto,
    this.onChanged,
    this.onCompleted,
    this.onDeleted,
    this.withMap = false,
    this.withHeader = true,
    this.withActions = true,
    this.withActivity = true,
    MapWidgetController controller,
  })  : this.controller = controller ?? MapWidgetController(),
        super(key: key);

  final Unit unit;
  final bool withMap;
  final Device device;
  final Person person;
  final bool withHeader;
  final bool withActions;
  final bool withActivity;
  final Tracking tracking;
  final Personnel personnel;
  final ActionCallback onMessage;
  final ValueChanged<Point> onGoto;
  final ValueChanged<Device> onChanged;
  final ValueChanged<Device> onCompleted;
  final VoidCallback onDeleted;
  final Organisation organisation;
  final MapWidgetController controller;

  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 2.0;

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
          if (withMap) _buildMap(context),
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
      padding: const EdgeInsets.only(left: 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildData(context, theme),
      ));

  Widget _buildLandscape(BuildContext context, TextTheme theme) {
    final items = _buildData(context, theme);
    final median = items.length ~/ 2;
    final reminder = items.skip(median).toList();
    if (reminder.first is Divider) {
      reminder.removeAt(0);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 0.0),
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
              children: reminder.toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildData(BuildContext context, TextTheme theme) {
    final bloc = context.bloc<AffiliationBloc>();
    final entity = _getEntity(bloc, person, device);
    final org = organisation ?? bloc.orgs[entity?.org?.uuid];

    return [
      _buildTypeAndStatusInfo(context),
      _buildAliasAndNumberInfo(context),
      _buildUsageAndFunction(context),
      _buildDivider(Orientation.portrait),
      if (person?.name != null)
        _buildAffiliationInfo(
          context,
          bloc.toName(entity, empty: 'Uorganisert'),
          SarSysIcons.of(org?.prefix),
        ),
      _buildOwnerInfo(
        context,
        person?.name ?? bloc.toName(entity),
        person?.name == null ? SarSysIcons.of(org?.prefix) : Icon(Icons.person),
      ),
      _buildDivider(Orientation.portrait),
      _buildLocationInfo(context, theme),
      _buildDivider(Orientation.portrait),
      _buildTrackingInfo(context),
      _buildDivider(Orientation.portrait),
      _buildEffortInfo(context)
    ];
  }

  Widget _buildDivider(Orientation orientation) => Orientation.portrait == orientation
      ? Divider(indent: 16.0, endIndent: 16.0)
      : VerticalDivider(indent: 16.0, endIndent: 16.0);

  ListTile _buildHeader(TextTheme theme, BuildContext context) => ListTile(
      selected: true,
      title: Text('Apparat', style: theme.headline6),
      subtitle: Text('${device.name}'),
      trailing: IconButton(
        icon: Icon(Icons.close),
        onPressed: () => _onComplete(device),
      ));

  Widget _buildMap(BuildContext context) {
    final center = device.position?.toLatLng();
    return Padding(
      padding: const EdgeInsets.all(8.0).copyWith(top: 0.0),
      child: Material(
        elevation: ELEVATION,
        borderRadius: BorderRadius.circular(CORNER),
        child: Container(
          height: 240.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CORNER),
            child: GestureDetector(
              child: MapWidget(
                key: ObjectKey(device.uuid),
                center: center,
                zoom: 16.0,
                readZoom: true,
                withRead: true,
                withWrite: true,
                withUnits: false,
                withDevices: true,
                interactive: false,
                withScaleBar: true,
                withControls: true,
                withTracking: false,
                withPersonnel: false,
                withControlsZoom: true,
                withControlsLayer: true,
                withControlsBaseMap: true,
                withControlsOffset: 16.0,
                showLayers: [
                  MapWidgetState.LAYER_POI,
                  MapWidgetState.LAYER_DEVICE,
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

  Widget _buildLocationInfo(BuildContext context, TextTheme theme) => Column(
        children: [
          CoordinateWidget(
            point: device.position?.geometry,
            timestamp: device.position?.timestamp,
            accuracy: device.position?.acc,
            onGoto: (point) => navigateToLatLng(context, toLatLng(point)),
            onMessage: onMessage,
            withIcons: true,
            withNavigation: true,
            onComplete: () => _onComplete(device),
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

  Row _buildAliasAndNumberInfo(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Alias",
              icon: Icon(Icons.info),
              value: device.alias ?? '-',
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
          Expanded(
            child: GestureDetector(
              child: buildCopyableText(
                context: context,
                label: "Nummer",
                icon: Icon(Icons.phone),
                value: device.number ?? "Ukjent",
                onMessage: onMessage,
                onComplete: _onComplete,
              ),
              onTap: () {
                final number = device.number ?? '';
                if (number.isNotEmpty) launch("tel:$number");
              },
            ),
          ),
        ],
      );

  Widget _buildUsageAndFunction(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: buildCopyableText(
              context: context,
              label: "Benyttes av",
              icon: Icon(Icons.link),
              value: unit?.name ?? personnel?.formal ?? "Ingen",
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

  Widget _buildOwnerInfo(BuildContext context, String name, Icon icon) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Eier",
            onMessage: onMessage,
            onComplete: _onComplete,
            icon: icon,
            value: name,
          ),
        ),
      ],
    );
  }

  Widget _buildAffiliationInfo(BuildContext context, String name, Icon icon) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Tilhørighet",
            onMessage: onMessage,
            onComplete: _onComplete,
            icon: icon,
            value: name,
          ),
        ),
      ],
    );
  }

  Row _buildTrackingInfo(BuildContext context) {
    final track = _toTrack(tracking);
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Aktivitet",
            icon: Icon(Icons.local_activity),
            value: translateActivityType(device.position?.activity?.type),
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
        child: TextButton.icon(
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
      child: TextButton.icon(
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
      child: TextButton.icon(
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
      child: TextButton.icon(
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

Affiliation _getEntity(AffiliationBloc bloc, Person person, Device device) {
  return person == null
      ? bloc.findEntity(device.number)
      : bloc.findAffiliates(person).firstWhere(
            (a) => a.isOrganized,
            orElse: () => bloc.findEntity(device.number),
          );
}

String _toDeviceTitle(BuildContext context, Person person, Device device) {
  final bloc = context.bloc<AffiliationBloc>();
  final entity = _getEntity(bloc, person, device);
  final name = person?.fname ?? device.alias ?? bloc.orgs[entity?.org?.uuid]?.fleetMap?.alias;
  final alias = device.type != DeviceType.app
      ? device.alias ?? device.number
      : device.uuid.substring(
          device.uuid.length - 5,
        );
  final title = '${[name, alias].where((e) => e != null).toSet().join(' | ')}';
  return title;
}

String _toUsage(
  Map<String, Unit> units,
  Map<String, Personnel> personnel,
  Device device,
) {
  final name = units[device.uuid]?.name ?? personnel[device.uuid]?.formal ?? '';
  return "$name ${formatSince(device?.position?.timestamp, defaultValue: "ingen")}";
}
