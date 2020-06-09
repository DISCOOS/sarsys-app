import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/services/location_service.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class DebugLocationScreen extends StatefulWidget {
  @override
  _DebugLocationScreenState createState() => _DebugLocationScreenState();
}

class _DebugLocationScreenState extends State<DebugLocationScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  LocationService _locationService;
  AppConfigBloc get bloc => context.bloc<AppConfigBloc>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locationService = LocationService(bloc);
  }

  @override //new
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("Feilsøke posisjon og sporing"),
        automaticallyImplyLeading: true,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(
                "Posisjonstjeneste",
                style: Theme.of(context).textTheme.subtitle2.copyWith(fontWeight: FontWeight.bold),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.system_update),
                    tooltip: "Konfigurer posisjonstjenesten på nytt",
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final answer = await prompt(
                        context,
                        "Bekreftelse",
                        "Dette vil konfigurere posisjonstjenesten på nytt, vil du forsette?",
                      );
                      if (answer) {
                        await LocationService(bloc).configure(force: true);
                        setState(() {});
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.my_location),
                    tooltip: "Be om min posisjon",
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      await LocationService(bloc).update();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    tooltip: "Send posisjonslogg til epostmottaker",
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final Email email = Email(
                        body: 'Posisjonstjeneste log:\n\n${_locationService.events.map(
                              (event) => '${event.runtimeType}\n$event',
                            ).join('\n\n')}',
                        subject: 'Posisjonstjeneste - log',
                        recipients: ['support@discoos.org'],
                      );
                      await FlutterEmailSender.send(email);
                    },
                  ),
                ],
              ),
            ),
            StreamBuilder<LocationEvent>(
                stream: _locationService.onChanged,
                builder: (context, snapshot) {
                  final now = DateTime.now();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: ClampingScrollPhysics(),
                    itemCount: _locationService.events.length,
                    itemBuilder: (BuildContext context, int index) {
                      final LocationEvent event = _locationService[index];
                      final duration = now.difference(_locationService[index].timestamp);
                      return ListTile(
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text('${event.runtimeType}', style: TextStyle(fontWeight: FontWeight.w600)),
                            Chip(label: Text('${formatDuration(duration, withMillis: true)}')),
                          ],
                        ),
                        subtitle: Text('$event'),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) => Divider(),
                  );
                }),
          ],
        ),
      ),
    );
  }
}
