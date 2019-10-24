import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';

class IncidentPage extends StatefulWidget {
  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 4.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  final MessageCallback onMessage;

  const IncidentPage({
    Key key,
    @required this.onMessage,
  }) : super(key: key);

  @override
  _IncidentPageState createState() => _IncidentPageState();
}

class _IncidentPageState extends State<IncidentPage> {
  final _controller = ScrollController();

  UserBloc _userBloc;
  bool _showHint = true;

  TextStyle labelStyle;
  TextStyle valueStyle;
  TextStyle unitStyle;

  Future<void> _hidePending;

  @override
  void initState() {
    super.initState();
    _showAndDelayHide();
    _controller.addListener(_testHint);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
  }

  @override
  void dispose() {
    _controller.removeListener(_testHint);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<IncidentBloc>(context);
    labelStyle = Theme.of(context).textTheme.body1.copyWith(fontWeight: FontWeight.w400);
    valueStyle = Theme.of(context).textTheme.headline.copyWith(fontWeight: FontWeight.w500, fontSize: 18.0);
    unitStyle = Theme.of(context).textTheme.headline.copyWith(fontWeight: FontWeight.w500, fontSize: 10.0);
    return RefreshIndicator(
      onRefresh: () async {
        bloc.fetch();
      },
      child: Container(
        color: Color.fromRGBO(168, 168, 168, 0.6),
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Stack(
            children: [
              StreamBuilder<Incident>(
                stream: bloc.changes(),
                initialData: bloc.current,
                builder: (context, snapshot) {
                  final incident = (snapshot.hasData ? snapshot.data : null);
                  return incident == null
                      ? Center(
                          child: Text(snapshot.hasError ? "${snapshot.error}" : "Ingen data"),
                        )
                      : _buildDashboard(context, incident);
                },
              ),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  ListView _buildDashboard(BuildContext context, Incident incident) {
    return ListView(
      controller: _controller,
      padding: const EdgeInsets.all(IncidentPage.SPACING),
      physics: AlwaysScrollableScrollPhysics(),
      children: [
        _buildMapTile(context, incident),
        SizedBox(height: IncidentPage.SPACING),
        _buildGeneral(incident),
        SizedBox(height: IncidentPage.SPACING),
        _buildJustification(incident),
        SizedBox(height: IncidentPage.SPACING),
        _buildIPP(incident),
        SizedBox(height: IncidentPage.SPACING),
        _buildMeetup(incident),
        SizedBox(height: IncidentPage.SPACING),
        _buildReference(incident),
        SizedBox(height: IncidentPage.SPACING),
        _buildPasscodes(incident),
        if (_userBloc?.user?.isCommander) ...[SizedBox(height: IncidentPage.SPACING), _buildActions(context)],
      ],
    );
  }

  SafeArea _buildBottomActions() {
    return SafeArea(
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
    );
  }

  Widget _buildMapTile(BuildContext context, Incident incident) {
    final ipp = incident.ipp != null ? toLatLng(incident.ipp.point) : null;
    final meetup = incident.meetup != null ? toLatLng(incident.meetup.point) : null;
    final fitBounds = LatLngBounds(ipp, meetup);
    return Container(
      height: 240.0,
      child: Material(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(IncidentPage.CORNER),
          child: GestureDetector(
            child: IncidentMap(
              center: meetup ?? ipp,
              fitBounds: fitBounds,
              fitBoundOptions: FitBoundsOptions(
                zoom: Defaults.zoom,
                maxZoom: Defaults.zoom,
                padding: EdgeInsets.all(48.0),
              ),
              incident: incident,
              interactive: false,
              withRead: true,
            ),
            onTap: () => jumpToIncident(context, incident),
          ),
        ),
        elevation: IncidentPage.ELEVATION,
        borderRadius: BorderRadius.circular(IncidentPage.CORNER),
      ),
    );
  }

  Row _buildReference(Incident incident) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile(incident.reference, label: "Referanse"),
        ),
      ],
    );
  }

