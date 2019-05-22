import 'package:SarSys/blocs/IncidentBloc.dart';
import 'package:SarSys/blocs/UserBloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/editors/IncidentEditor.dart';
import 'package:SarSys/popups/PasscodePopup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IncidentsScreen extends StatefulWidget {
  //modified
  @override //new
  IncidentsScreenState createState() => new IncidentsScreenState(); //new
}

// TODO: Add the ChatScreenState class definition in main.dart.

class IncidentsScreenState extends State<IncidentsScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override //new
  Widget build(BuildContext context) {
    final IncidentBloc bloc = BlocProvider.of<IncidentBloc>(context).init(setState);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return new Scaffold(
          appBar: new AppBar(
            title: new Text("Velg hendelse"),
          ),
          body: _buildBody(bloc, context, viewportConstraints),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              print("New Incident");
              showDialog(context: context, builder: (context) => IncidentEditor());
            },
            tooltip: 'Ny hendelse',
            child: Icon(Icons.add),
            elevation: 2.0,
          ),
          bottomNavigationBar: _buildBottomAppBar(),
        );
      },
    );
  }

  Widget _buildBody(IncidentBloc bloc, BuildContext context, BoxConstraints viewportConstraints) {
    return RefreshIndicator(
      onRefresh: () async {
        await bloc.fetch();
        setState(() {});
      },
      child: AnimatedCrossFade(
        duration: Duration(milliseconds: 300),
        crossFadeState: bloc.incidents.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild: Center(
          child: CircularProgressIndicator(),
        ),
        secondChild: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewportConstraints.maxHeight,
            ),
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                children: bloc.incidents.map((incident) => _buildCard(context, bloc, incident)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, IncidentBloc bloc, Incident incident) {
    final userBloc = BlocProvider.of<UserBloc>(context);

    return StreamBuilder(
        stream: userBloc.state,
        builder: (context, snapshot) {
          final isAuthorized = userBloc.isAuthorized(incident);
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
                    incident.reference ?? 'ingen',
                    style: TextStyle(fontSize: 14.0, color: Colors.black.withOpacity(0.5)),
                  ),
                ),
                if (isAuthorized)
                  Container(
                    height: 240.0,
                    child: Center(child: Text('Kart')),
                    decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.5)),
                  ),
                if (isAuthorized)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: Row(
                      children: [
                        Wrap(
                          children: [
                            Text(incident.justification),
                          ],
                        )
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    ButtonTheme.bar(
                      layoutBehavior: ButtonBarLayoutBehavior.constrained,
                      padding: EdgeInsets.only(right: 0.0),
                      // make buttons use the appropriate styles for cards
                      child: ButtonBar(
                        alignment: MainAxisAlignment.start,
                        children: <Widget>[
                          FlatButton(
                            child: Text(isAuthorized ? 'VELG' : 'LÅS OPP', style: TextStyle(fontSize: 14.0)),
                            padding: EdgeInsets.only(left: 16.0, right: 16.0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onPressed: () {
                              if (isAuthorized) {
                                bloc.select(incident.id);
                                Navigator.pushReplacementNamed(context, 'incident');
                              } else {
                                Navigator.push(context, PasscodeRoute(incident));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            isAuthorized ? Icons.lock_open : Icons.lock,
                            color: isAuthorized ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
                            size: 24.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
  }

  BottomAppBar _buildBottomAppBar() {
    return BottomAppBar(
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
    );
  }

  String _formatSince(DateTime timestamp) {
    Duration delta = DateTime.now().difference(timestamp);
    return delta.inHours > 99 ? "${delta.inDays}d" : delta.inHours > 0 ? "${delta.inHours}h" : "${delta.inSeconds}h";
  }
}
