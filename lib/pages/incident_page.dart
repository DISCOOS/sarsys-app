import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

class IncidentPage extends StatefulWidget {
  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 4.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  const IncidentPage({Key key}) : super(key: key);

  @override
  _IncidentPageState createState() => _IncidentPageState();
}

class _IncidentPageState extends State<IncidentPage> {
  final _controller = ScrollController();

  bool _showHint = true;
  Future<void> _hidePending;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_testHint);
    _showAndDelayHide();
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.body1.copyWith(fontWeight: FontWeight.w400);
    final valueStyle = Theme.of(context).textTheme.headline.copyWith(fontWeight: FontWeight.w500, fontSize: 22.0);
    final unitStyle = Theme.of(context).textTheme.headline.copyWith(fontWeight: FontWeight.w500, fontSize: 10.0);
    return Container(
      color: Color.fromRGBO(168, 168, 168, 0.6),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            StreamBuilder<Incident>(
              stream: BlocProvider.of<IncidentBloc>(context).changes,
              builder: (context, snapshot) {
                var incident = snapshot.data;
                return snapshot.hasData
                    ? ListView(
                        controller: _controller,
                        padding: const EdgeInsets.all(IncidentPage.SPACING),
                        physics: AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildMapTile(context, snapshot.data),
                          SizedBox(height: IncidentPage.SPACING),
                          _buildGeneral(incident, labelStyle, valueStyle, unitStyle),
                          SizedBox(height: IncidentPage.SPACING),
                          _buildJustification(incident, labelStyle, valueStyle, unitStyle),
                          SizedBox(height: IncidentPage.SPACING),
                          _buildIPP(incident, labelStyle, valueStyle, unitStyle),
                          SizedBox(height: IncidentPage.SPACING),
                          _buildMeetup(incident, labelStyle, valueStyle, unitStyle),
                          SizedBox(height: IncidentPage.SPACING),
                          _buildReference(incident, labelStyle, valueStyle, unitStyle),
                          SizedBox(height: IncidentPage.SPACING),
                          _buildPasscodes(incident, labelStyle, valueStyle, unitStyle),
                          SizedBox(height: IncidentPage.SPACING),
                          _buildActions(context),
                        ],
                      )
                    : Container();
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                    alignment: Alignment.bottomRight,
                    child: IgnorePointer(
                      ignoring: !_showHint,
                      child: AnimatedOpacity(
                        child: FloatingActionButton.extended(
                          icon: Icon(Icons.arrow_downward),
                          label: Text("Gå til bunn"),
                          onPressed: () {
                            setState(() {
                              _showHint = false;
                            });
                            if (_controller.hasClients) {
                              _controller.animateTo(
                                _controller.position.maxScrollExtent,
                                curve: Curves.easeOut,
                                duration: const Duration(milliseconds: 250),
                              );
                            }
                          },
                        ),
                        opacity: _showHint ? 1.0 : 0.0,
                        duration: _showHint ? Duration.zero : Duration(milliseconds: 800),
                      ),
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTile(BuildContext context, Incident incident) {
    final ipp = incident.ipp != null ? toLatLng(incident.ipp) : null;
    final meetup = incident.meetup != null ? toLatLng(incident.meetup) : null;
    final fitBounds = LatLngBounds(ipp, meetup);
    return Container(
      height: 240.0,
      child: Material(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(IncidentPage.CORNER),
          child: GestureDetector(
            child: IncidentMap(
              center: meetup ?? ipp,
              fitBounds: fitBounds.isValid ? fitBounds : null,
              incident: incident,
              interactive: false,
            ),
            onTap: () => jumpToIncident(context, incident),
          ),
        ),
        elevation: IncidentPage.ELEVATION,
        borderRadius: BorderRadius.circular(IncidentPage.CORNER),
      ),
    );
  }

  Row _buildReference(Incident incident, TextStyle labelStyle, TextStyle valueStyle, TextStyle unitStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile("Referanse", incident.reference, "", labelStyle, valueStyle, unitStyle),
        ),
      ],
    );
  }

  Row _buildGeneral(Incident incident, TextStyle labelStyle, TextStyle valueStyle, TextStyle unitStyle) {
    final bloc = BlocProvider.of<UnitBloc>(context);
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: _buildValueTile("Type", translateIncidentType(incident.type), "", labelStyle, valueStyle, unitStyle),
        ),
        SizedBox(width: IncidentPage.SPACING),
        Expanded(
          child: StreamBuilder<int>(
              stream: Stream<int>.periodic(Duration(seconds: 1), (x) => x),
              builder: (context, snapshot) {
                return _buildValueTile(
                    "Innsats", "${formatSince(incident.occurred)}", "", labelStyle, valueStyle, unitStyle);
              }),
        ),
        SizedBox(width: IncidentPage.SPACING),
        Expanded(
          child: StreamBuilder<UnitState>(
              stream: bloc.state,
              builder: (context, snapshot) {
                return _buildValueTile("Enheter", "${bloc.count}", "", labelStyle, valueStyle, unitStyle);
              }),
        ),
      ],
    );
  }

  Row _buildJustification(Incident incident, TextStyle labelStyle, TextStyle valueStyle, TextStyle unitStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile("Begrunnelse", incident.justification, "", labelStyle, valueStyle, unitStyle),
        ),
      ],
    );
  }

  Row _buildIPP(Incident incident, TextStyle labelStyle, TextStyle valueStyle, TextStyle unitStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: GestureDetector(
            child: _buildValueTile("IPP", toUTM(incident?.ipp), "", labelStyle, valueStyle, unitStyle),
            onTap: () => jumpToPoint(context, center: incident?.ipp, incident: incident),
          ),
        ),
      ],
    );
  }

  Row _buildMeetup(Incident incident, TextStyle labelStyle, TextStyle valueStyle, TextStyle unitStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: GestureDetector(
            child: _buildValueTile(
                "Oppmøte", toUTM(incident?.meetup, empty: "Ikke oppgitt"), "", labelStyle, valueStyle, unitStyle),
            onTap: () => jumpToPoint(context, center: incident?.meetup, incident: incident),
          ),
        ),
      ],
    );
  }

  Row _buildPasscodes(Incident incident, TextStyle labelStyle, TextStyle valueStyle, TextStyle unitStyle) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: _buildValueTile(
              "Kode for aksjonsledelse", "${incident.passcodes?.command}", "", labelStyle, valueStyle, unitStyle),
        ),
        SizedBox(width: IncidentPage.SPACING),
        Expanded(
          flex: 2,
          child: _buildValueTile(
              "Kode for mannskap", "${incident.passcodes?.personnel}", "", labelStyle, valueStyle, unitStyle),
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
              elevation: IncidentPage.ELEVATION,
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
        SizedBox(width: IncidentPage.SPACING),
        Expanded(
          child: SizedBox(
            height: 56,
            child: RaisedButton(
              elevation: IncidentPage.ELEVATION,
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
        height: IncidentPage.HEIGHT,
        padding: IncidentPage.PADDING,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null && label.isNotEmpty) Text(label, style: labelStyle),
            if (label != null && label.isNotEmpty) Spacer(),
            Wrap(children: [
              Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
              Text(unit, style: unitStyle),
            ]),
          ],
        ),
      ),
      elevation: IncidentPage.ELEVATION,
      borderRadius: BorderRadius.circular(IncidentPage.CORNER),
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

  void _testHint() {
    final extent = _controller.position.extentAfter;
    if (extent > IncidentPage.HEIGHT / 2 && _hidePending == null) {
      _showAndDelayHide();
    } else if (extent < IncidentPage.HEIGHT / 2) {
      setState(() {
        _showHint = false;
      });
    }
  }

  void _showAndDelayHide() {
    setState(() {
      _showHint = true;
    });
    _hidePending = Future.delayed(const Duration(milliseconds: 3000), () {
      if (this.mounted) {
        _showHint = false;
        setState(() {});
        _hidePending.whenComplete(() => _hidePending = null);
      }
    });
  }
}
