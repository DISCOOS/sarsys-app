import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/plugins/icon_layer.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

class IncidentPage extends StatelessWidget {
  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 4.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  final Incident incident;

  const IncidentPage(this.incident, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.body1.copyWith(fontWeight: FontWeight.w400);
    final valueStyle = Theme.of(context).textTheme.headline.copyWith(fontWeight: FontWeight.w500, fontSize: 22.0);
    final unitStyle = Theme.of(context).textTheme.headline.copyWith(fontWeight: FontWeight.w500, fontSize: 10.0);
    final messageStyle = Theme.of(context).textTheme.title.copyWith(fontSize: 22.0);

    return Container(
      color: Color.fromRGBO(168, 168, 168, 0.6),
      child: Padding(
        padding: const EdgeInsets.all(SPACING),
        child: Stack(
          children: [
            ListView(
              physics: ClampingScrollPhysics(),
              children: [
                _buildMapTile(context, incident),
                SizedBox(height: SPACING),
                _buildGeneral(incident, labelStyle, valueStyle, unitStyle),
                SizedBox(height: SPACING),
                _buildJustification(incident, labelStyle, messageStyle, unitStyle),
                SizedBox(height: SPACING),
                _buildIPP(incident, labelStyle, messageStyle, unitStyle),
                SizedBox(height: SPACING),
                _buildPasscodes(incident, labelStyle, valueStyle, unitStyle),
                SizedBox(height: SPACING * 10),
              ],
            ),
            SafeArea(child: Align(alignment: Alignment.bottomCenter, child: _buildActions(context))),
          ],
        ),
      ),
    );
  }

  static const BASEMAP = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";

  Widget _buildMapTile(BuildContext context, Incident incident) {
    if (incident == null || incident.ipp == null || incident.ipp.isEmpty) {
      return Container(
        height: 240.0,
        child: Center(child: Text('Kart')),
        decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.5)),
      );
    }

    final point = LatLng(incident.ipp.lat, incident.ipp.lon);
    return Container(
      height: 240.0,
      child: Material(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CORNER),
          child: FlutterMap(
            key: ObjectKey(incident),
            options: MapOptions(
                center: point,
                zoom: 13,
                interactive: true,
                plugins: [
                  IconLayer(),
                ],
                onTap: (_) => Navigator.pushReplacementNamed(context, 'map')),
            layers: [
              TileLayerOptions(
                urlTemplate: BASEMAP,
              ),
              IconLayerOptions(
                point,
                Icon(
                  Icons.location_on,
                  size: 30,
                  color: Colors.red,
                ),
              )
            ],
          ),
        ),
        elevation: ELEVATION,
        borderRadius: BorderRadius.circular(CORNER),
      ),
    );
  }

  Row _buildGeneral(Incident incident, TextStyle valueStyle, TextStyle unitStyle, TextStyle labelStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _buildValueTile("Hendelse", enumDescription(incident.type), "", valueStyle, unitStyle, unitStyle),
        ),
        SizedBox(width: SPACING),
        Expanded(
          child: _buildValueTile("Innsats", "${formatSince(incident.occurred)}", "", valueStyle, unitStyle, unitStyle),
        ),
        SizedBox(width: SPACING),
        Expanded(
          child: _buildValueTile("Enheter", "0", "", valueStyle, unitStyle, unitStyle),
        ),
      ],
    );
  }

  Row _buildJustification(Incident incident, TextStyle valueStyle, TextStyle unitStyle, TextStyle labelStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile("Begrunnelse", incident.justification, "", valueStyle, unitStyle, unitStyle),
        ),
      ],
    );
  }

  Row _buildIPP(Incident incident, TextStyle valueStyle, TextStyle unitStyle, TextStyle labelStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile("IPP", toUTM(incident.ipp), "", valueStyle, unitStyle, unitStyle),
        ),
      ],
    );
  }

  Row _buildPasscodes(Incident incident, TextStyle valueStyle, TextStyle unitStyle, TextStyle labelStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: _buildValueTile(
              "Kode for aksjonsledelse", "${incident.passcodes.command}", "", valueStyle, unitStyle, unitStyle),
        ),
        SizedBox(width: SPACING),
        Expanded(
          flex: 2,
          child: _buildValueTile(
              "Kode for mannskap", "${incident.passcodes.personnel}", "", valueStyle, unitStyle, unitStyle),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 56,
            child: RaisedButton(
              elevation: ELEVATION,
              child: Text(
                "KANSELLER",
                style: TextStyle(fontSize: 20),
              ),
              onPressed: () => _onCancel(context),
              color: Colors.white,
              textTheme: ButtonTextTheme.normal,
            ),
          ),
        ),
        SizedBox(width: SPACING),
        Expanded(
          child: SizedBox(
            height: 56,
            child: RaisedButton(
              elevation: ELEVATION,
              child: Text(
                "FULLFØRT",
                style: TextStyle(fontSize: 20),
              ),
              onPressed: () => _onFinish(context),
            ),
          ),
        ),
      ],
    );
  }

  Material _buildValueTile(
    String label,
    String value,
    String unit,
    TextStyle labelStyle,
    TextStyle valueStyle,
    TextStyle unitStyle,
  ) {
    return Material(
      child: Container(
        height: HEIGHT,
        padding: PADDING,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            Spacer(),
            Wrap(children: [
              Text(value, style: valueStyle),
              Text(unit, style: unitStyle),
            ]),
          ],
        ),
      ),
      elevation: ELEVATION,
      borderRadius: BorderRadius.circular(CORNER),
    );
  }

  void _onCancel(BuildContext context) async {
    var cancel = await prompt(
      context,
      "Bekreft kansellering",
      "Dette vil stoppe alle sporinger og sette status til Kansellert",
    );
    if (cancel) {
      _setIncidentStatus(context, IncidentStatus.Cancelled);
      Navigator.pushReplacementNamed(context, "incidents");
    }
  }

  void _onFinish(BuildContext context) async {
    var finish = await prompt(
      context,
      "Bekreft løsning",
      "Dette vil stoppe alle sporinger og sette status til Løst",
    );
    if (finish) {
      _setIncidentStatus(context, IncidentStatus.Resolved);
      Navigator.pushReplacementNamed(context, "incidents");
    }
  }

  void _setIncidentStatus(BuildContext context, IncidentStatus status) {
    var bloc = BlocProvider.of<IncidentBloc>(context);
    var userId = BlocProvider.of<UserBloc>(context).user?.userId;
    var incident = bloc.current.withJson({"status": enumName(status)}, userId: userId);
    bloc.update(incident);
  }
}
