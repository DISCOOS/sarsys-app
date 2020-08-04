import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:async/async.dart';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/presentation/map/map_widget.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/widgets/action_group.dart';

class OperationPage extends StatefulWidget {
  static const HEIGHT = 82.0;
  static const CORNER = 4.0;
  static const SPACING = 8.0;
  static const ELEVATION = 4.0;
  static const PADDING = EdgeInsets.fromLTRB(12.0, 16.0, 0, 16.0);

  final ActionCallback onMessage;

  const OperationPage({
    Key key,
    @required this.onMessage,
  }) : super(key: key);

  @override
  _OperationPageState createState() => _OperationPageState();
}

class _OperationPageState extends State<OperationPage> {
  final _controller = ScrollController();

  TextStyle labelStyle;
  TextStyle valueStyle;
  TextStyle unitStyle;

  StreamGroup<dynamic> _group;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group?.close();
    _group = StreamGroup<BlocEvent>.broadcast()
      ..add(context.bloc<UnitBloc>())
      ..add(context.bloc<OperationBloc>())
      ..add(context.bloc<PersonnelBloc>());
  }

  @override
  void dispose() {
    _group?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    labelStyle = Theme.of(context).textTheme.bodyText2.copyWith(fontWeight: FontWeight.w400);
    valueStyle = Theme.of(context).textTheme.headline5.copyWith(fontWeight: FontWeight.w500, fontSize: 18.0);
    unitStyle = Theme.of(context).textTheme.headline5.copyWith(fontWeight: FontWeight.w500, fontSize: 10.0);
    return RefreshIndicator(
      onRefresh: () async {
        context.bloc<OperationBloc>().load();
      },
      child: StreamBuilder<BlocEvent>(
        stream: _group.stream,
        builder: (context, snapshot) {
          final operation = context.bloc<OperationBloc>().selected;
          return Container(
            color: operation == null ? null : Color.fromRGBO(168, 168, 168, 0.6),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: operation == null
                  ? Center(
                      child: Text(snapshot.hasError ? "${snapshot.error}" : "Deltar ikke på aksjon"),
                    )
                  : _buildDashboard(
                      context,
                      context.bloc<OperationBloc>().incidents.get(operation.incident.uuid),
                      operation,
                    ),
            ),
          );
        },
      ),
    );
  }

  ListView _buildDashboard(BuildContext context, Incident incident, Operation operation) {
    return ListView(
      shrinkWrap: true,
      controller: _controller,
      padding: const EdgeInsets.all(OperationPage.SPACING),
      physics: AlwaysScrollableScrollPhysics(),
      children: [
        _buildMapTile(context, operation),
        SizedBox(height: OperationPage.SPACING),
        _buildGeneral(incident),
        SizedBox(height: OperationPage.SPACING),
        _buildJustification(operation),
        SizedBox(height: OperationPage.SPACING),
        _buildIPP(operation),
        SizedBox(height: OperationPage.SPACING),
        _buildMeetup(operation),
        SizedBox(height: OperationPage.SPACING),
        _buildPasscodes(operation),
        SizedBox(height: OperationPage.SPACING),
        _buildReference(operation),
      ],
    );
  }

  bool get isCommander => context.bloc<UserBloc>()?.user?.isCommander == true;

  Widget _buildMapTile(BuildContext context, Operation operation) {
    final ipp = operation.ipp != null ? toLatLng(operation.ipp.point) : null;
    final meetup = operation.meetup != null ? toLatLng(operation.meetup.point) : null;
    final fitBounds = LatLngBounds(ipp, meetup);
    return Container(
      height: 240.0,
      child: Material(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OperationPage.CORNER),
          child: GestureDetector(
            child: MapWidget(
              operation: operation,
              center: meetup ?? ipp,
              fitBounds: fitBounds,
              fitBoundOptions: FitBoundsOptions(
                zoom: Defaults.zoom,
                maxZoom: Defaults.zoom,
                padding: EdgeInsets.all(48.0),
              ),
              interactive: false,
              withRead: true,
            ),
            onTap: () => jumpToOperation(context, operation),
          ),
        ),
        elevation: OperationPage.ELEVATION,
        borderRadius: BorderRadius.circular(OperationPage.CORNER),
      ),
    );
  }

  Row _buildReference(Operation operation) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile(emptyAsNull(operation.reference) ?? 'Ingen', label: "Referanse"),
        ),
      ],
    );
  }

  Row _buildGeneral(Incident incident) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 6,
          child: _buildValueTile(
            incident == null ? '-' : translateIncidentType(incident?.type),
            label: "Type",
          ),
        ),
        SizedBox(width: OperationPage.SPACING),
        Expanded(
          flex: 5,
          child: StreamBuilder<int>(
              stream: Stream<int>.periodic(Duration(seconds: 1), (x) => x),
              builder: (context, snapshot) {
                return _buildValueTile(
                  "${snapshot.hasData ? formatSince(incident?.occurred) : "-"}",
                  label: "Innsats",
                );
              }),
        ),
        SizedBox(width: OperationPage.SPACING),
        Expanded(
          flex: 5,
          child: StreamBuilder<PersonnelState>(
              stream: context.bloc<PersonnelBloc>(),
              builder: (context, snapshot) {
                return _buildValueTile(
                  "${snapshot.hasData ? context.bloc<PersonnelBloc>().count() : "-"}",
                  label: "Mnsk",
                );
              }),
        ),
        SizedBox(width: OperationPage.SPACING),
        Expanded(
          flex: 5,
          child: StreamBuilder<UnitState>(
              stream: context.bloc<UnitBloc>(),
              builder: (context, snapshot) {
                return _buildValueTile(
                  "${snapshot.hasData ? context.bloc<UnitBloc>().count() : "-"}",
                  label: "Enheter",
                );
              }),
        ),
      ],
    );
  }

  Row _buildJustification(Operation operation) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile(operation.justification, label: "Begrunnelse"),
        ),
      ],
    );
  }

  Row _buildIPP(Operation operation) {
    final isEmpty = operation.ipp?.point?.isNotEmpty != true;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile(
            toUTM(operation.ipp?.point, empty: "Ikke oppgitt"),
            label: "IPP",
            subtitle: operation?.ipp?.description,
            icon: Icons.navigation,
            onIconTap: isEmpty
                ? null
                : () => navigateToLatLng(
                    context,
                    toLatLng(
                      operation?.ipp?.point,
                    )),
            onValueTap: isEmpty
                ? null
                : () => jumpToPoint(
                      context,
                      center: operation?.ipp?.point,
                      operation: operation,
                    ),
            onValueLongPress: () => copy(
              toUTM(operation?.ipp?.point, prefix: "", empty: "Ingen"),
              widget.onMessage,
              message: 'IPP kopiert til utklippstavlen',
            ),
          ),
        ),
      ],
    );
  }

  Row _buildMeetup(Operation operation) {
    final isEmpty = operation.meetup?.point?.isNotEmpty != true;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildValueTile(
            toUTM(operation?.meetup?.point, empty: "Ikke oppgitt"),
            label: "Oppmøte",
            subtitle: operation?.meetup?.description,
            icon: Icons.navigation,
            onIconTap: isEmpty
                ? null
                : () => navigateToLatLng(
                    context,
                    toLatLng(
                      operation?.meetup?.point,
                    )),
            onValueTap: isEmpty
                ? null
                : () => jumpToPoint(
                      context,
                      center: operation?.meetup?.point,
                      operation: operation,
                    ),
            onValueLongPress: () => copy(
              toUTM(operation?.meetup?.point, prefix: "", empty: "Ingen"),
              widget.onMessage,
              message: 'Oppmøte kopiert til utklippstavlen',
            ),
          ),
        ),
      ],
    );
  }

  Row _buildPasscodes(Operation operation) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: _buildValueTile("${operation.passcodes?.commander}", label: "Kode for aksjonsledelse"),
        ),
        SizedBox(width: OperationPage.SPACING),
        Expanded(
          flex: 2,
          child: _buildValueTile("${operation.passcodes?.personnel}", label: "Kode for mannskap"),
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
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label.isNotEmpty) Text(label, style: labelStyle),
        if (label != null && label.isNotEmpty) Spacer(),
        Wrap(
          children: [
            Text(value, style: valueStyle, overflow: TextOverflow.ellipsis),
            if (unit != null && unit.isNotEmpty) Text(unit, style: unitStyle, overflow: TextOverflow.ellipsis),
          ],
        ),
        if (emptyAsNull(subtitle) != null)
          Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.subtitle2.copyWith(fontSize: 14, color: Colors.grey),
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
          Expanded(child: tile),
          SizedBox(width: OperationPage.SPACING),
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
        height: OperationPage.HEIGHT * (emptyAsNull(subtitle) == null ? 1.0 : 1.25),
        padding: OperationPage.PADDING,
        child: tile,
      ),
      elevation: OperationPage.ELEVATION,
      borderRadius: BorderRadius.circular(OperationPage.CORNER),
    );
  }
}

