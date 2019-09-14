import 'package:SarSys/core/defaults.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';

class AboutScreen extends StatefulWidget {
  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: _buildAppBar(context),
      body: FutureBuilder(
        future: PackageInfo.fromPlatform(),
        builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
          return snapshot.hasData ? _buildPacketInfo(context, snapshot.data) : Container();
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
        title: Text("Om SarSys"),
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ));
  }

  _buildPacketInfo(BuildContext context, PackageInfo data) {
    return ListView(
      children: <Widget>[
        ListTile(
          title: Text("Navn"),
          subtitle: Text(data.appName),
        ),
        ListTile(
          title: Text("Versjon"),
          subtitle: Text(data.version),
        ),
        ListTile(
          title: Text("Pakkenavn"),
          subtitle: Text(data.packageName),
        ),
        ListTile(
          title: Text("Byggnummer"),
          subtitle: Text(data.buildNumber),
        ),
        ListTile(
          title: Text("REST API"),
          subtitle: Text(Defaults.baseRestUrl),
        ),
        ListTile(
          title: Text("Websocket API"),
          subtitle: Text(Defaults.baseWsUrl),
        ),
      ],
    );
  }
}
