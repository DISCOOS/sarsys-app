import 'package:SarSys/core/data/services/navigation_service.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/data/services/provider.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';

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
          child: StreamBuilder(
              stream: channel.onChanged,
              builder: (context, snapshot) {
                return _buildChannelStatusTile(channel, context);
              }),
          onTap: () async {
            await _showChannelStatistics(context, channel);
            setState(() {});
          },
          onLongPress: () => _openChannel(context, channel, setState),
        ),
      ],
    );
  }

  ListTile _buildChannelStatusTile(MessageChannel channel, BuildContext context) => ListTile(
        title: Text("Websocket API"),
        subtitle: Text('${Defaults.baseWsUrl} (oppkoblet ${channel.state.opened} '
            '${channel.state.opened > 1 ? 'ganger' : 'gang'})'),
        trailing: context.service<MessageChannel>().isOpen
            ? Icon(Icons.check_circle, color: Colors.green)
            : Icon(Icons.warning, color: Colors.orange),
      );

  Future _showChannelStatistics(BuildContext context, MessageChannel channel) => showDialog(
        context: context,
        builder: (BuildContext context) {
          // return object of type Dialog
          return StatefulBuilder(builder: (context, setState) {
            final closeCodes = channel.state.toCloseReasonAsJson();
            return Scaffold(
              appBar: AppBar(
                title: Text('Statistikk'),
                leading: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: () => _openChannel(context, channel, setState),
                  )
                ],
              ),
              body: StreamBuilder<MessageChannelState>(
                  stream: channel.onChanged,
                  initialData: channel.state,
                  builder: (context, snapshot) {
                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildChannelStatusTile(channel, context),
                        ListTile(
                          title: Text("Token status"),
                          subtitle: Text(
                            'Token is ${channel.isTokenExpired ? 'expired' : 'valid'}',
                          ),
                        ),
                        ListTile(
                          title: Text('Meldinger prosessert'),
                          subtitle: Text(
                            '${channel.state.inboundCount} ${channel.state.inboundCount > 1 ? 'meldinger' : 'melding'}',
                          ),
                        ),
                        _buildSection(context, 'Årsakskoder', subtitle: closeCodes.isEmpty ? Text('Ingen') : null),
                        if (closeCodes.isNotEmpty)
                          ...closeCodes.map(
                            (json) => ListTile(
                              title: Text('${json['code']} (${json['name']})'),
                              subtitle: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...(json['reasons'] as List).map(
                                    (reason) => Text.rich(
                                      TextSpan(
                                        text: 'count',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                        children: [
                                          TextSpan(
                                            text: ': ${reason['count']}, ',
                                            style: TextStyle(fontWeight: FontWeight.normal),
                                          ),
                                          TextSpan(
                                            text: 'message',
                                          ),
                                          TextSpan(
                                            text: ': ${reason['message']}',
                                            style: TextStyle(fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
            );
          });
        },
      );

  ListTile _buildSection(BuildContext context, String title, {Widget subtitle}) {
    return ListTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.subtitle2.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: subtitle,
    );
  }

  Future _openChannel(
    BuildContext context,
    MessageChannel channel,
    StateSetter setState,
  ) async {
    final answer = await prompt(
      context,
      'Koble opp på nytt',
      'Vil du koble opp web-socket på nytt?',
    );
    if (answer) {
      channel.close();
      if (context.bloc<UserBloc>().repo.isTokenExpired) {
        try {
          await context.bloc<UserBloc>().repo.refresh();
        } on UserServiceException catch (e) {
          debugPrint('Failed to refresh token: $e');
          // Prompt user to login
          NavigationService().pushReplacementNamed(
            LoginScreen.ROUTE,
          );
        }
      }
      if (!channel.isOpen) {
        channel.open(
          url: channel.url,
          appId: context.bloc<AppConfigBloc>().config.udid,
        );
      }
      setState(() {});
    }
  }
}
