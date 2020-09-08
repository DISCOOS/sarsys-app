import 'dart:math';

import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
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

class LocationBufferWidget extends StatefulWidget {
  const LocationBufferWidget({Key key, this.onMessage}) : super(key: key);
  final ActionCallback onMessage;

  @override
  _LocationBufferWidgetState createState() => _LocationBufferWidgetState();
}

class _LocationBufferWidgetState extends State<LocationBufferWidget> {
  var state = 0;
  LocationOptions get options => LocationService().options;
  bool get locationAllowSharing => options.locationAllowSharing;
  bool get isLocationStoreLocally => options.locationStoreLocally;

  Future<SharedPreferences> get future => _prefs ??= SharedPreferences.getInstance();
  Future<SharedPreferences> _prefs;

  @override
  Widget build(BuildContext context) {
    final service = LocationService();
    SizeConfig.init(context);
    final size = SizeConfig.screenMin - 60;
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: size),
      child: FutureBuilder<SharedPreferences>(
          future: future,
          builder: (context, snapshot) {
            final manual = snapshot.hasData
                // Read from shared preferences
                ? (snapshot.data.getBool(LocationService.pref_location_manual) ?? false)
                : false;

            return Column(
              children: <Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints.tightFor(width: size, height: size - 36),
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
                Divider(),
                SwitchListTile(
                  value: locationAllowSharing,
                  secondary: Icon(Icons.cloud_upload),
                  title: Text('Del'),
                  subtitle: Text('Kan bli lagret i aksjonen'),
                  onChanged: manual
                      ? (value) {
                          context.bloc<AppConfigBloc>().updateWith(
                                locationAllowSharing: value,
                              );
                          setState(() {});
                        }
                      : null,
                ),
                SwitchListTile(
                  value: isLocationStoreLocally,
                  secondary: Icon(Icons.storage),
                  title: Text('Bufre'),
                  subtitle: Text('Lagres lokalt når du er uten nett'),
                  onChanged: manual
                      ? (value) {
                          context.bloc<AppConfigBloc>().updateWith(
                                locationStoreLocally: value,
                              );
                          setState(() {});
                        }
                      : null,
                ),
              ],
            );
          }),
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
      onPressed: () async {
        await showDialog(
          context: context,
          builder: (context) => LocationConfigScreen(),
        );
        setState(() {});
      },
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
          return FutureBuilder<Iterable<Position>>(
              future: service.backlog(),
              builder: (context, history) {
                final positions = history.hasData ? history.data as Iterable : [];
                final usage = positions.length / 1000;
                return CircularPercentIndicator(
                  radius: SizeConfig.screenMin * 0.70,
                  lineWidth: 20.0,
                  percent: usage,
                  center: FractionallySizedBox(
                    widthFactor: 0.7,
                    heightFactor: 0.5,
                    child: Stack(
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: <Widget>[
                              _buildValue(context, positions.length, 'punkter'),
                              Divider(
                                thickness: 2,
                              ),
                              _buildValue(context, service.odometer?.toInt(), 'meter'),
                              Spacer(),
                              Text(
                                service.isStoring ? '${positions.length} av 1000 bufret' : 'Bufrer ikke',
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  service.isSharing ? 'Posisjoner deles' : 'Posisjoner deles ikke',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _toTrackingColor(service, usage),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  progressColor: _toTrackingColor(service, usage),
                );
              });
        },
      );

  Text _buildValue(BuildContext context, Object value, String unit) => Text.rich(TextSpan(
        text: '$value',
        style: Theme.of(context).textTheme.headline4,
        children: [
          TextSpan(
            text: ' $unit',
            style: Theme.of(context).textTheme.caption,
          ),
        ],
      ));

  MaterialColor _toTrackingColor(LocationService service, double capacity) {
    if (!service.isSharing) {
      return Colors.red;
    }
    if (capacity < 0.5) {
      return Colors.green;
    } else if (capacity > 0.90) {
      return Colors.red;
    }
    return Colors.orange;
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
