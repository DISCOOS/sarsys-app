import 'package:SarSys/services/navigation_service.dart';
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class UseCase<E, T, P> {
  Future<Either<E, T>> call(P params);
}

class NoParams extends Equatable {}

class BlocParams<B extends Bloc, T> extends Equatable {
  final B bloc;
  final T data;
  OverlayState get overlay => NavigationService().overlay;
  BuildContext get context => NavigationService().context;

  BlocParams(
    this.data,
  )   : this.bloc = BlocProvider.of<B>(NavigationService().context),
        super([data]);
}
