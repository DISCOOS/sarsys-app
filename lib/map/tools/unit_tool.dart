import 'dart:math' as math;

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/map/tools/map_tools.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong/latlong.dart';
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
  void doProcessLongPress(BuildContext context, List<Unit> units) {
    _show(context, units, _showUnitMenu);
  }

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

  void _showUnitMenu(
    BuildContext context,
    Unit unit,
  ) async {
    final title = Theme.of(context).textTheme.title;
    final tracking = bloc.tracks[unit.tracking];
    _execute(
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            return Dialog(
              elevation: 0,
              backgroundColor: Colors.white,
              child: SizedBox(
                height: 232,
                width: MediaQuery.of(context).size.width - 112,
                child: ListView(
                  children: <Widget>[
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.group),
                      title: Text("Endre ${unit.name}", style: title),
                      onTap: () => Navigator.pop(context, 1),
                    ),
                    Divider(),
                    ListTile(
                      dense: true,
                      leading: Icon(tracking.status == TrackingStatus.Tracking
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline),
                      title: Text(
                        tracking.status == TrackingStatus.Tracking ? "Stopp sporing" : "Start sporing",
                        style: title,
                      ),
                      onTap: () => Navigator.pop(context, 2),
                    ),
                    Divider(),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.content_copy),
                      title: Text("Kopier UTM", style: title),
                      onTap: () => Navigator.pop(context, 3),
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.content_copy),
                      title: Text("Kopier desmialgrader", style: title),
                      onTap: () => Navigator.pop(context, 4),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        context,
        unit,
        tracking);
  }

  void _execute(action, BuildContext context, Unit unit, Tracking tracking) {
    switch (action) {
      case 1:
        showDialog(
          context: context,
          builder: (context) => UnitEditor(unit: unit),
        );
        break;
      case 2:
        bloc.transition(tracking);
        break;
      case 3:
        copy(toUTM(tracking.location, prefix: ""), onMessage);
        break;
      case 4:
        copy(toDD(tracking.location, prefix: ""), onMessage);
        break;
    }
  }

  void _showUnitInfo(
    BuildContext context,
    Unit unit,
  ) {
    final style = Theme.of(context).textTheme.title;
    final tracking = bloc.tracks[unit.tracking];
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: 380,
            width: MediaQuery.of(context).size.width - 96,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('${unit.name}', style: style),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                Divider(),
                buildCopyableText(
                  context: context,
                  label: "UTM",
                  icon: Icon(Icons.my_location),
                  value: toUTM(tracking.location, prefix: ""),
                  action: tracking?.location == null ? null : Icon(Icons.navigation),
                  onAction: tracking?.location == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          navigateToLatLng(context, toLatLng(tracking.location));
                        },
                  onMessage: onMessage,
                ),
                buildCopyableText(
                  context: context,
                  label: "Desimalgrader (DD)",
                  icon: Icon(Icons.my_location),
                  value: toDD(tracking.location, prefix: ""),
                  action: tracking?.location == null ? null : Icon(Icons.navigation),
                  onAction: tracking?.location == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          navigateToLatLng(context, toLatLng(tracking.location));
                        },
                  onMessage: onMessage,
                ),
                Divider(),
                Row(
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
                ),
                Divider(),
                buildCopyableText(
                  context: context,
                  label: "Terminaler",
                  icon: Icon(FontAwesomeIcons.mobileAlt),
                  value: tracking.devices.map((id) => bloc.deviceBloc.devices[id]?.number)?.join(', ') ?? '',
                  onMessage: onMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
