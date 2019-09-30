import 'package:catcher/mode/page_report_mode.dart';
import 'package:catcher/model/report.dart';
import 'package:flutter/material.dart';

class ScreenReportMode extends PageReportMode {
  final bool showStackTrace;
  static bool _reentrant = false;

  ScreenReportMode({
    this.showStackTrace = true,
  });

  @override
  void requestAction(Report report, BuildContext context) {
    _navigateToPageWidget(report, context);
  }

  _navigateToPageWidget(Report report, BuildContext context) async {
    if (_reentrant) return;
    _reentrant = true;
    await Future.delayed(Duration.zero);
    await Navigator.push(
      context,
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
          ],
        ),
        body: Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  "${widget.report.error}",
                  style: _getTextStyle(15),
                  textAlign: TextAlign.start,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    "Løsningsforslag",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Divider(),
                Text(
                  "Dersom feilen vedvarer kan du forsøke å slette alle app-data "
                  "via telefonens innstillinger. Hvis det ikke fungerer så prøv "
                  "å installer appen på nytt. \n\n"
                  "Send gjerne denne feilmeldingen til oss med knappen øverst til høyre.",
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    "Detaljer",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Divider(),
                Expanded(child: _getStackTraceWidget()),
              ],
            )));
  }

  TextStyle _getTextStyle(double fontSize) {
    return TextStyle(fontSize: fontSize, color: Colors.black, decoration: TextDecoration.none);
  }

  Widget _getStackTraceWidget() {
    if (widget.mode.showStackTrace) {
      var items = widget.report.stackTrace.toString().split("\n");
      return SizedBox(
        height: 300.0,
        child: ListView.builder(
          padding: EdgeInsets.all(8.0),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            return Text(
              '${items[index]}',
              style: _getTextStyle(10),
            );
          },
        ),
      );
    } else {
      return Container();
    }
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
