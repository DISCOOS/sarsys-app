import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/action_group.dart';
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
