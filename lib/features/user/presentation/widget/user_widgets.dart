import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:SarSys/core/data/services/location/location_service.dart';
import 'package:SarSys/core/domain/models/Position.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/domain/models/Point.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/widgets/action_group.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/settings/presentation/screens/location_config_screen.dart';
import 'package:SarSys/features/affiliation/presentation/widgets/affiliation.dart';

class UserWidget extends StatelessWidget {
  final bool withName;
  final bool withHeader;
  final bool withActions;
  final User user;
  final VoidCallback onDeleted;
  final Organisation organisation;
  final MessageCallback onMessage;
  final ValueChanged<Point> onGoto;
  final ValueChanged<User> onChanged;
  final ValueChanged<User> onCompleted;

  const UserWidget({
    Key key,
    @required this.user,
    @required this.onMessage,
    this.onGoto,
    this.onDeleted,
    this.onChanged,
    this.onCompleted,
    this.withName = false,
    this.withHeader = true,
    this.withActions = true,
    this.organisation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Orientation orientation = MediaQuery.of(context).orientation;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (withHeader) _buildHeader(context, user, theme),
        if (withHeader) Divider() else SizedBox(height: 8.0),
        if (Orientation.portrait == orientation) _buildPortrait(context) else _buildLandscape(context),
        if (withActions) ...[
          Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text("Handlinger", textAlign: TextAlign.left, style: theme.caption),
          ),
          UserActionGroup(
            user: user,
            type: ActionGroupType.buttonBar,
            onDeleted: onDeleted,
            onChanged: onChanged,
            onMessage: onMessage,
            onCompleted: onCompleted,
          ),
        ] else
          SizedBox(height: 16.0)
      ],
    );
  }

  Widget _buildPortrait(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameView(),
            _buildContactView(),
            _buildAffiliationView(context),
          ],
        ),
      );

  Widget _buildLandscape(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildNameView(),
                  _buildContactView(),
                ],
              ),
            ),
            _buildDivider(Orientation.landscape),
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildAffiliationView(context),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDivider(Orientation orientation) => Orientation.portrait == orientation
      ? Divider(indent: 16.0, endIndent: 16.0)
      : VerticalDivider(indent: 16.0, endIndent: 16.0);

  Padding _buildHeader(BuildContext context, User user, TextTheme theme) {
    return Padding(
      padding: EdgeInsets.only(left: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('${user.fullName}', style: theme.headline6),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => _onComplete(user),
          )
        ],
      ),
    );
  }

  Widget _buildNameView() => UserNameView(
        user: user,
        onMessage: onMessage,
        onComplete: () => _onComplete(user),
      );

  Widget _buildContactView() => UserContactView(
        user: user,
        onMessage: onMessage,
        onComplete: () => _onComplete(user),
      );

  Widget _buildAffiliationView(BuildContext context) {
    final affiliation = context.bloc<AffiliationBloc>().findUserAffiliation();
    return AffiliationView(
      onMessage: onMessage,
      affiliation: affiliation,
      onComplete: () => _onComplete(user),
    );
  }

  void _onComplete([user]) {
    if (onCompleted != null) onCompleted(user ?? this.user);
  }
}

class UserActionGroup extends StatelessWidget {
  UserActionGroup({
    @required this.user,
    @required this.type,
    this.onDeleted,
    this.onMessage,
    this.onChanged,
    this.onCompleted,
  });
  final User user;
  final ActionGroupType type;
  final VoidCallback onDeleted;
  final MessageCallback onMessage;
  final ValueChanged<User> onChanged;
  final ValueChanged<User> onCompleted;

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
        child: IgnorePointer(child: _buildDeleteButton(context)),
        onPressed: _onEdit,
      ),
    ];
  }

  Widget _buildEditButton(BuildContext context) => Tooltip(
        message: "Endre bruker",
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
//    final result = await editUser(user);
//    if (result.isRight()) {
//      final actual = result.toIterable().first;
//      if (actual != user) {
//        _onMessage("${actual.name} er oppdatert");
//        _onChanged(actual);
//      }
//      _onCompleted();
//    }
  }

  Widget _buildDeleteButton(BuildContext context) {
    final button = Theme.of(context).textTheme.button;
    return Tooltip(
      message: "Slett bruker",
      child: FlatButton.icon(
        icon: Icon(
          Icons.delete,
          color: Colors.red,
        ),
        label: Text(
          'SLETT',
          textAlign: TextAlign.center,
          style: button.copyWith(color: Colors.red),
        ),
        onPressed: _onDelete,
      ),
    );
  }

  void _onDelete() async {
//    final result = await deleteUser(user);
//    if (result.isRight()) {
//      _onMessage("${user.fullName} er slettet");
//      _onDeleted();
//      _onCompleted();
//    }
  }

