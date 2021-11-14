

import 'package:SarSys/core/data/services/navigation_service.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:catcher/mode/page_report_mode.dart';
import 'package:catcher/model/report.dart';
import 'package:flutter/material.dart';

import 'fatal_error_app.dart';

class ScreenReportMode extends PageReportMode {
  final bool showStackTrace;
  static bool _reentrant = false;

  ScreenReportMode({
    this.showStackTrace = true,
  });

  @override
  void requestAction(Report report, BuildContext? context) {
    _navigateToPageWidget(report, context);
  }

  _navigateToPageWidget(Report report, BuildContext? context) async {
    if (_reentrant) return;
    _reentrant = true;
    await Future.delayed(Duration.zero);
    await Navigator.push(
      context!,
      MaterialPageRoute(builder: (context) => ScreenReport(this, report)),
    );
    _reentrant = false;
  }
}

class ScreenReport extends StatefulWidget {
  final ScreenReportMode mode;
  final Report report;

  ScreenReport(this.mode, this.report);

  @override
  ScreenReportState createState() => ScreenReportState();
}

class ScreenReportState extends State<ScreenReport> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Uventet feil"),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => _cancelReport(),
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.send),
            tooltip: "Send feilmelding",
            onPressed: () => _acceptReport(),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            tooltip: "Slett data",
            onPressed: () async {
              final delete = await prompt(
                NavigationService().overlay!.context,
                "Slette alle data?",
                "Dette vil slette alle data SarSys har lagret på telefonen unntatt kart. Vil du fortsette?",
              );
              if (delete) {
                Navigator.pop(NavigationService().overlay!.context);
                await NavigationService().controller.reset();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FatalErrorWidget(
          widget.report.error,
          widget.report.stackTrace,
        ),
      ),
    );
  }

  _acceptReport() {
    widget.mode.onActionConfirmed(widget.report);
    _closePage();
  }

  _cancelReport() {
    widget.mode.onActionRejected(widget.report);
    _closePage();
  }

  _closePage() {
    Navigator.of(context).pop();
  }
}
