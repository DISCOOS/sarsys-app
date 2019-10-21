import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/usecase/personnel.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class PersonnelInfoPanel extends StatelessWidget {
  final Personnel personnel;
  final Tracking tracking;
  final Iterable<Device> devices;
  final bool withHeader;
  final bool withActions;
  final ValueChanged<Personnel> onChanged;
  final ValueChanged<Personnel> onComplete;
  final MessageCallback onMessage;
  final Future<Organization> organization;

  const PersonnelInfoPanel({
    Key key,
    @required this.personnel,
    @required this.tracking,
    @required this.devices,
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
        if (withHeader) _buildHeader(personnel, theme, context),
        if (withHeader) Divider() else SizedBox(height: 8.0),
        _buildContactInfo(context),
        if (organization != null) _buildAffiliationInfo(context),
        Divider(),
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
          _buildActions(context, personnel)
        ]
      ],
    );
  }

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

  Row _buildLocationInfo(BuildContext context, TextTheme theme) {
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
      onTap: () => tracking?.point == null
          ? Navigator.pushReplacementNamed(context, 'map')
          : jumpToPoint(
              context,
              center: tracking?.point,
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
            label: "Navn",
            icon: Icon(Icons.person),
            value: personnel.name,
            onMessage: onMessage,
            onComplete: _onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Status",
            icon: Icon(MdiIcons.accountQuestionOutline),
            value: translatePersonnelStatus(personnel.status),
            onMessage: onMessage,
            onComplete: _onComplete,
          ),
        ),
      ],
    );
  }

  Widget _buildAffiliationInfo(BuildContext context) {
    return FutureBuilder<Organization>(
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
  }

  String _ensureAffiliation(AsyncSnapshot<Organization> snapshot) => snapshot.hasData
      ? "${snapshot.data.name}, ${snapshot.data.divisions[personnel.affiliation.division].name}, "
          "${snapshot.data.divisions[personnel.affiliation.division].departments[personnel.affiliation.department]}"
      : "-";

  Row _buildTrackingInfo(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Apparater",
            icon: Icon(MdiIcons.cellphoneBasic),
            value: devices?.map((device) => device.number)?.join(', ') ?? 'Ingen',
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

  Row _buildEffortInfo(BuildContext context) {
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

  Widget _buildActions(BuildContext context, Personnel personnel1) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ButtonBarTheme(
        // make buttons use the appropriate styles for cards
        child: ButtonBar(
          alignment: MainAxisAlignment.start,
          children: <Widget>[
            _buildEditAction(context),
            if (devices.isNotEmpty) _buildRemoveAction(context),
            _buildRetireAction(context),
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
            final result = await editPersonnel(context, personnel);
            if (result.isRight() && result.toIterable().first != personnel) {
              final actual = result.toIterable().first;
              _onMessage("${actual.name} er oppdatert");
              _onChanged(actual);
            }
            _onComplete();
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
            final result = await removeFromPersonnel(context, personnel, devices: devices);
            if (result.isRight()) {
              _onMessage("Apparater fjernet fra ${personnel.name}");
              _onChanged(personnel);
            }
            _onComplete();
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
            final result = await retirePersonnel(context, personnel);
            if (result.isRight()) {
              _onMessage("${personnel.name} er dimmitert");
              _onChanged(personnel);
            }
            _onComplete();
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
            final result = await deletePersonnel(context, personnel);
            if (result.isRight()) {
              _onMessage("${personnel.name} er slettet");
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
}
