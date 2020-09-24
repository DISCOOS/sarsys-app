import 'package:SarSys/core/data/streams.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/domain/usecase/core.dart';

class AppParams<T> extends BlocParams<AppConfigBloc, AppConfig> {
  AppParams({
    AppConfig config,
    AppConfigBloc bloc,
  }) : super(config, bloc: bloc);

  UserBloc get users => context.bloc<UserBloc>();
}

/// Configure app
Future<dartz.Either<bool, AppConfig>> configureApp() => ConfigureApp()(AppParams());

class ConfigureApp extends UseCase<bool, AppConfig, AppParams> {
  ConfigureApp() : super(failure: false, isModal: true);
  @override
  Future<dartz.Either<bool, AppConfig>> execute(AppParams params) async {
    //
    // If 'current_user_id' in
    // secure storage exists in bloc
    // and access token is valid, this
    // will load operations for given
    // user. If any operation matches
    // 'selected_ouuid' in secure storage
    // it will be selected as current
    // operation.
    //
    await params.users.load();

    // Wait for config to become available
    final config = await waitThroughStateWithData<AppConfigState, AppConfig>(
      params.bloc.bus,
      fail: true,
      map: (state) => state.data,
      timeout: Duration(minutes: 1),
      test: (state) => state.data is AppConfig,
    );

    // Wait for affiliations to become available
    await waitThoughtStates<AffiliationState, void>(
      params.bloc.bus,
      fail: true,
      expected: [AffiliationsLoaded],
      timeout: Duration(minutes: 1),
      test: (state) => params.bloc.isOnline ? state.isRemote : state.isLocal,
    );

    return dartz.right(config);
  }
}
