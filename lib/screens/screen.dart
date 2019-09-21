import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';

abstract class Screen<S extends ScreenState> extends StatefulWidget {
  const Screen({Key key}) : super(key: key);
  @override
  S createState();
}

abstract class ScreenState extends State<Screen> {
  final String title;
  final FloatingActionButtonLocation floatingActionButtonLocation;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  ScreenState({
    @required this.title,
    this.floatingActionButtonLocation = FloatingActionButtonLocation.endFloat,
  });

  @protected
  Widget buildFAB() => null;

  @protected
  Widget bottomNavigationBar() => null;

  @protected
  Widget buildBody(BoxConstraints constraints);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(),
          appBar: AppBar(
            title: Text(title),
            centerTitle: false,
          ),
          extendBody: true,
          resizeToAvoidBottomInset: true,
          body: buildBody(constraints),
          floatingActionButtonLocation: floatingActionButtonLocation,
          floatingActionButton: buildFAB(),
          bottomNavigationBar: bottomNavigationBar(),
        );
      },
    );
  }
}
