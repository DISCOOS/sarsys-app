

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/data/services/navigation_service.dart';
import 'package:SarSys/core/presentation/widgets/stream_widget.dart';
import 'package:SarSys/core/presentation/widgets/channel_status_widget.dart';
import 'package:SarSys/core/presentation/widgets/connectivity_status_widget.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
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
          return snapshot.hasData ? _buildPacketInfo(context, snapshot.data!) : Container();
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
    final String auuid = context.read<DeviceBloc>().app!.uuid;
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
              value: auuid.substring(auuid.length - 5) ?? 'Ikke funnet',
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
            child: _buildConnectivityStateTile(context),
            onTap: () async {
              await _showConnectivityStatistics(context);
              setState(() {});
            },
          ),
          GestureDetector(
            child: StreamBuilderWidget(
                stream: channel.onChanged,
                initialData: channel.state,
                builder: (context, dynamic _) {
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
    VoidCallback? onPressed,
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

  ListTile _buildConnectivityStateTile(BuildContext context) {
    final state = ConnectivityService().state;
    return ListTile(
      title: Text("Tilkobling"),
      subtitle: Text('${translateConnectivityStatus(state.status)} med '
          '${translateConnectivityQuality(state.quality).toLowerCase()} kvalitet (forbruk ${state.speed})'),
      trailing: context.service<ConnectivityService>().isOnline
          ? Icon(Icons.check_circle, color: Colors.green)
          : Icon(Icons.warning, color: Colors.orange),
    );
  }

  Future _showConnectivityStatistics(BuildContext context) => showDialog(
        context: context,
        builder: (BuildContext context) {
          // return object of type Dialog
          return StatefulBuilder(builder: (context, setState) {
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
                    onPressed: () => setState(() {}),
                  )
                ],
              ),
              body: ConnectivityStatusWidget(
                ConnectivityService(),
              ),
            );
          });
        },
      );

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
              body: MessageChannelStatusWidget(
                channel,
              ),
            );
          });
        },
      );

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
          url: channel.url!,
          appId: context.read<AppConfigBloc>().config.udid,
        );
      }
      setState(() {});
    }
  }
}
