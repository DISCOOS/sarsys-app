import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UnitInfoPanel extends StatelessWidget {
  final Unit unit;
  final bool withHeader;
  final TrackingBloc bloc;
  final ValueChanged<Unit> onChanged;
  final ValueChanged<Unit> onComplete;
  final MessageCallback onMessage;

  const UnitInfoPanel({
    Key key,
    @required this.unit,
    @required this.bloc,
    @required this.onMessage,
    this.onChanged,
    this.onComplete,
    this.withHeader = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final tracking = bloc.tracking[unit.tracking];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (withHeader) _buildHeader(unit, theme, context),
        if (withHeader) Divider(),
        _buildLocationInfo(context, tracking, theme),
        Divider(),
        _buildContactInfo(context, unit),
        Divider(),
        _buildTrackingInfo(context, tracking),
        Divider(),
        _buildEffortInfo(context, tracking),
        Divider(),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text("Handlinger", textAlign: TextAlign.left, style: theme.caption),
        ),
        _buildActions(context, unit)
      ],
    );
  }

  Padding _buildHeader(Unit unit, TextTheme theme, BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('${unit.name}', style: theme.title),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => _onComplete(unit),
          )
        ],
      ),
    );
  }

  Row _buildLocationInfo(BuildContext context, Tracking tracking, TextTheme theme) {
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
                tracking: tracking,
                formatter: (point) => toUTM(tracking?.point, prefix: "", empty: "Ingen"),
              ),
              buildCopyableLocation(
                context,
                label: "Desimalgrader (DD)",
                icon: Icons.my_location,
                tracking: tracking,
                formatter: (point) => toDD(tracking?.point, prefix: "", empty: "Ingen"),
              ),
            ],
          ),
        ),
        if (tracking?.point != null)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.navigation, color: Colors.black45),
                  onPressed: tracking?.point == null
                      ? null
                      : () {
                          navigateToLatLng(context, toLatLng(tracking?.point));
                          _onComplete();
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
    Tracking tracking,
    String label,
    IconData icon,
    String formatter(Point location),
  }) {
    return buildCopyableText(
      context: context,
      label: label,
      icon: Icon(icon),
      value: formatter(tracking?.point),
      onTap: tracking?.point == null
          ? null
          : () => jumpToPoint(
                context,
                center: tracking?.point,
              ),
      onMessage: onMessage,
      onComplete: _onComplete,
    );
  }

  Row _buildContactInfo(BuildContext context, Unit unit) {
    return Row(
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
              value: unit?.phone ?? "Ukjent",
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
  }

  Row _buildTrackingInfo(BuildContext context, Tracking tracking) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Apparater",
            icon: Icon(MdiIcons.cellphoneBasic),
            value: tracking?.devices?.map((id) => bloc.deviceBloc.devices[id]?.number)?.join(', ') ?? '',
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
  }

  Row _buildEffortInfo(BuildContext context, Tracking tracking) {
    return Row(
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
  }

  Widget _buildActions(BuildContext context, Unit unit) {
    List<Device> devices = bloc.getDevicesFromTrackingId(unit.tracking);
    return ButtonBarTheme(
      // make buttons use the appropriate styles for cards
      child: ButtonBar(
        alignment: MainAxisAlignment.start,
        children: <Widget>[
          FlatButton(
            child: Text(
              "ENDRE",
              textAlign: TextAlign.center,
            ),
            onPressed: () async {
              final result = await editUnit(context, unit);
              if (result.isRight() && result.toIterable().first != unit) {
                final actual = result.toIterable().first;
                _onMessage("${actual.name} er oppdatert");
                _onChanged(actual);
              }
              _onComplete();
            },
          ),
          if (devices.isNotEmpty)
            FlatButton(
              child: Text(
                "FJERN APPARATER",
                textAlign: TextAlign.center,
              ),
              onPressed: () async {
                final result = await removeFromUnit(context, unit, devices: devices);
                if (result.isRight()) {
                  _onMessage("Apparater fjernet fra ${unit.name}");
                  _onChanged(unit);
                }
                _onComplete();
              },
            ),
          FlatButton(
            child: Text(
              "OPPLØS",
              textAlign: TextAlign.center,
            ),
            onPressed: () async {
              final result = await retireUnit(context, unit);
              if (result.isRight()) {
                _onMessage("${unit.name} er oppløst");
              }
              _onComplete();
            },
          ),
        ],
      ),
      data: ButtonBarThemeData(
        layoutBehavior: ButtonBarLayoutBehavior.constrained,
        buttonPadding: EdgeInsets.all(8.0),
      ),
    );
  }

  void _onMessage(String message) {
    if (onMessage != null) onMessage(message);
  }

  void _onChanged([unit]) {
    if (onChanged != null) onChanged(unit);
  }

  void _onComplete([unit]) {
    if (onComplete != null) onComplete(unit ?? this.unit);
  }
}
