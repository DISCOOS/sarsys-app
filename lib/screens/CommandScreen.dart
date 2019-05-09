import 'package:SarSys/blocs/IncidentBloc.dart';
import 'package:SarSys/pages/IncidentPage.dart';
import 'package:SarSys/pages/PlanPage.dart';
import 'package:SarSys/widgets/AppDrawer.dart';
import 'package:SarSys/widgets/ColoredTabBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CommandScreen extends StatelessWidget {
  final int tabIndex;

  CommandScreen({Key key, @required this.tabIndex}) : super(key: key);

  //new
  @override //new
  Widget build(BuildContext context) {
    IncidentBloc bloc = BlocProvider.of<IncidentBloc>(context);
    return DefaultTabController(
      length: 2,
      initialIndex: this.tabIndex,
      child: Scaffold(
        drawer: AppDrawer(),
        appBar: AppBar(
          bottom: ColoredTabBar(
            Colors.white,
            TabBar(
              labelColor: Colors.black,
              tabs: [
                Tab(text: "Hendelse"),
                Tab(text: "Plan"),
              ],
            ),
          ),
          title: StreamBuilder(
            stream: bloc.switches,
            initialData: bloc.current?.reference,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              String title = "Ingen hendelse";
              if (snapshot.hasData) {
                title = snapshot.data is IncidentSelected ? snapshot.data.reference : snapshot.data;
              }
              return Tab(text: title);
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: Icon(Icons.add),
          elevation: 2.0,
        ),
        body: TabBarView(
          children: [
            IncidentPage(),
            PlanPage(),
          ],
        ),
      ),
    );
  }
}
