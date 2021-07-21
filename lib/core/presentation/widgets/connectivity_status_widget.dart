// @dart=2.11

import 'package:SarSys/core/data/services/connectivity_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/material.dart';

import 'package:SarSys/core/presentation/widgets/stream_widget.dart';
import 'package:SarSys/core/data/services/provider.dart';

class ConnectivityStatusWidget extends StatelessWidget {
  const ConnectivityStatusWidget(this.service, {Key key}) : super(key: key);

  final ConnectivityService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilderWidget<ConnectivityStatus>(
        stream: service.changes,
        initialData: service.status,
        builder: (context, _) {
          final toc = DateTime.now();
          return Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStateTile(context),
              ListTile(
                title: Text("Kvalitet"),
                subtitle: Text('${translateConnectivityQuality(service.quality)}'),
              ),
              ListTile(
                title: Text("Forbruk"),
                subtitle: Text('${service.speed.toString()}'),
              ),
              _buildSection(
                context,
                'Tidsutløp',
                subtitle: service.timeouts.isEmpty ? Text('Ingen') : null,
              ),
              if (service.timeouts.isNotEmpty)
                ...service.timeouts.values.map(
                  (result) => ListTile(
                    title: Text('${result.error.runtimeType}'),
                    subtitle: Text(
                      'Totalt ${result.count} ${formatSince(result.timestamp, now: toc)} siden',
                    ),
                  ),
                ),
            ],
          );
        });
  }

  ListTile _buildStateTile(BuildContext context) {
    final state = service.state;
    return ListTile(
      title: Text("Tilkobling"),
      subtitle: Text('${translateConnectivityStatus(state.status)} med '
          '${translateConnectivityQuality(state.quality).toLowerCase()} kvalitet (forbruk ${state.speed})'),
      trailing: context.service<ConnectivityService>().isOnline
          ? Icon(Icons.check_circle, color: Colors.green)
          : Icon(Icons.warning, color: Colors.orange),
    );
  }

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
