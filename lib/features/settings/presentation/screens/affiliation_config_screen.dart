// @dart=2.11

import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/presentation/widgets/affiliation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AffiliationConfigScreen extends StatefulWidget {
  const AffiliationConfigScreen({
    @required this.organisation,
    Key key,
  }) : super(key: key);
  final String organisation;

  @override
  _AffiliationConfigScreenState createState() => _AffiliationConfigScreenState();
}

class _AffiliationConfigScreenState extends State<AffiliationConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _affiliationKey = GlobalKey<AffiliationFormState>();

  String get organisation => widget.organisation ?? 'organisasjon';

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Tilhørighet"),
        automaticallyImplyLeading: true,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AffiliationForm(
              key: _affiliationKey,
              user: context.read<UserBloc>().user,
              value: _ensureAffiliation(),
              onChanged: (affiliation) => context.read<AppConfigBloc>().updateWith(
                    divId: affiliation.div.uuid,
                    depId: affiliation.dep.uuid,
                  ),
            ),
            if (context.read<UserBloc>().user.isAffiliated)
              Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      filled: true,
                      enabled: false,
                      isDense: false,
                      labelText: 'Informasjon',
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Din tilhørighet er styrt av $organisation. '
                        'Du kan derfor ikke endre denne manuelt. '
                        'Ta kontakt med $organisation hvis den er feil.',
                        style: TextStyle(color: Theme.of(context).textTheme.caption.color),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Affiliation _ensureAffiliation() => context.read<AffiliationBloc>().findUserAffiliation();
}
