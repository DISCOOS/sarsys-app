import 'package:flutter/material.dart';

class IncidentsScreen extends StatefulWidget {
  //modified
  @override //new
  IncidentsScreenState createState() => new IncidentsScreenState(); //new
}

// Add the ChatScreenState class definition in main.dart.

class IncidentsScreenState extends State<IncidentsScreen> {
  //new
  @override //new
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Velg hendelse"),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(children: [
          _buildCard(
            context,
            Incident(
                id: "1",
                name: "Savnet person (øvelse)",
                reference: "EX-201901",
                description: "Mann, 32 år, økt selvmordsfare.",
                occurred: DateTime.now().subtract(Duration(hours: 2))),
          ),
        ]),
      ),
    );
  }

  Card _buildCard(BuildContext context, Incident incident) {
    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: CircleAvatar(
              child: Text(
                "${_formatSince(incident.occurred)}",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.redAccent,
            ),
            title: Text(
              incident.name,
              style: TextStyle(fontSize: 20.0),
            ),
            subtitle: Text(
              incident.reference,
              style: TextStyle(fontSize: 14.0, color: Colors.black.withOpacity(0.5)),
            ),
          ),
          Container(
            height: 240.0,
            child: Center(child: Text('Kart')),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.5)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              children: [
                Wrap(
                  children: [
                    Text(incident.description),
                  ],
                )
              ],
            ),
          ),
          ButtonTheme.bar(
            layoutBehavior: ButtonBarLayoutBehavior.constrained,
            padding: EdgeInsets.only(right: 0.0),
            // make buttons use the appropriate styles for cards
            child: ButtonBar(
              alignment: MainAxisAlignment.start,
              children: <Widget>[
                FlatButton(
                  child: const Text('VELG', style: TextStyle(fontSize: 14.0)),
                  padding: EdgeInsets.only(left: 16.0, right: 16.0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () {
                    // TODO Set appstate current incident
                    Navigator.pushReplacementNamed(context, 'incident');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSince(DateTime timestamp) {
    Duration delta = DateTime.now().difference(timestamp);
    return delta.inHours > 99 ? "${delta.inDays}d" : delta.inHours > 0 ? "${delta.inHours}h" : "${delta.inSeconds}h";
  }
}

class Incident {
  final String id, name, reference;
  final DateTime occurred;

  var description;

  Incident({
    @required this.id,
    this.name,
    this.reference,
    this.description,
    this.occurred,
  });
}
