import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pretty_json/pretty_json.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';

class StorageStatePage<T> extends StatelessWidget {
  const StorageStatePage({
    Key key,
    @required this.state,
    @required this.repository,
  }) : super(key: key);

  final StorageState<T> state;
  final StatefulRepository repository;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          ListTile(
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Version: ${state.version}'),
                Text('IsRemove: ${enumName(state.isRemote)}'),
                Text('Status: ${enumName(state.status)}'),
                if (state.hasPrevious) Divider(),
                if (state.hasPrevious) _buildValue(context, 'Difference', '${prettyJson(toDiff())}'),
                if (state.isError) Divider(),
                if (state.isError) _buildValue(context, 'Error', '${toError()}'),
                if (state.isConflict) Divider(),
                if (state.isConflict) _buildValue(context, 'Conflict', '${prettyJson(state.conflict.toJson())}'),
                Divider(),
                _buildValue(
                  context,
                  'Current',
                  '${state.value is JsonObject ? prettyJson((state.value as JsonObject).toJson()) : state.value}',
                ),
                if (state.hasPrevious) Divider(),
                if (state.hasPrevious)
                  _buildValue(
                    context,
                    'Previous',
                    '${state.previous is JsonObject ? prettyJson((state.previous as JsonObject).toJson()) : state.previous}',
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  String toError() {
    final error = state.error;
    if (error is ServiceException) {
      return prettyJson(error.toJson());
    }
    if (error is Map) {
      return prettyJson(error);
    }
    return '$error';
  }

  RichText _buildValue(BuildContext context, String label, String value) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.caption,
        text: '$label: ',
        children: [
          TextSpan(
            style: Theme.of(context).textTheme.bodyText2.copyWith(fontSize: 12),
            text: value,
          )
        ],
      ),
    );
  }

  List<Map<String, dynamic>> toDiff() {
    final value = state.value;
    if (state.hasPrevious && value is JsonObject) {
      return JsonUtils.diff(value, state.previous as JsonObject);
    }
    return [];
  }
}
