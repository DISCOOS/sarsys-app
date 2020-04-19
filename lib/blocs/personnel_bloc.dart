import 'dart:async';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/repositories/personnel_repository.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:bloc/bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

typedef void PersonnelCallback(VoidCallback fn);

class PersonnelBloc extends Bloc<PersonnelCommand, PersonnelState> {
  final PersonnelRepository repo;
  final IncidentBloc incidentBloc;

  PersonnelService get service => repo.service;

  String get iuuid => incidentBloc.selected.uuid;

  // only set once to prevent reentrant error loop
  List<StreamSubscription> _subscriptions = [];

  PersonnelBloc(this.repo, this.incidentBloc) {
    assert(repo != null, "repo can not be null");
    assert(service != null, "service can not be null");
    assert(incidentBloc != null, "incidentBloc can not be null");
    _subscriptions
      ..add(incidentBloc.listen(
        _init,
      ))
      // Process tracking messages
      ..add(service.messages.listen(
        _handle,
      ));
  }

  void _init(IncidentState state) {
    try {
      if (_subscriptions.isNotEmpty) {
        // Clear out current tracking upon states given below
        if (state.isUnset() ||
            state.isCreated() ||
            state.isDeleted() ||
            (state.isUpdated() &&
                [
                  IncidentStatus.Cancelled,
                  IncidentStatus.Resolved,
                ].contains((state as IncidentUpdated).data.status))) {
          //
          // TODO: Mark as internal event, no message from personnel service expected
          //
          add(UnloadPersonnel(repo.iuuid));
        } else if (state.isSelected()) {
          add(LoadPersonnel(state.data.uuid));
        }
      }
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(
        error,
        stackTrace,
      );
    }
  }

  void _handle(event) {
    try {
      add(_HandleMessage(event));
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(
        error,
        stackTrace,
      );
    }
  }

  @override
  PersonnelState get initialState => PersonnelEmpty();

  /// Get personnel
  Map<String, Personnel> get personnel => repo.map;

  /// Find personnel from user
  List<Personnel> find(
    User user, {
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  }) =>
      repo.find(user, exclude: exclude);

  /// Stream of changes on given Personnel
  Stream<Personnel> changes(Personnel personnel) => where(
        (state) =>
            (state is PersonnelUpdated && state.data.id == personnel.id) ||
            (state is PersonnelLoaded && state.data.contains(personnel.id)),
      ).map((state) => state is PersonnelLoaded ? repo[personnel.id] : state.data);

  /// Get count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  }) =>
      repo.count(exclude: exclude);

  void _assertState() {
    if (incidentBloc.isUnset) {
      throw PersonnelError(
        "No incident selected. "
        "Ensure that 'IncidentBloc.select(String id)' is called before 'PersonnelBloc.load()'",
      );
    }
  }

  /// Fetch personnel from [service]
  Future<List<Personnel>> load() async {
    _assertState();
    return _dispatch<List<Personnel>>(
      LoadPersonnel(iuuid),
    );
  }

  /// Create given personnel
  Future<Personnel> create(Personnel personnel) {
    _assertState();
    return _dispatch<Personnel>(
      CreatePersonnel(personnel),
    );
  }

  /// Update given personnel
  Future<Personnel> update(Personnel personnel) {
    _assertState();
    return _dispatch<Personnel>(
      UpdatePersonnel(personnel),
    );
  }

  /// Delete given personnel
  Future<Personnel> delete(Personnel personnel) {
    _assertState();
    return _dispatch<Personnel>(
      DeletePersonnel(personnel),
    );
  }

  @override
  Stream<PersonnelState> mapEventToState(PersonnelCommand command) async* {
    if (command is LoadPersonnel) {
      yield await _load(command);
    } else if (command is CreatePersonnel) {
      yield await _create(command);
    } else if (command is UpdatePersonnel) {
      yield await _update(command);
    } else if (command is DeletePersonnel) {
      yield await _delete(command);
    } else if (command is UnloadPersonnel) {
      yield await _unload(command);
    } else if (command is _HandleMessage) {
      yield await _process(command.data);
    } else if (command is RaisePersonnelError) {
      yield _toError(command, command.data);
    } else {
      yield _toError(
        command,
        PersonnelError("Unsupported $command"),
      );
    }
  }

  Future<PersonnelState> _load(LoadPersonnel command) async {
    var devices = await repo.load(command.data);
    return _toOK<List<Personnel>>(
      command,
      PersonnelLoaded(repo.keys),
      result: devices,
    );
  }

  Future<PersonnelState> _create(CreatePersonnel command) async {
    var device = await repo.create(iuuid, command.data);
    return _toOK(
      command,
      PersonnelCreated(device),
      result: device,
    );
  }

  Future<PersonnelState> _update(UpdatePersonnel command) async {
    final device = await repo.update(command.data);
    return _toOK(
      command,
      PersonnelUpdated(device),
      result: device,
    );
  }

  Future<PersonnelState> _delete(DeletePersonnel command) async {
    final device = await repo.delete(command.data);
    return _toOK(
      command,
      PersonnelDeleted(device),
      result: device,
    );
  }

  Future<PersonnelState> _unload(UnloadPersonnel command) async {
    final devices = await repo.unload();
    return _toOK(
      command,
      PersonnelUnloaded(devices),
      result: devices,
    );
  }

