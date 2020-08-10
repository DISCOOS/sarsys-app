import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/data/services/provider.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AboutScreen extends StatefulWidget {
  @override
  _AboutScreenState createState() => _AboutScreenState();
}

/// Screen state which records route to PageStorage
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
        title: Text("Om SARSys App"),
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ));
  }

  _buildPacketInfo(BuildContext context, PackageInfo data) {
    final channel = context.service<MessageChannel>();
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
        GestureDetector(
          child: ListTile(
            title: Text("Websocket API"),
            subtitle: Text('${Defaults.baseWsUrl} (oppkoblet ${channel.stats.connected} '
                '${channel.stats.connected > 1 ? 'ganger' : 'gang'})'),
            trailing: context.service<MessageChannel>().isOpen
                ? Icon(Icons.check_circle, color: Colors.green)
                : Icon(Icons.warning, color: Colors.orange),
          ),
          onLongPress: () async {
            final answer = await prompt(
              context,
              'Koble opp på nytt',
              'Vil du koble opp web-socket på nytt?',
            );
            if (answer) {
              channel.close();
              channel.open(
                url: channel.url,
                token: context.bloc<UserBloc>().repo.token,
              );
              setState(() {});
            }
          },
        ),
      ],
    );
  }
}
