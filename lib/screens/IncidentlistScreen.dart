import 'package:flutter/material.dart';

class IncidentlistScreen extends StatefulWidget {
  //modified
  @override //new
  IncidentlistScreenState createState() => new IncidentlistScreenState(); //new
}

// Add the ChatScreenState class definition in main.dart.

class IncidentlistScreenState extends State<IncidentlistScreen> {
  //new
  @override //new
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: new Text("Velg hendelse")),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("New Incident");
        },
        tooltip: 'Ny hendelse',
        child: Icon(Icons.add),
        elevation: 2.0,
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.sort),
              color: Colors.white,
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.search),
              color: Colors.white,
              onPressed: () {},
            )
          ],
        ),
        shape: CircularNotchedRectangle(),
        color: Colors.grey[850],
      ),
      body: Column(children: [
        Card(
          child: Container(
            padding: EdgeInsets.all(4.0),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: CircleAvatar(child: Text("2h")),
                  title: Text("Savnet person (øvelse)"),
                  subtitle: Text("EX-201901"),
                ),
                Text('Kart'),
                Row(children: [
                  FlatButton(
                    child: Text('Velg'),
                    onPressed: () {
                      // Set appstate current incident

                      // Navigate to incident screen
                      Navigator.pushReplacementNamed(context, 'incident');
                    },
                  ),
                ])
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
