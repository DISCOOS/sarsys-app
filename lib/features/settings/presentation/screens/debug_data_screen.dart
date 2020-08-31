import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/settings/presentation/pages/repository_page.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:catcher/catcher.dart';
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: <Widget>[
              _buildConfigsTile(context),
              _buildIncidentsTile(context),
              _buildOperationsTile(context),
              _buildUnitsTile(context),
              _buildPersonsTile(context),
              _buildAffiliationsTile(context),
              _buildPersonnelsTile(context),
              _buildDevicesTile(context),
              _buildTrackingsTile(context),
              _buildOrgsTile(context),
              _buildDivsTile(context),
              _buildDepsTile(context),
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
      subtitle: (StorageState<AppConfig> state) => 'Unik app-id: ${state?.value?.udid}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildIncidentsTile(BuildContext context) {
    return RepositoryTile<Incident>(
      title: "Hendelser",
      repo: context.bloc<OperationBloc>().incidents,
      subtitle: (StorageState<Incident> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildOperationsTile(BuildContext context) {
    return RepositoryTile<Operation>(
      title: "Aksjoner",
      repo: context.bloc<OperationBloc>().repo,
      subtitle: (StorageState<Operation> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildUnitsTile(BuildContext context) {
    return RepositoryTile<Unit>(
      title: "Enheter",
      repo: context.bloc<UnitBloc>().repo,
      subtitle: (StorageState<Unit> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildPersonsTile(BuildContext context) {
    return RepositoryTile<Person>(
      title: "Personer",
      repo: context.bloc<AffiliationBloc>().persons,
      subtitle: (StorageState<Person> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildAffiliationsTile(BuildContext context) {
    return RepositoryTile<Affiliation>(
      title: "Tilhørigheter",
      repo: context.bloc<AffiliationBloc>().repo,
      subtitle: (StorageState<Affiliation> state) => '${state?.value}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildPersonnelsTile(BuildContext context) {
    return RepositoryTile<Personnel>(
      title: "Mannskaper",
      repo: context.bloc<PersonnelBloc>().repo,
      subtitle: (StorageState<Personnel> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildDevicesTile(BuildContext context) {
    return RepositoryTile<Device>(
      title: "Apparater",
      repo: context.bloc<DeviceBloc>().repo,
      subtitle: (StorageState<Device> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildTrackingsTile(BuildContext context) {
    return RepositoryTile<Tracking>(
      title: "Sporinger",
      repo: context.bloc<TrackingBloc>().repo,
      subtitle: (StorageState<Tracking> state) => '${enumName(state?.value?.status)}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildOrgsTile(BuildContext context) {
    return RepositoryTile<Organisation>(
      title: "Organisasjoner",
      repo: context.bloc<AffiliationBloc>().orgs,
      subtitle: (StorageState<Organisation> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildDivsTile(BuildContext context) {
    return RepositoryTile<Division>(
      title: "Distrikter",
      repo: context.bloc<AffiliationBloc>().divs,
      subtitle: (StorageState<Division> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildDepsTile(BuildContext context) {
    return RepositoryTile<Department>(
      title: "Avdelinger",
      repo: context.bloc<AffiliationBloc>().deps,
      subtitle: (StorageState<Department> state) => '${state?.value?.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  void _commitAll() {
    Future.wait(
      [
        context.bloc<AppConfigBloc>().repo.commit(),
        context.bloc<AffiliationBloc>().repo.commit(),
        context.bloc<AffiliationBloc>().orgs.commit(),
        context.bloc<AffiliationBloc>().divs.commit(),
        context.bloc<AffiliationBloc>().deps.commit(),
        context.bloc<AffiliationBloc>().persons.commit(),
        context.bloc<OperationBloc>().incidents.commit(),
        context.bloc<OperationBloc>().repo.commit(),
        context.bloc<UnitBloc>().repo.commit(),
        context.bloc<PersonnelBloc>().repo.commit(),
        context.bloc<DeviceBloc>().repo.commit(),
        context.bloc<TrackingBloc>().repo.commit(),
      ],
      cleanUp: (_) => setState(() {}),
    ).catchError(Catcher.reportCheckedError);
  }

  void _resetAll() async {
    // DO NOT RESET AppConfig here! Should only be done from AppDrawer
    Future.wait(
      [
        context.bloc<OperationBloc>().incidents.reset(),
        context.bloc<AffiliationBloc>().repo.reset(),
        context.bloc<AffiliationBloc>().orgs.reset(),
        context.bloc<AffiliationBloc>().divs.reset(),
        context.bloc<AffiliationBloc>().deps.reset(),
        context.bloc<AffiliationBloc>().persons.reset(),
        context.bloc<OperationBloc>().repo.reset(),
        context.bloc<UnitBloc>().repo.reset(),
        context.bloc<PersonnelBloc>().repo.reset(),
        context.bloc<DeviceBloc>().repo.reset(),
        context.bloc<TrackingBloc>().repo.reset(),
      ],
      cleanUp: (_) => setState(() {}),
    ).catchError(Catcher.reportCheckedError);
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
    this.onReset,
    this.onCommit,
    this.withResetAction = true,
    this.withCommitAction = true,
  });
  final String title;
  final VoidCallback onReset;
  final VoidCallback onCommit;
  final String Function(StorageState<T> state) subtitle;
  final ConnectionAwareRepository<dynamic, T, Service> repo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: StreamBuilder<Object>(
          stream: repo.onChanged,
          builder: (context, snapshot) {
            return _buildRepoActions(context,
                child: ListTile(
                  key: PageStorageKey<ConnectionAwareRepository>(repo),
                  leading: const Icon(Icons.storage),
                  title: Text(title),
                  subtitle: repo.isEmpty
                      ? Text('Ingen elementer')
                      : Text("Elementer: ${repo.length}, feil: ${repo.errors.length}"),
                ));
          }),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text("${typeOf<T>()}"),
            ),
            body: RepositoryPage<T>(
              repository: repo,
              subtitle: subtitle,
            ),
          ),
        ),
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
        if (onReset != null) {
          onReset();
        }
      },
    );
  }

  Widget _buildCommitAction(BuildContext context) {
    return IconSlideAction(
      caption: 'PUBLISER',
      color: Theme.of(context).buttonColor,
      icon: Icons.publish,
      onTap: () {
        if (onCommit != null) {
          onCommit();
        }
        repo.commit();
      },
    );
  }
}
