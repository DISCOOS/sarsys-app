import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Affiliation.dart';
import 'package:SarSys/widgets/affilliation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AffiliationConfigScreen extends StatefulWidget {
  @override
  _AffiliationConfigScreenState createState() => _AffiliationConfigScreenState();
}

class _AffiliationConfigScreenState extends State<AffiliationConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _affiliationKey = GlobalKey<AffiliationFormState>();

  UserBloc _userBloc;
  AppConfigBloc _configBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _configBloc = BlocProvider.of<AppConfigBloc>(context);
  }

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Tihørighet"),
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
              user: _userBloc.user,
              initialValue: _ensureAffiliation(),
              onChanged: (affiliation) => _configBloc.update(
                division: affiliation.divId,
                department: affiliation.depId,
              ),
            ),
            if (_userBloc.user.isAffiliated)
              Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      hasFloatingPlaceholder: true,
                      filled: true,
                      enabled: false,
                      isDense: false,
                      labelText: 'Informasjon',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Din tilhørighet er styrt av organisasjonen. '
                        'Du kan derfor ikke endre denne manuelt. '
                        'Ta kontakt med din organisasjon hvis den er feil.',
                        style: TextStyle(color: Theme.of(context).textTheme.caption.color),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Affiliation _ensureAffiliation() => Affiliation(
        orgId: Defaults.orgId,
        divId: _configBloc.config.divId ?? Defaults.divId,
        depId: _configBloc.config.depId ?? Defaults.depId,
      );
}
