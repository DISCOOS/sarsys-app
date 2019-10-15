import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/device.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DeviceInfoPanel extends StatelessWidget {
  final Unit unit;
  final Device device;
  final bool withHeader;
  final bool withActions;
  final Tracking tracking;
  final MessageCallback onMessage;
  final ValueChanged<Device> onChanged;
  final ValueChanged<Device> onComplete;
  final Future<Organization> organization;

  const DeviceInfoPanel({
    Key key,
    @required this.unit,
    @required this.device,
    @required this.tracking,
    @required this.onMessage,
    this.onChanged,
    this.onComplete,
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
        if (withHeader) _buildHeader(device, theme, context),
        if (withHeader) Divider(),
        _buildLocationInfo(context, device, theme),
        Divider(),
        _buildContactInfo(context),
        Divider(),
        if (organization != null && DeviceType.Tetra == device.type) ...[
          _buildTetraInfo(context),
          Divider(),
        ],
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

  Padding _buildHeader(Device device, TextTheme theme, BuildContext context) {
    return Padding(
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
  }

  Row _buildLocationInfo(BuildContext context, Device device, TextTheme theme) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 4,
          child: Column(
            children: <Widget>[
              buildCopyableLocation(
                context,
                label: "UTM",
                icon: Icons.my_location,
                location: device?.point,
                formatter: (point) => toUTM(device?.point, prefix: "", empty: "Ingen"),
              ),
              buildCopyableLocation(
                context,
                label: "Desimalgrader (DD)",
                icon: Icons.my_location,
                location: device?.point,
                formatter: (point) => toDD(device?.point, prefix: "", empty: "Ingen"),
              ),
            ],
          ),
        ),
        if (device?.point != null)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.navigation, color: Colors.black45),
                  onPressed: device?.point == null
                      ? null
                      : () {
                          navigateToLatLng(context, toLatLng(device?.point));
                          _onComplete(device);
                        },
                ),
                Text("Naviger", style: theme.caption),
              ],
            ),
          ),
      ],
    );
  }

  Widget buildCopyableLocation(
    BuildContext context, {
    Point location,
    String label,
    IconData icon,
    String formatter(Point location),
  }) {
    return buildCopyableText(
      context: context,
      label: label,
      icon: Icon(icon),
      value: formatter(location),
      onTap: location == null
          ? null
          : () => jumpToPoint(
                context,
                center: location,
              ),
      onMessage: onMessage,
      onComplete: _onComplete,
    );
  }

  Row _buildContactInfo(BuildContext context) {
    return Row(
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
          child: GestureDetector(
            child: buildCopyableText(
              context: context,
              label: "Nummer",
              icon: Icon(Icons.looks_one),
              value: device?.number,
              onMessage: onMessage,
              onComplete: _onComplete,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTetraInfo(BuildContext context) {
    return FutureBuilder<Organization>(
        future: organization,
        builder: (context, snapshot) {
          return Row(
            children: <Widget>[
              Expanded(
                child: buildCopyableText(
                  context: context,
                  label: "Distrikt",
                  icon: Icon(Icons.home),
                  value: snapshot.hasData ? snapshot.data.toDistrict(device.number) : '-',
                  onMessage: onMessage,
                  onComplete: _onComplete,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  child: buildCopyableText(
                    context: context,
                    label: "Funksjon",
                    icon: Icon(Icons.functions),
                    value: snapshot.hasData ? snapshot.data.toFunction(device.number) : '-',
                    onMessage: onMessage,
                    onComplete: _onComplete,
                  ),
                ),
              ),
            ],
          );
        });
  }

  Row _buildTrackingInfo(BuildContext context) {
    final List<Point> track = _toTrack(tracking);
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Spores av",
            icon: Icon(Icons.group),
            value: unit?.name ?? "Ingen",
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

  List<Point> _toTrack(Tracking tracking) => tracking != null ? tracking.tracks[device.id] ?? [] : [];

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

  Widget _buildActions(BuildContext context, Unit unit) {
    return ButtonBarTheme(
      // make buttons use the appropriate styles for cards
      child: ButtonBar(
        alignment: MainAxisAlignment.start,
        children: <Widget>[
          _buildEditAction(context),
          if (unit != null)
            _buildRemoveAction(context, unit)
          else ...[
            _buildCreateAction(context),
            _buildAttachAction(context, unit),
          ],
          _buildReleaseAction(context),
        ],
      ),
      data: ButtonBarThemeData(
        layoutBehavior: ButtonBarLayoutBehavior.constrained,
        buttonPadding: EdgeInsets.all(8.0),
      ),
    );
  }

  Widget _buildAttachAction(BuildContext context, Unit unit) {
    return Tooltip(
      message: "Knytt apparat til enhet",
      child: FlatButton(
          child: Text(
            'KNYTT',
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await addToUnit(context, [device], unit: unit);
            if (result.isRight()) {
              var actual = result.toIterable().first.left;
              _onMessage("${device.name} er tilknyttet ${actual.name}");
              _onChanged(device);
            }
          }),
    );
  }

  Widget _buildEditAction(BuildContext context) {
    return Tooltip(
      message: "Endre apparat",
      child: FlatButton(
        child: Text(
          'ENDRE',
          textAlign: TextAlign.center,
        ),
        onPressed: () async {
          final result = await editDevice(context, device);
          if (result.isRight() && result.toIterable().first != device) {
            var actual = result.toIterable().first;
            _onMessage("${actual.name} er oppdatert");
            _onChanged(actual);
          }
        },
      ),
    );
  }

  Widget _buildCreateAction(BuildContext context) {
    return Tooltip(
      message: "Opprett enhet fra apparat",
      child: FlatButton(
        child: Text(
          'OPPRETT',
          textAlign: TextAlign.center,
        ),
        onPressed: () async {
          final result = await createUnit(context, devices: [device]);
          if (result.isRight()) {
            final actual = result.toIterable().first;
            _onMessage("${device.name} er tilknyttet ${actual.name}");
            _onChanged(device);
          }
        },
      ),
    );
  }

  Widget _buildRemoveAction(BuildContext context, Unit unit) {
    return Tooltip(
      message: "Fjern apparat fra enhet",
      child: FlatButton(
          child: Text(
            'FJERN',
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await removeFromUnit(context, unit, devices: [device]);
            if (result.isRight()) {
              _onMessage("${device.name} er fjernet fra ${unit.name}");
              _onChanged(device);
            }
          }),
    );
  }

  Widget _buildReleaseAction(BuildContext context) {
    return Tooltip(
      message: "Frigi apparat fra hendelse",
      child: FlatButton(
          child: Text(
            'FRIGI',
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            final result = await detachDevice(context, device);
            if (result.isRight()) {
              _onMessage("${device.name} er frigitt");
              _onComplete();
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
}
