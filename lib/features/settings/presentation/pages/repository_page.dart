import 'package:SarSys/core/repository.dart';
import 'package:SarSys/models/core.dart';
import 'package:flutter/material.dart';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/utils/data_utils.dart';

class RepositoryPage<T extends Aggregate> extends StatefulWidget {
  final bool withActions;
  final ConnectionAwareRepository repository;
  final bool Function(StorageState<T> state) where;
  final String Function(StorageState<T> state) subtitle;

  RepositoryPage({
    Key key,
    this.where,
    this.subtitle,
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
            itemExtent: 72.0,
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
    final key = widget.repository.toKey(state);
    return ListTile(
      title: Text(widget.subtitle(state)),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Key $key'),
          Text('Status ${enumName(state.status)}, '
              'last change was ${state.isLocal ? 'local' : 'remote'},'),
          if (state.isError) Text('Last error: ${state.error}'),
        ],
      ),
    );
  }
}
