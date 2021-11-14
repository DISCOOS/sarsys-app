import 'package:SarSys/features/user/presentation/screens/change_pin_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class SecurityConfigScreen extends StatefulWidget {
  @override
  _SecurityConfigScreenState createState() => _SecurityConfigScreenState();
}

class _SecurityConfigScreenState extends State<SecurityConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Sikkerhetsoppsett"),
        automaticallyImplyLeading: true,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.phonelink_lock),
              title: Text('Endre pin', style: TextStyle(fontSize: 14)),
              onTap: () async {
                Navigator.popAndPushNamed(
                  context,
                  ChangePinScreen.ROUTE,
                  arguments: {'popOnClose': true},
                );
              },
            ),
            Divider(),
            _buildSecurityModeField(),
            SizedBox(
              height: 16,
            ),
            _buildSecurityTypeField(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(
            "Lokal sikkerhet",
          ),
          subtitle: Text(
            "Data er sikret med pin-kode som må oppgis når appen "
            "ikke har vært i bruk på en stund. I delt modus må hver "
            "bruker oppgi sin egen pinkode.",
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Chip(
            label: Text(translateSecurityType(context.read<AppConfigBloc>().config!.securityType)),
          ),
        )
      ],
    );
  }

  Widget _buildSecurityModeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(
            "Sikkerhetsmodus",
          ),
          subtitle: Text(
            "I privat modus så kan kun èn person logge inn. "
            "I delt modus kan flere personer logge inn, typisk på nettbrett som deles mellom flere brukere. "
            "Av sikkerhetsgrunner kan denne innstillingen ikke endres uten å avinstallere appen.",
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Chip(
            label: Text(
              translateSecurityMode(context.read<AppConfigBloc>().config!.securityMode),
            ),
          ),
        )
      ],
    );
  }
}