  Row _buildGeneral(Incident incident) {
    final unitBloc = BlocProvider.of<UnitBloc>(context);
    final personnelBloc = BlocProvider.of<PersonnelBloc>(context);
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: _buildValueTile(translateIncidentType(incident.type), label: "Type"),
        ),
        SizedBox(width: IncidentPage.SPACING),
        Expanded(
          child: StreamBuilder<int>(
              stream: Stream<int>.periodic(Duration(seconds: 1), (x) => x),
              builder: (context, snapshot) {
                return _buildValueTile("${snapshot.hasData ? formatSince(incident.occurred) : "-"}", label: "Innsats");
              }),
        ),
        SizedBox(width: IncidentPage.SPACING),
        Expanded(
          child: StreamBuilder<PersonnelState>(
              stream: personnelBloc.state,
              builder: (context, snapshot) {
                return _buildValueTile("${snapshot.hasData ? personnelBloc.count() : "-"}", label: "Mnsk");
              }),
        ),
        SizedBox(width: IncidentPage.SPACING),
        Expanded(
          child: StreamBuilder<UnitState>(
              stream: unitBloc.state,
              builder: (context, snapshot) {
                return _buildValueTile("${snapshot.hasData ? unitBloc.count() : "-"}", label: "Enheter");
              }),
        ),
      ],
    );
  }

  Row _buildJustification(Incident incident) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile(incident.justification, label: "Begrunnelse"),
        ),
      ],
    );
  }

  Row _buildIPP(Incident incident) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile(
            toUTM(incident.ipp?.point),
            label: "IPP",
            subtitle: incident?.ipp?.description,
            icon: Icons.navigation,
            onIconTap: () => navigateToLatLng(context, toLatLng(incident?.ipp?.point)),
            onValueTap: () => jumpToPoint(context, center: incident?.ipp?.point, incident: incident),
            onValueLongPress: () => copy(
              toUTM(incident?.ipp?.point, prefix: "", empty: "Ingen"),
              widget.onMessage,
              message: 'IPP kopiert til utklippstavlen',
            ),
          ),
        ),
      ],
    );
  }

  Row _buildMeetup(Incident incident) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile(
            toUTM(incident?.meetup?.point, empty: "Ikke oppgitt"),
            label: "Oppmøte",
            subtitle: incident?.meetup?.description,
            icon: Icons.navigation,
            onIconTap: () => navigateToLatLng(context, toLatLng(incident?.meetup?.point)),
            onValueTap: () => jumpToPoint(context, center: incident?.meetup?.point, incident: incident),
            onValueLongPress: () => copy(
              toUTM(incident?.meetup?.point, prefix: "", empty: "Ingen"),
              widget.onMessage,
              message: 'Oppmøte kopiert til utklippstavlen',
            ),
          ),
        ),
      ],
    );
  }

  Row _buildPasscodes(Incident incident) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: _buildValueTile("${incident.passcodes?.command}", label: "Kode for aksjonsledelse"),
        ),
        SizedBox(width: IncidentPage.SPACING),
        Expanded(
          flex: 2,
          child: _buildValueTile("${incident.passcodes?.personnel}", label: "Kode for mannskap"),
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

  Widget _buildValueTile(
    String value, {
    String label,
    String subtitle,
    String unit,
    IconData icon,
    GestureTapCallback onIconTap,
    GestureTapCallback onValueTap,
    GestureTapCallback onValueLongPress,
  }) {
    Widget tile = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label.isNotEmpty) Text(label, style: labelStyle),
        if (label != null && label.isNotEmpty) Spacer(),
        Wrap(children: [
          Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
          if (unit != null && unit.isNotEmpty) Text(unit, style: unitStyle),
        ]),
        if (emptyAsNull(subtitle) != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.subhead.copyWith(fontSize: 14, color: Colors.grey),
            ),
          )
      ],
    );

    // Value detector?
    tile = onValueTap != null || onValueLongPress != null
        ? GestureDetector(
            child: tile,
            onTap: onValueTap,
            onLongPress: onValueLongPress,
          )
        : tile;

    if (icon != null) {
      Widget action = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 24.0,
              color: Colors.black45,
            ),
            SizedBox(
              child: Text(
                "Naviger",
                style: labelStyle.copyWith(fontSize: 12),
                softWrap: true,
              ),
            )
          ],
        ),
      );

      action = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          tile,
          SizedBox(width: IncidentPage.SPACING),
          action,
        ],
      );

      tile = onIconTap == null
          ? action
          : GestureDetector(
              child: action,
              onTap: onIconTap,
            );
    }

    return Material(
      child: Container(
        height: IncidentPage.HEIGHT * (emptyAsNull(subtitle) == null ? 1.0 : 1.25),
        padding: IncidentPage.PADDING,
        child: tile,
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
      Navigator.pushReplacementNamed(context, "incident/list");
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
      Navigator.pushReplacementNamed(context, "incident/list");
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
    if (mounted) {
      setState(() {
        _showHint = true;
      });
    }
    _hidePending = Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _showHint = false;
        setState(() {});
      }
    });
    _hidePending.whenComplete(() => _hidePending = null);
  }
}
