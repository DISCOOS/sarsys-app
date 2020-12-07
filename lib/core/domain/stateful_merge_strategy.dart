import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/utils/data.dart';

import 'models/core.dart';

class StatefulMergeStrategy<S, T extends JsonObject, U extends Service> {
  StatefulMergeStrategy(this.repository);
  final StatefulRepository<S, T, U> repository;

  Future<StorageState<T>> call(
    StorageState<T> state,
    ConflictModel conflict,
  ) =>
      reconcile(state, conflict);

  Future<StorageState<T>> reconcile(
    StorageState<T> state,
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
  Future<StorageState<T>> onExists(ConflictModel conflict, StorageState<T> state) async {
    return StorageState.updated(
      await repository.onUpdate(state),
      isRemote: true,
    );
  }

  /// Default is to replace local value with remote value
  Future<StorageState<T>> onMerge(ConflictModel conflict, StorageState<T> state) {
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
  Future<StorageState<T>> onDeleted(ConflictModel conflict, StorageState<T> state) => Future.value(state);
}
