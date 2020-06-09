import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/repository.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:catcher/catcher_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class DebugDataScreen extends StatefulWidget {
  @override
  _DebugDataScreenState createState() => _DebugDataScreenState();
}

class _DebugDataScreenState extends State<DebugDataScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Feilsøkning lokale data"),
        automaticallyImplyLeading: true,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: <Widget>[
          Tooltip(
            message: "Publiser alle lokale endringer",
            child: IconButton(
              icon: Icon(Icons.publish),
              onPressed: () => _commitAll(),
            ),
          ),
          Tooltip(
            message: "Erstatt alle lokale endringer med publiserte verdier",
            child: IconButton(
              icon: Icon(Icons.clear_all),
              onPressed: () => _resetAll(),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              _buildConfigsTile(context),
              _buildIncidentsTile(context),
              _buildOperationsTile(context),
              _buildUnitsTile(context),
              _buildPersonnelsTile(context),
              _buildDevicesTile(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigsTile(BuildContext context) {
    return RepositoryTile<AppConfig>(
      title: "Innstillinger",
      withResetAction: false,
      repo: context.bloc<AppConfigBloc>().repo,
      subtitle: (StorageState<AppConfig> state) => 'Device id ${state?.value?.udid}',
    );
  }

  Widget _buildIncidentsTile(BuildContext context) {
    return RepositoryTile<Incident>(
      title: "Hendelser",
      repo: context.bloc<OperationBloc>().incidents,
      subtitle: (StorageState<Incident> state) => '${state?.value?.name}',
    );
  }

  Widget _buildOperationsTile(BuildContext context) {
    return RepositoryTile<Operation>(
      title: "Aksjoner",
      repo: context.bloc<OperationBloc>().repo,
      subtitle: (StorageState<Operation> state) => '${state?.value?.name}',
    );
  }

  Widget _buildUnitsTile(BuildContext context) {
    return RepositoryTile<Unit>(
      title: "Enheter",
      repo: context.bloc<UnitBloc>().repo,
      subtitle: (StorageState<Unit> state) => '${state?.value?.name}',
    );
  }

  Widget _buildPersonnelsTile(BuildContext context) {
    return RepositoryTile<Personnel>(
      title: "Mannskaper",
      repo: context.bloc<PersonnelBloc>().repo,
      subtitle: (StorageState<Personnel> state) => '${state?.value?.name}',
    );
  }

  Widget _buildDevicesTile(BuildContext context) {
    return RepositoryTile<Device>(
      title: "Apparater",
      repo: context.bloc<DeviceBloc>().repo,
      subtitle: (StorageState<Device> state) => '${state?.value?.name}',
    );
  }

  void _commitAll() {
    context.bloc<AppConfigBloc>().repo.commit()..catchError(Catcher.reportCheckedError);
    context.bloc<OperationBloc>().repo.commit()..catchError(Catcher.reportCheckedError);
    context.bloc<OperationBloc>().incidents.commit()..catchError(Catcher.reportCheckedError);
    context.bloc<UnitBloc>().repo.commit()..catchError(Catcher.reportCheckedError);
    context.bloc<PersonnelBloc>().repo.commit()..catchError(Catcher.reportCheckedError);
    context.bloc<DeviceBloc>().repo.commit()..catchError(Catcher.reportCheckedError);
    context.bloc<TrackingBloc>().repo.commit()..catchError(Catcher.reportCheckedError);
  }

  void _resetAll() async {
    // DO NOT RESET AppConfig here! Should only be done from AppDrawer
    await context.bloc<OperationBloc>().incidents.reset().catchError(Catcher.reportCheckedError);
    await context.bloc<OperationBloc>().repo.reset().catchError(Catcher.reportCheckedError);
    context.bloc<UnitBloc>().repo.reset()..catchError(Catcher.reportCheckedError);
    context.bloc<PersonnelBloc>().repo.reset()..catchError(Catcher.reportCheckedError);
    context.bloc<DeviceBloc>().repo.reset()..catchError(Catcher.reportCheckedError);
    context.bloc<TrackingBloc>().repo.reset()..catchError(Catcher.reportCheckedError);
  }
}

// Displays one Entry. If the entry has children then it's displayed
// with an ExpansionTile.
class RepositoryTile<T extends Aggregate> extends StatelessWidget {
  final bool withCommitAction;
  final bool withResetAction;

  const RepositoryTile({
    @required this.title,
    @required this.subtitle,
    @required this.repo,
    this.withResetAction = true,
    this.withCommitAction = true,
  });
  final String title;
  final String Function(StorageState<T> state) subtitle;
  final ConnectionAwareRepository<dynamic, T> repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
        stream: repo.onChanged,
        builder: (context, snapshot) {
          return repo.isEmpty
              ? _buildRepoActions(context,
                  child: ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text(title),
                    subtitle: Text('Ingen elementer'),
                  ))
              : _buildRepoActions(context,
                  child: ExpansionTile(
                    key: PageStorageKey<ConnectionAwareRepository>(repo),
                    leading: const Icon(Icons.storage),
                    title: Text(title),
                    subtitle: Text("Elementer: ${repo.length}, feil: ${repo.errors.length}"),
                    children: repo.states.values.map((state) => _buildTile(context, state)).toList(),
                  ));
        });
  }

  Widget _buildTile(BuildContext context, StorageState<T> state) {
    final key = repo.toKey(state);
    return ListTile(
      title: Text(subtitle(state)),
      subtitle: Column(
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

  Widget _buildRepoActions(
    BuildContext context, {
    @required Widget child,
  }) {
    return Slidable(
      actionPane: SlidableScrollActionPane(),
      actionExtentRatio: 0.2,
      child: child,
      actions: <Widget>[
        if (withCommitAction) _buildCommitAction(context),
        if (withResetAction) _buildResetAction(context),
      ],
    );
  }

  Widget _buildResetAction(BuildContext context) {
    return IconSlideAction(
      caption: 'NULLSTILL',
      color: Theme.of(context).buttonColor,
      icon: Icons.clear_all,
      onTap: () {
        repo.reset();
      },
    );
  }

  Widget _buildCommitAction(BuildContext context) {
    return IconSlideAction(
      caption: 'PUBLISER',
      color: Theme.of(context).buttonColor,
      icon: Icons.publish,
      onTap: () => repo.commit(),
    );
  }
}
