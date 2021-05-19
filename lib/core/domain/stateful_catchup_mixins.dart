import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/foundation.dart';
import 'package:json_patch/json_patch.dart';

import 'models/core.dart';

mixin StatefulCatchup<V extends JsonObject, S extends StatefulServiceDelegate<V, V>>
    on StatefulRepository<String, V, S> {
  /// Catchup with state in messages
  void catchupTo<T extends MessageModel>(Stream<T> messages) {
    registerStreamSubscription(messages.listen(
      _handle,
    ));
  }

  void _handle(MessageModel message) {
    if (isReady) {
      StorageState<V> state;
      try {
        // Merge with local state?
        if (containsKey(message.uuid)) {
          final current = getState(
            message.uuid,
          );

          // A-priori message?
          if (message.isApriori) {
            state = _onApriori(message, current);
          }

          // Skip retrospective events
          else if (message.version >= current.version) {
            if (current.isRemote) {
              if (message.version == current.version + 1) {
                // Trivial >> Just update local with remote state
                state = _onRemoteNextWhenUnmodified(
                  message,
                  current,
                );
              } else if (message.version > current.version + 1) {
                // Warning >> Only update if message contains state
                state = _onRemoteBeyondWhenUnmodified(
                  message,
                  current,
                );
              }
            } else {
              if (message.version == current.version + 1) {
                // Danger >> Remote state should be equal to local
                state = _onRemoteNextWhenModified(
                  message,
                  current,
                );
              } else if (message.version > current.version + 1) {
                // Danger >> Remote state has progress beyond local
                state = _onRemoteBeyondWhenModified(
                  message,
                  current,
                );
              }
            }
          } else {
            // Trivial >> Just add remote state locally
            state = _onRemoteCreate(
              message,
              state,
            );
          }
          if (state != null) {
            put(state);
          }
        }
      } on Exception catch (error, stackTrace) {
        if (state != null) {
          put(state.failed(error));
        }
        onError(error, stackTrace);
      }
    }
  }

  /// Get next state from state directly or by patching changed to previous
  V _toNextState(MessageModel message, StorageState<V> previous) => fromJson(message.isState
      ? message.state
      : JsonUtils.apply(
          previous.value,
          message.patches,
          strict: false,
        ));

  /// Replace state with a-priori data
  StorageState<V> _onApriori(MessageModel message, StorageState<V> current) => current.replace(
        _toNextState(message, current),
      );

  /// Created new state not seen before
  StorageState<V> _onRemoteCreate(MessageModel message, StorageState<V> state) {
    final next = fromJson(
      message.isState
          ? message.state
          : JsonPatch.apply(
              {},
              message.patches,
              strict: false,
            ),
    );
    return StorageState.created(
      next,
      message.version,
      isRemote: true,
    );
  }

  StorageState<V> _onRemoteNextWhenUnmodified(
    MessageModel message,
    StorageState<V> current,
  ) {
    return StorageState.updated(
      _toNextState(
        message,
        current,
      ),
      message.version,
      isRemote: true,
    );
  }

  StorageState<V> _onRemoteBeyondWhenUnmodified(
    MessageModel message,
    StorageState<V> current,
  ) {
    if (message.isState) {
      return StorageState.updated(
        fromJson(message.state),
        message.version,
        isRemote: true,
      );
    }
    // No state to replace directly - skip message
    // TODO: Force catchup from local version
    return current;
  }

  StorageState<V> _onRemoteNextWhenModified(
    MessageModel message,
    StorageState<V> current,
  ) {
    // Use Last-Writer-Wins strategy >> local changes are overwritten on concurrent modification
    final next = _toNextState(
      message,
      current,
    );

    // Check merge resolution
    final residue = _check(
      message,
      current,
      next,
    );

    return current.replace(
      next,
      version: message.version,
      isRemote: residue.isEmpty,
    );
  }

  StorageState<V> _onRemoteBeyondWhenModified(
    MessageModel message,
    StorageState<V> current,
  ) {
    if (message.isState) {
      // With state we can do a forward merge
      return _onRemoteNextWhenModified(
        message,
        current,
      );
    }
    // No state to replace directly - skip message
    // TODO: Force catchup from local version
    return current;
  }

  List<Map<String, dynamic>> _check(
    MessageModel message,
    StorageState<V> current,
    V next,
  ) {
    final base = current.previous;
    final mine = JsonUtils.diff(
      base,
      current.value,
    );
    final yours = message.isPatches
        ? message.patches
        : JsonUtils.diff(
            base,
            next,
          );
    final conflict = JsonUtils.check(mine, yours);
    if (conflict != null) {
      // TODO: Allow user to choose conflict resolution
      debugPrint(
        'Conflict >> ${typeOf<V>()} ${message.uuid} lost local changes: '
        '${mine.where((op) => conflict.paths.contains(op['path']))}',
      );
    }
    // Check if there are local changes left
    // (not consumed by same remote changes)
    return JsonUtils.diff(
      next,
      current.value,
    );
  }
}
