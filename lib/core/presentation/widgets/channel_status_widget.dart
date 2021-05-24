import 'package:flutter/material.dart';

import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/presentation/widgets/stream_widget.dart';
import 'package:SarSys/core/data/services/provider.dart';

class MessageChannelStatusWidget extends StatelessWidget {
  const MessageChannelStatusWidget(this.channel, {Key key}) : super(key: key);

  final MessageChannel channel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilderWidget<MessageChannelState>(
        stream: channel.onChanged,
        initialData: channel.state,
        builder: (context, _) {
          final closeCodes = channel.state.toCloseReasonAsJson();
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
        });
  }

  ListTile _buildChannelStatusTile(MessageChannel channel, BuildContext context) => ListTile(
        title: Text("Websocket API"),
        subtitle: Text('${Defaults.baseWsUrl} (oppkoblet ${channel.state.opened} '
            '${channel.state.opened > 1 ? 'ganger' : 'gang'})'),
        trailing: context.service<MessageChannel>().isOpen
            ? Icon(Icons.check_circle, color: Colors.green)
            : Icon(Icons.warning, color: Colors.orange),
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
}
