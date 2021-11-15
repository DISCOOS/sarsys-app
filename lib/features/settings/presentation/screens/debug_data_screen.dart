

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/error_handler.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/domain/stateful_repository.dart';
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
      repo: context.read<AppConfigBloc>().repo,
      subject: (StorageState<AppConfig> state) => 'Unik app-id: ${state.value.udid}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildIncidentsTile(BuildContext context) {
    return RepositoryTile<Incident>(
      title: "Hendelser",
      repo: context.read<OperationBloc>().incidents,
      subject: (StorageState<Incident> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildOperationsTile(BuildContext context) {
    return RepositoryTile<Operation>(
      title: "Aksjoner",
      repo: context.read<OperationBloc>().repo,
      subject: (StorageState<Operation> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildUnitsTile(BuildContext context) {
    return RepositoryTile<Unit>(
      title: "Enheter",
      repo: context.read<UnitBloc>().repo,
      subject: (StorageState<Unit> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildPersonsTile(BuildContext context) {
    return RepositoryTile<Person>(
      title: "Personer",
      repo: context.read<AffiliationBloc>().persons,
      subject: (StorageState<Person> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildAffiliationsTile(BuildContext context) {
    return RepositoryTile<Affiliation>(
      title: "Tilhørigheter",
      repo: context.read<AffiliationBloc>().repo,
      subject: (StorageState<Affiliation> state) => '${context.read<AffiliationBloc>().toName(
            state.value,
            empty: translateAffiliationType(AffiliationType.volunteer),
          )}',
      content: (StorageState<Affiliation> state) => '${emptyAsNull(state.value.person?.name) ?? '<Ingen navn>'}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildPersonnelsTile(BuildContext context) {
    return RepositoryTile<Personnel>(
      title: "Mannskaper",
      repo: context.read<PersonnelBloc>().repo,
      subject: (StorageState<Personnel> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildDevicesTile(BuildContext context) {
    return RepositoryTile<Device>(
      title: "Apparater",
      repo: context.read<DeviceBloc>().repo,
      subject: (StorageState<Device> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildTrackingsTile(BuildContext context) {
    return RepositoryTile<Tracking>(
      title: "Sporinger",
      repo: context.read<TrackingBloc>().repo,
      subject: (StorageState<Tracking> state) {
        final units = context.read<UnitBloc>().repo.find(
              where: (u) => u.tracking.uuid == state.value.uuid,
            );
        if (units.isNotEmpty) {
          return 'Unit: ${units.first.name} '
              '(${translateUnitStatus(units.first.status)})';
        }
        final personnels = context.read<PersonnelBloc>().repo.find(
              where: (p) => p.tracking.uuid == state.value.uuid,
            );
        if (personnels.isNotEmpty) {
          return 'Mannskap: ${personnels.first.person.name} '
              '(${translatePersonnelStatus(personnels.first.status)})';
        }

        return 'Tracking is ${enumName(state.value.status)}';
      },
      content: (StorageState<Tracking> state) => '${toUTM(state.value.position?.geometry, empty: 'Ingen posisjon')}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildOrgsTile(BuildContext context) {
    return RepositoryTile<Organisation>(
      title: "Organisasjoner",
      repo: context.read<AffiliationBloc>().orgs,
      subject: (StorageState<Organisation> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildDivsTile(BuildContext context) {
    return RepositoryTile<Division>(
      title: "Distrikter",
      repo: context.read<AffiliationBloc>().divs,
      subject: (StorageState<Division> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  Widget _buildDepsTile(BuildContext context) {
    return RepositoryTile<Department>(
      title: "Avdelinger",
      repo: context.read<AffiliationBloc>().deps,
      subject: (StorageState<Department> state) => '${state.value.name}',
      onReset: () => setState(() {}),
      onCommit: () => setState(() {}),
    );
  }

  void _commitAll() {
    Future.wait(
      [
        context.read<AppConfigBloc>().repo.commit(),
        context.read<AffiliationBloc>().repo.commit(),
        context.read<AffiliationBloc>().orgs.commit(),
        context.read<AffiliationBloc>().divs.commit(),
        context.read<AffiliationBloc>().deps.commit(),
        context.read<AffiliationBloc>().persons.commit(),
        context.read<OperationBloc>().incidents.commit(),
        context.read<OperationBloc>().repo.commit(),
        context.read<UnitBloc>().repo.commit(),
        context.read<PersonnelBloc>().repo.commit(),
        context.read<DeviceBloc>().repo!.commit(),
        context.read<TrackingBloc>().repo.commit(),
      ],
      cleanUp: (dynamic _) => setState(() {}),
    ).catchError(SarSysApp.reportCheckedError);
  }

  void _resetAll() async {
    // DO NOT RESET AppConfig here! Should only be done from AppDrawer
    Future.wait(
      [
        context.read<OperationBloc>().incidents.reset(),
        context.read<AffiliationBloc>().repo.reset(),
        context.read<AffiliationBloc>().orgs.reset(),
        context.read<AffiliationBloc>().divs.reset(),
        context.read<AffiliationBloc>().deps.reset(),
        context.read<AffiliationBloc>().persons.reset(),
        context.read<OperationBloc>().repo.reset(),
        context.read<UnitBloc>().repo.reset(),
        context.read<PersonnelBloc>().repo.reset(),
        context.read<DeviceBloc>().repo!.reset(),
        context.read<TrackingBloc>().repo.reset(),
      ],
      cleanUp: (dynamic _) => setState(() {}),
    ).catchError(SarSysApp.reportCheckedError);
  }
}

// Displays one Entry. If the entry has children then it's displayed
// with an ExpansionTile.
class RepositoryTile<T extends Aggregate> extends StatelessWidget {
  final bool withCommitAction;
  final bool withResetAction;

  const RepositoryTile({
    required this.repo,
    required this.title,
    required this.subject,
    this.content,
    this.onReset,
    this.onCommit,
    this.withResetAction = true,
    this.withCommitAction = true,
  });
  final String title;
  final VoidCallback? onReset;
  final VoidCallback? onCommit;
  final StatefulRepository? repo;
  final String Function(StorageState<T> state) subject;
  final String Function(StorageState<T> state)? content;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object?>(
        stream: repo!.onChanged,
        builder: (context, snapshot) {
          var local = 0;
          var remote = 0;
          if (snapshot.hasData) {
            repo!.states.values.forEach((state) {
              if (state.isLocal) {
                local++;
              } else {
                remote++;
              }
            });
          }
          return _buildRepoActions(
            context,
            child: ListTile(
              key: PageStorageKey<StatefulRepository?>(repo),
              leading: const Icon(Icons.storage),
              title: SelectableText(
                title,
                onTap: () => onTap(context),
              ),
              subtitle: repo!.isEmpty
                  ? SelectableText('No data')
                  : SelectableText(
                      'Totals ${repo!.length} '
                      '($remote published, $local waiting, ${repo!.errors.length} errors)',
                    ),
              onTap: () => onTap(context),
            ),
          );
        });
  }

  Future onTap(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text("${typeOf<T>()}"),
          ),
          body: RepositoryPage<T>(
            repository: repo,
            subject: subject,
            content: content,
          ),
        ),
      ),
    );
  }

  Widget _buildRepoActions(
    BuildContext context, {
    required Widget child,
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
        repo!.reset();
        if (onReset != null) {
          onReset!();
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
          onCommit!();
        }
        repo!.commit();
      },
    );
  }
}
