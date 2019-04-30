import 'package:flutter/material.dart';
import '../Widgets/AppDrawer.dart';
import '../Widgets/ColoredTabBar.dart';

class IncidentScreen extends StatefulWidget {
  //modified
  @override //new
  IncidentScreenState createState() => new IncidentScreenState(); //new
}

class IncidentScreenState extends State<IncidentScreen> {
  //new
  @override //new
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: AppDrawer(),
        appBar: AppBar(
          bottom: ColoredTabBar(Colors.white, TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(text: "Hendelse"),
              Tab(text: "Plan"),
            ],
          ),),
          title: Text('Hendelse'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: Icon(Icons.add),
          elevation: 2.0,
        ),
        body: TabBarView(
          children: [
            Icon(Icons.directions_car),
            Icon(Icons.directions_transit),
          ],
        ),
      ),
    );
  }
}