class OperationActionGroup extends StatelessWidget {
  OperationActionGroup({
    @required this.operation,
    @required this.type,
    this.onDeleted,
    this.onMessage,
    this.onChanged,
    this.onCompleted,
  });
  final Operation operation;
  final VoidCallback onDeleted;
  final ActionGroupType type;
  final MessageCallback onMessage;
  final ValueChanged<Operation> onChanged;
  final ValueChanged<Operation> onCompleted;

  @override
  Widget build(BuildContext context) {
    return ActionGroupBuilder(
      type: type,
      builder: _buildActionItems,
    );
  }

  List<ActionMenuItem> _buildActionItems(BuildContext context) {
    return <ActionMenuItem>[
      ActionMenuItem(
        child: IgnorePointer(child: _buildEditButton(context)),
        onPressed: _onEdit,
      ),
      ActionMenuItem(
        child: IgnorePointer(child: _buildCompleteAction(context)),
        onPressed: () => _onResolved(context),
      ),
      ActionMenuItem(
        child: IgnorePointer(child: _buildCancelAction(context)),
        onPressed: () => _onCancel(context),
      ),
    ];
  }

  Widget _buildEditButton(BuildContext context) => Tooltip(
        message: "Endre aksjon",
        child: FlatButton.icon(
          icon: Icon(Icons.edit),
          label: Text(
            "ENDRE",
            textAlign: TextAlign.center,
          ),
          onPressed: _onEdit,
        ),
      );

