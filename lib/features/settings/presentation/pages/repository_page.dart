import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/settings/presentation/pages/storage_state_page.dart';
import 'package:flutter/material.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/utils/data.dart';

class RepositoryPage<T extends Aggregate> extends StatefulWidget {
  final bool withActions;
  final StatefulRepository repository;
  final bool Function(StorageState<T> state) where;
  final String Function(StorageState<T> state) subject;
  final String Function(StorageState<T> state) content;

  RepositoryPage({
    Key key,
    this.where,
    this.subject,
    this.content,
    this.repository,
    this.withActions = true,
  }) : super(key: key);

  @override
  RepositoryPageState<T> createState() => RepositoryPageState<T>();
}

class RepositoryPageState<T extends Aggregate> extends State<RepositoryPage<T>> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.repository.onChanged,
        initialData: widget.repository.values,
        builder: (context, snapshot) {
          if (snapshot.hasData == false) return Container();
          var states = _filtered();
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: states.length,
            itemBuilder: (context, index) {
              return _buildTile(context, states[index]);
            },
          );
        });
  }

  List<StorageState<T>> _filtered() => widget.repository.states.values
      .where((state) => widget.where?.call(state) ?? true)
      .toList()
      .cast<StorageState<T>>();

  Widget _buildTile(BuildContext context, StorageState<T> state) {
    final key = widget.repository.toKey(state.value);
    return ListTile(
      title: SelectableText(widget.subject(state)),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            'Key $key',
            onTap: () => onTap(context, state, key),
          ),
          if (widget.content != null)
            SelectableText(
              '${widget.content(state)}',
              onTap: () => onTap(context, state, key),
            ),
          SelectableText(
            'Status ${enumName(state.status)}, '
            'last change was ${state.isLocal ? 'local' : 'remote'},',
            onTap: () => onTap(context, state, key),
          ),
          SelectableText('Version ${state.version}'),
          if (state.isError)
            SelectableText(
              'Last error: ${toErrorString(state)}',
              onTap: () => onTap(context, state, key),
            ),
        ],
      ),
      onTap: () => onTap(context, state, key),
    );
  }

  String toErrorString(StorageState state) {
    final error = state.error;
    if (error is ServiceException) {
      return '${error.response.statusCode} ${error.response.error}';
    }
    return '${state.error.toString().substring(0, 100)}...';
  }

  Future onTap(BuildContext context, StorageState<T> state, String key) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text("${typeOf<T>()} ...${key.substring(key.length - 7)}"),
          ),
          body: StorageStatePage<T>(
            state: state,
            repository: widget.repository,
          ),
        ),
      ),
    );
  }
}
