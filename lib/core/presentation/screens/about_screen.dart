import 'package:SarSys/core/data/services/navigation_service.dart';
import 'package:SarSys/core/presentation/widgets/stream_widget.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
import 'package:flutter/cupertino.dart';
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
    final auuid = context.read<DeviceBloc>().app?.uuid;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListView(
        children: <Widget>[
          ListTile(
            title: Text("App-id (full)"),
            subtitle: buildCopyableText(
              isDense: true,
              context: context,
              onMessage: showMessage,
              value: auuid ?? 'Ikke funnet',
              text: auuid == null ? Text('Ikke funnet') : Text(auuid),
            ),
          ),
          ListTile(
            title: Text("App-id (kort)"),
            subtitle: buildCopyableText(
              isDense: true,
              context: context,
              onMessage: showMessage,
              value: auuid?.substring(auuid.length - 5) ?? 'Ikke funnet',
            ),
          ),
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
            child: StreamBuilderWidget(
                initialData: channel.state,
                stream: channel.onChanged,
                builder: (context, _) {
                  return _buildChannelStatusTile(channel, context);
                }),
            onTap: () async {
              await _showChannelStatistics(context, channel);
              setState(() {});
            },
            onLongPress: () => _openChannel(context, channel, setState),
          ),
        ],
      ),
    );
  }

  void showMessage(
    String message, {
    String action = "OK",
    VoidCallback onPressed,
    dynamic data,
  }) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: SnackBarAction(
          label: action,
          onPressed: () {
            if (onPressed != null) onPressed();
            ScaffoldMessenger.of(context)..hideCurrentSnackBar(reason: SnackBarClosedReason.action);
          }),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackbar);
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
              body: StreamBuilderWidget<MessageChannelState>(
                  stream: channel.onChanged,
                  initialData: channel.state,
                  builder: (context, _) {
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
      if (context.read<UserBloc>().repo.isTokenExpired) {
        try {
          await context.read<UserBloc>().repo.refresh();
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
          appId: context.read<AppConfigBloc>().config.udid,
        );
      }
      setState(() {});
    }
  }
}
