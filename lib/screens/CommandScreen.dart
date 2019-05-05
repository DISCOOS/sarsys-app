import 'package:SarSys/pages/IncidentPage.dart';
import 'package:SarSys/pages/PlanPage.dart';
import 'package:SarSys/widgets/AppDrawer.dart';
import 'package:SarSys/widgets/ColoredTabBar.dart';
import 'package:flutter/material.dart';

class CommandScreen extends StatelessWidget {
  final int tabIndex;

  const CommandScreen({Key key, @required this.tabIndex}) : super(key: key);

  //new
  @override //new
  Widget build(BuildContext context) {
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
          title: Text('Hendelse'),
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
