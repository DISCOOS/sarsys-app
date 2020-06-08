import 'dart:io';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class FatalErrorApp extends StatelessWidget {
  static final navigatorKey = new GlobalKey<NavigatorState>();
  final error;
  final stackTrace;

  static bool noEmailClient = false;

  const FatalErrorApp({
    Key key,
    @required this.error,
    this.stackTrace,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SarSys',
      theme: ThemeData(
        primaryColor: Colors.grey[850],
        buttonTheme: ButtonThemeData(
          height: 36.0,
          textTheme: ButtonTextTheme.primary,
        ),
      ),
      localizationsDelegates: [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', 'US'), // English
        const Locale('nb', 'NO'), // Norwegian Bokmål
      ],
      home: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
        return Scaffold(
          appBar: AppBar(
            title: Text('SarSys kunne ikke starte'),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.send),
                tooltip: "Send feilmelding",
                onPressed: noEmailClient
                    ? null
                    : () async {
                        final Email email = Email(
                          body: 'Feilmelding\n\n$error\n\n$stackTrace',
                          subject: 'SarSys kunne ikke starte',
                          recipients: ['support@discoos.org'],
                        );
                        try {
                          await FlutterEmailSender.send(email);
                        } on Exception {
                          setState(() => noEmailClient = true);
                          prompt(
                            navigatorKey.currentState.overlay.context,
                            "Feilmelding kunne ikke sendes",
                            "Kopier feilmeldingen eller ta en skjermdump og send den til support@discoos.org",
                          );
                        }
                      },
              ),
              IconButton(
                icon: Icon(Icons.delete),
                tooltip: "Slett data",
                onPressed: () async {
                  final delete = await prompt(
                    navigatorKey.currentState.overlay.context,
                    "Slette alle data?",
                    "Dette vil slette alle data SarSys har lagret. Vil du fortsette?",
                  );
                  if (delete) {
                    await Storage.destroy();
                    exit(0);
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.close),
                tooltip: "Lukk app",
                onPressed: () => exit(0),
              ),
            ],
          ),
          body: FatalErrorWidget(error, stackTrace),
        );
      }),
    );
  }
}

class FatalErrorWidget extends StatelessWidget {
  final error;
  final stackTrace;
  const FatalErrorWidget(
    this.error,
    this.stackTrace, {
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        child: Column(
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
              "Dersom feilen vedvarer kan du forsøke å slette alle app-data "
              "med knappen oppe til høyre (søppeldunk). Hvis det ikke fungerer så prøv "
              "å installer appen på nytt. \n\n"
              "Send gjerne denne feilmeldingen til oss med sende-knappen oppe til høyre (pil).",
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
        ),
      ),
    );
  }
}

class FatalErrorAppBlocDelegate extends FatalErrorApp implements BlocDelegate {
  @override
  void onError(Bloc bloc, Object error, StackTrace stackTrace) {
    runApp(FatalErrorApp(
      error: error,
      stackTrace: stackTrace,
    ));
  }

  @override
  void onEvent(Bloc bloc, Object event) {}

  @override
  void onTransition(Bloc bloc, Transition transition) {}
}
