

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/presentation/widgets/permission_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PermissionConfigScreen extends StatefulWidget {
  @override
  _PermissionConfigScreenState createState() => _PermissionConfigScreenState();
}

class _PermissionConfigScreenState extends State<PermissionConfigScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _permissionsKey = GlobalKey<PermissionSetupState>();

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Tillatelser"),
        automaticallyImplyLeading: true,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: PermissionSetup(
          key: _permissionsKey,
          onChanged: (response) async {
            await context.read<AppConfigBloc>().updateWith(
                  storage: _permissionsKey.currentState!.isStorageGranted,
                  locationWhenInUse: _permissionsKey.currentState!.isLocationWhenInUseGranted,
                );
          },
        ),
      ),
    );
  }
}
