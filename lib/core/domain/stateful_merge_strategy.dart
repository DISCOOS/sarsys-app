import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/utils/data.dart';

import 'models/core.dart';

class StatefulMergeStrategy<K, V extends JsonObject, S extends StatefulServiceDelegate<V, V>> {
  StatefulMergeStrategy(this.repository);
  final StatefulRepository<K, V, S> repository;

  Future<StorageState<V>> call(
    StorageState<V> state,
    ConflictModel conflict,
  ) =>
      reconcile(state, conflict);

  Future<StorageState<V>> reconcile(
    StorageState<V> state,
    ConflictModel conflict,
  ) async {
    switch (conflict.type) {
      case ConflictType.exists:
        return onExists(conflict, state);
      case ConflictType.merge:
        return onMerge(conflict, state);
      case ConflictType.deleted:
        return onDeleted(conflict, state);
    }
    throw UnimplementedError(
      "Reconciling conflict type '${enumName(conflict.type)}' not implemented",
    );
  }

  /// Default is last writer wins by forwarding to [repository.onUpdate]
  Future<StorageState<V>> onExists(ConflictModel conflict, StorageState<V> state) => repository.onUpdate(state);

  /// Default is to replace local value with remote value
  Future<StorageState<V>> onMerge(ConflictModel conflict, StorageState<V> state) {
    return Future.value(repository.replace(
      repository.fromJson(
        JsonUtils.apply(
          repository.fromJson(conflict.base),
          conflict.yours,
        ),
      ),
      isRemote: true,
    ));
  }

  /// Delete conflicts are not
  /// handled as conflicts, returns
  /// current state value
  Future<StorageState<V>> onDeleted(ConflictModel conflict, StorageState<V> state) => Future.value(state);
}