  Future<PersonnelState> _process(PersonnelMessage event) async {
    switch (event.type) {
      case PersonnelMessageType.PersonnelChanged:
        if (repo.containsKey(event.puuid)) {
          return PersonnelUpdated(
            await repo.patch(Personnel.fromJson(event.json)),
          );
        }
        break;
    }
    return PersonnelError("Personnel message not recognized: $event");
  }

  // Dispatch and return future
  Future<T> _dispatch<T>(PersonnelCommand<Object, T> command) {
    add(command);
    return command.callback.future;
  }

  // Complete request and return given state to bloc
  PersonnelState _toOK<T>(PersonnelCommand event, PersonnelState state, {T result}) {
    if (result != null)
      event.callback.complete(result);
    else
      event.callback.complete();
    return state;
  }

  // Complete with error and return response as error state to bloc
  PersonnelState _toError(PersonnelCommand event, Object response) {
    final error = PersonnelError(response);
    event.callback.completeError(error);
    return error;
  }

  @override
  void onError(Object error, StackTrace stacktrace) {
    if (_subscriptions.isNotEmpty) {
      add(RaisePersonnelError(PersonnelError(error, stackTrace: stacktrace)));
    } else {
      throw "Bad state: PersonnelBloc is disposed. Unexpected ${PersonnelError(error, stackTrace: stacktrace)}";
    }
  }

  @override
  Future<void> close() async {
    super.close();
    _subscriptions.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();
  }
}

/// ---------------------
/// Commands
/// ---------------------
abstract class PersonnelCommand<S, T> extends Equatable {
  final S data;
  final Completer<T> callback = Completer();

  PersonnelCommand(this.data, [props = const []]) : super([data, ...props]);
}

class LoadPersonnel extends PersonnelCommand<String, List<Personnel>> {
  LoadPersonnel(String iuuid) : super(iuuid);

  @override
  String toString() => 'LoadPersonnel {iuuid: $data}';
}

class CreatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  CreatePersonnel(Personnel data) : super(data);

  @override
  String toString() => 'CreatePersonnel {data: $data}';
}

class UpdatePersonnel extends PersonnelCommand<Personnel, Personnel> {
  UpdatePersonnel(Personnel data) : super(data);

  @override
  String toString() => 'UpdatePersonnel {data: $data}';
}

class DeletePersonnel extends PersonnelCommand<Personnel, Personnel> {
  DeletePersonnel(Personnel data) : super(data);

  @override
  String toString() => 'DeletePersonnel {data: $data}';
}

class _HandleMessage extends PersonnelCommand<PersonnelMessage, PersonnelMessage> {
  _HandleMessage(PersonnelMessage data) : super(data);

  @override
  String toString() => '_HandleMessage {data: $data}';
}

class UnloadPersonnel extends PersonnelCommand<String, List<String>> {
  UnloadPersonnel(String iuuid) : super(iuuid);

  @override
  String toString() => 'ClearPersonnel {iuuid: $data}';
}

class RaisePersonnelError extends PersonnelCommand<PersonnelError, PersonnelError> {
  RaisePersonnelError(data) : super(data);

  @override
  String toString() => 'RaisePersonnelError {data: $data}';
}

/// ---------------------
/// Normal States
/// ---------------------
abstract class PersonnelState<T> extends Equatable {
  final T data;

  PersonnelState(this.data, [props = const []]) : super([data, ...props]);

  isEmpty() => this is PersonnelEmpty;
  isLoaded() => this is PersonnelLoaded;
  isCreated() => this is PersonnelCreated;
  isUpdated() => this is PersonnelUpdated;
  isDeleted() => this is PersonnelDeleted;
  isCleared() => this is PersonnelUnloaded;
  isException() => this is PersonnelException;
  isError() => this is PersonnelError;
}

class PersonnelEmpty extends PersonnelState<Null> {
  PersonnelEmpty() : super(null);

  @override
  String toString() => 'PersonnelEmpty';
}

class PersonnelLoaded extends PersonnelState<List<String>> {
  PersonnelLoaded(List<String> data) : super(data);

  @override
  String toString() => 'PersonnelLoaded {data: $data}';
}

class PersonnelCreated extends PersonnelState<Personnel> {
  PersonnelCreated(Personnel data) : super(data);

  @override
  String toString() => 'PersonnelCreated {data: $data}';
}

class PersonnelUpdated extends PersonnelState<Personnel> {
  PersonnelUpdated(Personnel data) : super(data);

  @override
  String toString() => 'PersonnelUpdated {data: $data}';
}

class PersonnelDeleted extends PersonnelState<Personnel> {
  PersonnelDeleted(Personnel data) : super(data);

  @override
  String toString() => 'PersonnelDeleted {data: $data}';
}

class PersonnelUnloaded extends PersonnelState<List<Personnel>> {
  PersonnelUnloaded(List<Personnel> personnel) : super(personnel);

  @override
  String toString() => 'PersonnelUnloaded {data: $data}';
}

/// ---------------------
/// Exceptional States
/// ---------------------
abstract class PersonnelException extends PersonnelState<Object> {
  final StackTrace stackTrace;
  PersonnelException(Object error, {this.stackTrace}) : super(error, [stackTrace]);

  @override
  String toString() => 'PersonnelException {data: $data}';
}

/// Error that should have been caught by the programmer, see [Error] for details about errors in dart.
class PersonnelError extends PersonnelException {
  final StackTrace stackTrace;
  PersonnelError(Object error, {this.stackTrace}) : super(error, stackTrace: stackTrace);

  @override
  String toString() => 'PersonnelError {data: $data}';
}
