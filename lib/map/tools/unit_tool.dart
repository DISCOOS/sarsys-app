import 'dart:math' as math;
import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/usecase/unit_transition.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong/latlong.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UnitTool extends MapTool with MapSelectable<Unit> {
  final TrackingBloc bloc;
  final MessageCallback onMessage;
  UnitTool(
    this.bloc, {
    bool active = false,
    this.onMessage,
  }) : super(active);

  @override
  Iterable<Unit> get targets => bloc.units.values;

  @override
  void doProcessTap(BuildContext context, List<Unit> units) {
    _show(context, units, _showUnitInfo);
  }

  @override
  LatLng toPoint(Unit unit) {
    return toLatLng(bloc.tracks[unit.tracking].location);
  }

  void _show(BuildContext context, List<Unit> units, Function onAction) {
    if (units.length == 1) {
      onAction(context, units.first);
    } else {
      final style = Theme.of(context).textTheme.title;
      final size = MediaQuery.of(context).size;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('Velg enhet', style: style),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                Divider(),
                SizedBox(
                  height: math.min(size.height - 150, 380),
                  width: MediaQuery.of(context).size.width - 96,
                  child: ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        leading: Icon(Icons.group),
                        title: Text("${units[index].name}"),
                        onTap: () {
                          Navigator.of(context).pop();
                          onAction(context, units[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _showUnitInfo(
    BuildContext context,
    Unit unit,
  ) {
    final theme = Theme.of(context).textTheme;
    final tracking = bloc.tracks[unit.tracking];
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: min(432.0, MediaQuery.of(context).size.height - 96),
            width: MediaQuery.of(context).size.width - 96,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeader(unit, theme, context),
                  Divider(),
                  _buildLocationInfo(context, tracking, theme),
                  Divider(indent: 42.0),
                  buildContactInfo(context, unit),
                  Divider(indent: 42.0),
                  _buildTrackingInfo(context, tracking),
                  Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                    child: Text("Handlinger", textAlign: TextAlign.left, style: theme.caption),
                  ),
                  _buildActions(context, unit)
                ],
              ),
            ),
          ),
        );
      },
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
            onPressed: () => Navigator.pop(context),
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
              buildCopyableText(
                context: context,
                label: "UTM",
                icon: Icon(Icons.my_location),
                value: toUTM(tracking.location, prefix: ""),
                onTap: () => tracking?.location == null
                    ? null
                    : jumpToPoint(
                        context,
                        center: tracking.location,
                      ),
                onMessage: onMessage,
              ),
              buildCopyableText(
                context: context,
                label: "Desimalgrader (DD)",
                value: toDD(tracking.location, prefix: ""),
                onTap: () => tracking?.location == null
                    ? null
                    : jumpToPoint(
                        context,
                        center: tracking.location,
                      ),
                onMessage: onMessage,
              ),
            ],
          ),
        ),
        if (tracking?.location != null)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.navigation, color: Colors.black45),
                  onPressed: () {
                    Navigator.pop(context);
                    navigateToLatLng(context, toLatLng(tracking.location));
                  },
                ),
                Text("Naviger", style: theme.caption),
              ],
            ),
          ),
      ],
    );
  }

  Row buildContactInfo(BuildContext context, Unit unit) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Kallesignal",
            icon: Icon(Icons.headset_mic),
            value: unit.callsign,
            onMessage: onMessage,
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
            value: tracking.devices.map((id) => bloc.deviceBloc.devices[id]?.number)?.join(', ') ?? '',
            onMessage: onMessage,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Avstand sporet",
            icon: Icon(MdiIcons.tapeMeasure),
            value: formatDistance(tracking.distance),
            onMessage: onMessage,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, Unit unit) {
    return Row(
      children: <Widget>[
        FlatButton(
          padding: EdgeInsets.zero,
          child: Text("Endre"),
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) => UnitEditor(unit: unit),
            );
          },
        ),
        FlatButton(
          padding: EdgeInsets.zero,
          child: Text("Oppløs"),
          onPressed: () async {
            Navigator.pop(context);
            final retireUnit = RetireUnit();
            final result = await retireUnit(UnitParams(context, unit));
            if (result.isRight() && onMessage != null) onMessage("${unit.name} er oppløst");
          },
        ),
      ],
    );
  }
}
