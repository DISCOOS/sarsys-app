import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/services/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:catcher/core/catcher.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

abstract class UseCase<E, T, P> {
  /// Execute use case checked.
  /// Returns [null] if operation fails.
  @protected
  Future<Either<E, T>> call(P params) {
    try {
      return execute(params);
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(error, stackTrace);
    }
    return null;
  }

  Future<Either<E, T>> execute(P params);
}

class NoParams extends Equatable {}

class BlocParams<B extends Bloc, T> extends Equatable {
  final B bloc;
  final T data;
  OverlayState get overlay => NavigationService().overlay;
  BuildContext get context => NavigationService().context;
  PermissionController get controller => Provider.of<PermissionController>(context, listen: false);

  BlocParams(
    this.data,
  )   : this.bloc = BlocProvider.of<B>(NavigationService().context),
        super([data]);
}
