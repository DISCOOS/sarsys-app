import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/device.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chips_input/flutter_chips_input.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
        backgroundColor: toPointStatusColor(device.point),
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
            backgroundColor: toPointStatusColor(device.point),
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

class DeviceInfoPanel extends StatelessWidget {
  final Unit unit;
  final Personnel personnel;
  final Device device;
  final bool withHeader;
  final bool withActions;
  final Tracking tracking;
  final ActionCallback onMessage;
  final ValueChanged<Point> onGoto;
  final ValueChanged<Device> onChanged;
  final ValueChanged<Device> onComplete;
  final VoidCallback onDelete;
  final Future<Organization> organization;

  const DeviceInfoPanel({
    Key key,
    @required this.unit,
    @required this.personnel,
    @required this.device,
    @required this.tracking,
    @required this.onMessage,
    this.onGoto,
    this.onChanged,
    this.onComplete,
    this.onDelete,
    this.withHeader = true,
    this.withActions = true,
    this.organization,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (withHeader) _buildHeader(theme, context),
        if (withHeader) Divider() else SizedBox(height: 8.0),
        _buildTypeAndStatusInfo(context),
        if (organization != null && DeviceType.Tetra == device.type) _buildTetraInfo(context),
        Divider(),
        if (organization != null && DeviceType.Tetra == device.type) ...[
          _buildAffiliationInfo(context),
          Divider(),
        ],
        _buildLocationInfo(context, theme),
        Divider(),
        _buildTrackingInfo(context),
        Divider(),
        _buildEffortInfo(context),
        if (withActions) ...[
          Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text("Handlinger", textAlign: TextAlign.left, style: theme.caption),
          ),
          _buildActions(context, unit)
        ]
      ],
    );
  }

  Padding _buildHeader(TextTheme theme, BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 16, top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('${device.name}', style: theme.title),
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
                  location: device.point,
                  formatter: (point) => toUTM(device.point, prefix: "", empty: "Ingen"),
                ),
                buildCopyableLocation(
                  context,
                  label: "Desimalgrader (DD)",
                  icon: Icons.my_location,
                  location: device.point,
                  formatter: (point) => toDD(device.point, prefix: "", empty: "Ingen"),
                ),
              ],
            ),
          ),
          if (device.point != null)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.navigation, color: Colors.black45),
                    onPressed: device.point == null
                        ? null
                        : () {
                            navigateToLatLng(context, toLatLng(device.point));
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
    Point location,
    String label,
    IconData icon,
    String formatter(Point location),
  }) =>
      buildCopyableText(
        context: context,
        label: label,
        icon: Icon(icon),
        value: formatter(location),
        onMessage: onMessage,
        onComplete: _onComplete,
        onTap: () => _onGoto(location),
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

  Widget _buildTetraInfo(BuildContext context) => FutureBuilder<Organization>(
      future: organization,
      builder: (context, snapshot) {
        return Row(
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
                value: snapshot.hasData ? snapshot.data.toFunctionFromNumber(device.number) : '-',
                onMessage: onMessage,
                onComplete: _onComplete,
              ),
            ),
          ],
        );
      });

  Widget _buildAffiliationInfo(BuildContext context) => FutureBuilder<Organization>(
      future: organization,
      builder: (context, snapshot) {
        return Row(
          children: <Widget>[
            Expanded(
              child: buildCopyableText(
                context: context,
                label: "Tilhørighet",
                icon: Icon(MdiIcons.graph),
                value: _ensureAffiliation(snapshot),
                onMessage: onMessage,
                onComplete: _onComplete,
              ),
            ),
          ],
        );
      });

  String _ensureAffiliation(AsyncSnapshot<Organization> snapshot) =>
      snapshot.hasData ? snapshot.data.toAffiliationNameFromNumber(device.number) : "-";

  Row _buildTrackingInfo(BuildContext context) {
    final List<Point> track = _toTrack(tracking);
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Knyttet til",
            icon: Icon(Icons.group),
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
            value: formatDistance(asDistance(track, tail: track.length)),
            onMessage: onMessage,
            onComplete: _onComplete,
          ),
        ),
      ],
    );
  }

  List<Point> _toTrack(Tracking tracking) =>
      tracking?.tracks?.isNotEmpty == true ? tracking?.tracks[device.uuid]?.points ?? [] : [];

  Row _buildEffortInfo(BuildContext context) {
    final List<Point> track = _toTrack(tracking);
    final effort = asEffort(track);
    final distance = asDistance(track, tail: track.length);
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
            value: "${(asSpeed(distance, effort) * 3.6).toStringAsFixed(1)} km/t",
            onMessage: onMessage,
            onComplete: _onComplete,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, Unit unit) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ButtonBarTheme(
          // make buttons use the appropriate styles for cards
          child: ButtonBar(
            alignment: MainAxisAlignment.start,
            children: <Widget>[
              _buildEditAction(context),
              if (unit != null)
                _buildRemoveFromUnitAction(context)
              else ...[
                _buildCreateAction(context),
                _buildAddToUnitAction(context),
              ],
              if (device.manual) _buildDeleteAction(context),
            ],
          ),
          data: ButtonBarThemeData(
            layoutBehavior: ButtonBarLayoutBehavior.constrained,
            buttonPadding: EdgeInsets.all(0.0),
          ),
        ),
      );

  Widget _buildAddToUnitAction(BuildContext context) => Tooltip(
        message: "Knytt apparat til enhet",
        child: FlatButton(
            child: Text(
              'KNYTT',
              textAlign: TextAlign.center,
            ),
            onPressed: () async {
              final result = await addToUnit(devices: [device], unit: unit);
              if (result.isRight()) {
                var actual = result.toIterable().first.left;
                _onMessage("${device.name} er tilknyttet ${actual.name}");
                _onChanged(device);
              }
            }),
      );

  Widget _buildEditAction(BuildContext context) => Tooltip(
        message: "Endre apparat",
        child: FlatButton(
          child: Text(
            'ENDRE',
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await editDevice(device);
            if (result.isRight() && result.toIterable().first != device) {
              var actual = result.toIterable().first;
              _onMessage("${actual.name} er oppdatert");
              _onChanged(actual);
            }
          },
        ),
      );

  Widget _buildCreateAction(BuildContext context) => Tooltip(
        message: "Opprett enhet fra apparat",
        child: FlatButton(
          child: Text(
            'OPPRETT',
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await createUnit(devices: [device]);
            if (result.isRight()) {
              final actual = result.toIterable().first;
              _onMessage("${device.name} er tilknyttet ${actual.name}");
              _onChanged(device);
            }
          },
        ),
      );

  Widget _buildRemoveFromUnitAction(BuildContext context) => Tooltip(
        message: "Fjern apparat fra enhet",
        child: FlatButton(
            child: Text(
              'FJERN',
              textAlign: TextAlign.center,
            ),
            onPressed: () async {
              final result = await removeFromUnit(unit, devices: [device]);
              if (result.isRight()) {
                _onMessage("${device.name} er fjernet fra ${unit.name}");
                _onChanged(device);
              }
            }),
      );

  Widget _buildDeleteAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Slett apparat lagt til manuelt",
      child: FlatButton(
          child: Text(
            'SLETT',
            textAlign: TextAlign.center,
            style: button.copyWith(color: Colors.red),
          ),
          onPressed: () async {
            final result = await deleteDevice(context, device);
            if (result.isRight()) {
              _onMessage("${device.name} er slettet");
              _onDelete();
            }
          }),
    );
  }

  void _onMessage(String message) {
    if (onMessage != null) onMessage(message);
  }

  void _onChanged([device]) {
    if (onChanged != null) onChanged(device);
  }

  void _onComplete([device]) {
    if (onComplete != null) onComplete(device ?? this.device);
  }

  void _onDelete() {
    if (onDelete != null) onDelete();
  }
}
