import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class FatalErrorApp extends StatelessWidget {
  final error;
  final stackTrace;

  const FatalErrorApp({
    Key key,
    @required this.error,
    this.stackTrace,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SarSys',
      theme: ThemeData(
        primaryColor: Colors.grey[850],
        buttonTheme: ButtonThemeData(
          height: 36.0,
          textTheme: ButtonTextTheme.primary,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('SarSys kunne ikke starte'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.send),
              tooltip: "Send feilmelding",
              onPressed: () async {
                final Email email = Email(
                  body: 'Feilmelding\n\n$error\n\n$stackTrace',
                  subject: 'SarSys kunne ikke starte',
                  recipients: ['support@discoos.org'],
                );
                await FlutterEmailSender.send(email);
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            child: _buildErrorPanel(error, stackTrace),
          ),
        ),
      ),
    );
  }

  Column _buildErrorPanel(error, stackTrace) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Text(
            "Forslag til løsning",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Divider(),
        Text(
          "Forsøk å slette alle app-data via telefonens innstillinger.\n"
          "Hvis det ikke fungerer så prøv å installer appen på nytt. \n\n"
          "Send gjerne denne feilmeldingen til oss med knappen øverst til høyre.",
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Text(
            "Feilmelding",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Divider(),
        SelectableText(
          "$error",
          style: TextStyle(fontSize: 12.0),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Text(
            "Detaljer",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Divider(),
        Flexible(
          child: SelectableText(
            "$stackTrace",
            style: TextStyle(fontSize: 12.0),
          ),
        ),
      ],
    );
  }
}