//  void _onMessage(String message) {
//    if (onMessage != null) onMessage(message);
//  }
//
//  void _onChanged([user]) {
//    if (onChanged != null) onChanged(user);
//  }
//
//  void _onCompleted([user]) {
//    if (onCompleted != null) onCompleted(user ?? this.user);
//  }
//
//  void _onDeleted() {
//    if (onDeleted != null) onDeleted();
//  }
}

class UserLocationWidget extends StatefulWidget {
  const UserLocationWidget({Key key, this.onMessage}) : super(key: key);
  final ActionCallback onMessage;

  @override
  _UserLocationWidgetState createState() => _UserLocationWidgetState();
}

class _UserLocationWidgetState extends State<UserLocationWidget> {
  var state = 0;
  final isSelected = <bool>[false, false, false];

  @override
  void didChangeDependencies() {
    final config = context.bloc<AppConfigBloc>().config;
    if (config.locationStoreLocally == false) {
      state = 0;
    } else if (config.locationAllowSharing == false) {
      state = 1;
    } else {
      state = 2;
    }
    isSelected[state] = true;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final service = LocationService();
    return ConstrainedBox(
      constraints: BoxConstraints.loose(Size.fromRadius(175)),
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: _buildStatus(service),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: _buildDeleteButton(context, service),
            ),
            Align(
              alignment: Alignment.topRight,
              child: _buildRefreshButton(service),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: _buildSettingsButton(context, service),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _buildSyncButton(service),
            ),
          ],
        ),
      ),
    );
  }

  IconButton _buildRefreshButton(LocationService service) {
    return IconButton(
      icon: Icon(
        Icons.refresh,
        color: Colors.green,
      ),
      tooltip: 'Oppdater posisjon',
      onPressed: () => service.update(),
    );
  }

  IconButton _buildSettingsButton(BuildContext context, LocationService service) {
    return IconButton(
      icon: Icon(
        Icons.settings,
      ),
      tooltip: 'Endre innstillinger',
      onPressed: () => showDialog(
        context: context,
        builder: (context) => LocationConfigScreen(),
      ),
    );
  }

  IconButton _buildSyncButton(LocationService service) {
    return IconButton(
      icon: Icon(
        Icons.publish,
        color: Colors.green,
      ),
      tooltip: 'Del posisjoner nå',
      onPressed: () => service.push(),
    );
  }

  IconButton _buildDeleteButton(BuildContext context, LocationService service) {
    return IconButton(
      icon: Icon(
        Icons.delete,
        color: Colors.red,
      ),
      tooltip: 'Slett bufrede posisjoner',
      onPressed: () async {
        if (await prompt(
          context,
          "Bekreftelse",
          "Dette vil slette bufrede posisjoner. Vil du fortsette?",
        )) {
          service.clear();
        }
      },
    );
  }

  Widget _buildStatus(LocationService service) => StreamBuilder<LocationEvent>(
        stream: service.onChanged,
        builder: (context, snapshot) {
          final point = service.current?.geometry;
          return FutureBuilder<Iterable<Position>>(
              future: service.backlog(),
              builder: (context, history) {
                final positions = history.hasData ? history.data as Iterable : [];
                final capacity = positions.length / 1000;
                return CircularPercentIndicator(
                  radius: 272.0,
                  lineWidth: 15.0,
                  percent: capacity,
                  header: Text(
                    'SPORING',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  footer: Text(
                    'Posisjoner bufret: ${positions.length} av 1000 (${(capacity * 100).toStringAsFixed(1)} %)',
                  ),
                  center: Padding(
                    padding: const EdgeInsets.only(top: 48.0, bottom: 52.0, left: 24.0, right: 24.0),
                    child: Stack(
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: <Widget>[
                              buildCopyableText(
                                label: "UTM",
                                isDense: true,
                                context: context,
                                prefixWidth: 0.0,
                                value: toUTM(point, prefix: "", empty: "Ingen"),
                                onCopy: (value) => copy(
                                  value,
                                  widget.onMessage,
                                  message: 'UTM kopiert til utklippstavlen',
                                ),
                                onTap: () => jumpToPoint(context, center: point),
                              ),
                              buildCopyableText(
                                label: "Desimalminutter (DDM)",
                                isDense: true,
                                context: context,
                                prefixWidth: 0.0,
                                contentPadding: EdgeInsets.zero,
                                value: toDDM(point, prefix: "", empty: "Ingen"),
                                onCopy: (value) => copy(
                                  value,
                                  widget.onMessage,
                                  message: 'DDM kopiert til utklippstavlen',
                                ),
                                onTap: () => jumpToPoint(context, center: point),
                              ),
                              Divider(
                                thickness: 2,
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              ToggleButtons(
                                renderBorder: false,
                                children: <Widget>[
                                  Icon(
                                    Icons.visibility_off,
                                    color: Colors.red,
                                  ),
                                  Icon(
                                    Icons.storage,
                                    color: Colors.orange,
                                  ),
                                  Icon(
                                    Icons.cloud_upload,
                                    color: Colors.green,
                                  ),
                                ],
                                onPressed: (int index) {
                                  setState(() {
                                    for (int buttonIndex = 0; buttonIndex < isSelected.length; buttonIndex++) {
                                      if (buttonIndex == index) {
                                        state = index;
                                        isSelected[buttonIndex] = true;
                                        _apply(context, service, state);
                                      } else {
                                        isSelected[buttonIndex] = false;
                                      }
                                    }
                                  });
                                },
                                isSelected: isSelected,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _toTrackingStatus(state),
                                  style: Theme.of(context).textTheme.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  progressColor: _toTrackingColor(state),
                );
              });
        },
      );

  MaterialColor _toTrackingColor(int index) {
    switch (index) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  String _toTrackingStatus(int index) {
    switch (index) {
      case 1:
        return 'BUFRES LOKALT';
      case 2:
        return 'LAGRES I AKSJON';
      default:
        return 'INGEN BUFRING';
    }
  }

  Future _apply(
    BuildContext context,
    LocationService service,
    int index,
  ) async {
    switch (index) {
      case 0:
        await context.bloc<AppConfigBloc>().updateWith(
              locationStoreLocally: false,
              locationAllowSharing: false,
            );
        break;
      case 1:
        await context.bloc<AppConfigBloc>().updateWith(
              locationStoreLocally: true,
              locationAllowSharing: false,
            );
        break;
      case 2:
        await context.bloc<AppConfigBloc>().updateWith(
              locationStoreLocally: true,
              locationAllowSharing: true,
            );
        break;
    }
    return service.configure();
  }
}

class UserNameView extends StatelessWidget {
  const UserNameView({
    Key key,
    this.user,
    this.onMessage,
    this.onComplete,
  }) : super(key: key);

  final User user;
  final VoidCallback onComplete;
  final MessageCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Fornavn",
            icon: Icon(Icons.person),
            value: user.fname,
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Etternavn",
            icon: Icon(Icons.person_outline),
            value: user.lname,
            onMessage: onMessage,
            onComplete: onComplete,
          ),
        ),
      ],
    );
  }
}

class UserContactView extends StatelessWidget {
  const UserContactView({
    Key key,
    this.user,
    this.onMessage,
    this.onComplete,
  }) : super(key: key);

  final User user;
  final VoidCallback onComplete;
  final MessageCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: buildCopyableText(
            context: context,
            label: "Mobil",
            icon: Icon(Icons.phone),
            value: user.phone ?? "Ukjent",
            onMessage: onMessage,
            onComplete: onComplete,
            onTap: () {
              final number = user.phone ?? '';
              if (number.isNotEmpty) launch("tel:$number");
            },
          ),
        ),
      ],
    );
  }
}