  void _onEdit() async {
    final result = await editOperation(operation);
    if (result.isRight()) {
      final actual = result.toIterable().first;
      if (actual != operation) {
        _onMessage("${actual.name} er oppdatert");
        _onChanged(actual);
      }
      _onCompleted();
    }
  }

  Widget _buildCompleteAction(BuildContext context) {
    return FlatButton.icon(
      icon: Icon(Icons.check_circle),
      label: Text(
        "LØST",
        textAlign: TextAlign.center,
      ),
      onPressed: () => _onResolved(context),
    );
  }

  void _onResolved(BuildContext context) async {
    var finish = await prompt(
      context,
      "Bekreft løsning",
      "Dette vil stoppe alle sporinger og sette status til Løst",
    );
    if (finish) {
      _setIncidentResolution(
        context,
        OperationResolution.resolved,
      );
      Navigator.pushReplacementNamed(
        context,
        OperationsScreen.ROUTE,
      );
    }
  }

  Widget _buildCancelAction(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Kansellèr aksjon",
      child: FlatButton.icon(
        icon: Icon(
          Icons.cancel,
          color: Colors.red,
        ),
        label: Text(
          "KANSELLERT",
          textAlign: TextAlign.center,
          style: button.copyWith(color: Colors.red),
        ),
        onPressed: () => _onCancel(context),
      ),
    );
  }

  void _onCancel(BuildContext context) async {
    var cancel = await prompt(
      context,
      "Bekreft kansellering",
      "Dette vil stoppe alle sporinger og sette status til Kansellert",
    );
    if (cancel) {
      _setIncidentResolution(
        context,
        OperationResolution.cancelled,
      );
      Navigator.pushReplacementNamed(
        context,
        OperationsScreen.ROUTE,
      );
    }
  }

  void _setIncidentResolution(
    BuildContext context,
    OperationResolution resolution,
  ) async {
    var incident = context.bloc<OperationBloc>().selected.copyWith(
          resolution: resolution,
          status: OperationStatus.completed,
        );
    await context.bloc<OperationBloc>().update(incident);
    _onMessage("${incident.name} er ${enumName(resolution)}");
    _onDeleted();
    _onCompleted();
  }

  void _onMessage(String message) {
    if (onMessage != null) onMessage(message);
  }

  void _onChanged([incident]) {
    if (onChanged != null) onChanged(incident);
  }

  void _onCompleted([incident]) {
    if (onCompleted != null) onCompleted(incident ?? this.operation);
  }

  void _onDeleted() {
    if (onDeleted != null) onDeleted();
  }
}
