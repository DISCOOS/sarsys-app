import 'dart:math';

import 'package:SarSys/core/size_config.dart';
import 'package:flutter/material.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';

/// Stepped Screen implementing the Self-Select model in Material Design, see
/// https://material.io/design/communication/onboarding.html#self-select-model
///
/// Code is based on
/// https://medium.com/aubergine-solutions/create-an-onboarding-page-indicator-in-3-minutes-in-flutter-a2bd97ceeaff
class SteppedScreen extends StatefulWidget {
  const SteppedScreen({
    Key key,
    @required this.views,
    @required this.isComplete,
    @required this.onComplete,
    this.index = 0,
    this.onBack,
    this.onNext,
    this.hasBack,
    this.hasNext,
    this.onCancel,
    this.withProgress = true,
    this.withNextAction = true,
    this.withBackAction = true,
    this.canScroll = true,
    this.nextActionText = 'NESTE',
    this.backActionText = 'FORRIGE',
    this.cancelActionText = 'AVBRYT',
    this.completeActionText = 'FERDIG',
    this.controller,
  }) : super(key: key);

  final int index;
  final List<Widget> views;
  final String nextActionText;
  final String backActionText;
  final String cancelActionText;
  final String completeActionText;
  final PageController controller;

  final bool withProgress;
  final bool withBackAction;
  final bool withNextAction;
  final bool canScroll;

  final ValueChanged<int> onBack;
  final ValueChanged<int> onNext;
  final ValueChanged<int> onCancel;
  final ValueChanged<int> onComplete;
  final bool Function(int index) hasBack;
  final bool Function(int index) hasNext;
  final bool Function(int index) isComplete;

  @override
  _SteppedScreenState createState() => _SteppedScreenState();
}

class _SteppedScreenState extends State<SteppedScreen> {
  int index = 0;
  PageController controller;

  @override
  void initState() {
    controller = PageController(initialPage: widget.index);
    super.initState();
  }

  @override
  void didUpdateWidget(SteppedScreen oldWidget) {
    if (oldWidget.controller != widget.controller && widget.controller != null) {
      controller?.dispose();
      controller = widget.controller ?? PageController(initialPage: widget.index);
    }
    if (controller.page.toInt() != widget.index) {
      controller.jumpToPage(widget.index);
    }
    index = controller.page.toInt();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: Stack(
              alignment: AlignmentDirectional.topCenter,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: PageView.builder(
                    pageSnapping: true,
                    itemCount: widget.views.length,
                    physics: widget.canScroll ? ClampingScrollPhysics() : NeverScrollableScrollPhysics(),
                    onPageChanged: (int page) {
                      getChangedPageAndMoveBar(page);
                    },
                    controller: controller,
                    itemBuilder: (context, index) {
                      return KeyboardAvoider(
                        child: widget.views[index],
                        autoScroll: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      elevation: 4.0,
      child: Container(
        height: 56,
        child: Stack(
          children: <Widget>[
            if (widget.withBackAction)
              Align(
                alignment: Alignment.centerLeft,
                child: FlatButton(
                  disabledTextColor: Theme.of(context).bottomAppBarColor,
                  child: Text(widget.backActionText),
                  onPressed: index == 0
                      ? null
                      : () {
                          if (_hasBack(index)) {
                            controller.animateToPage(
                              index = max(0, --index),
                              curve: Curves.linearToEaseOut,
                              duration: const Duration(milliseconds: 500),
                            );
                            _onBack(index);
                          }
                        },
                ),
              ),
            if (widget.withProgress)
              Align(
                alignment: Alignment.center,
                child: Stack(
                  alignment: AlignmentDirectional.center,
                  children: <Widget>[
                    Container(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (int i = 0; i < widget.views.length; i++)
                            if (i == index) ...[circleBar(true)] else circleBar(false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.withNextAction)
              Align(
                alignment: Alignment.centerRight,
                child: FlatButton(
                  child: Text(index == widget.views.length - 1
                      ? (widget.isComplete(index) ? widget.completeActionText : widget.cancelActionText)
                      : widget.nextActionText),
                  onPressed: () async {
                    if (_hasNext(index)) {
                      controller.animateToPage(
                        index = min(widget.views.length - 1, ++index),
                        curve: Curves.linearToEaseOut,
                        duration: const Duration(milliseconds: 500),
                      );
                      _onNext(index);
                    } else if (widget.isComplete(index)) {
                      widget.onComplete(index);
                    } else {
                      widget.onCancel(index);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget circleBar(bool isActive) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 150),
      margin: EdgeInsets.symmetric(horizontal: 8),
      height: isActive ? 8 : 7,
      width: isActive ? 8 : 7,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Theme.of(context).primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
      ),
    );
  }

  void getChangedPageAndMoveBar(int page) {
    index = page;
    setState(() {});
  }

  void _onBack(int index) {
    if (widget.onBack != null) {
      widget.onBack(index);
    }
  }

  void _onNext(int index) {
    if (widget.onNext != null) {
      widget.onNext(index);
    }
  }

  bool _hasNext(int index) =>
      index < widget.views.length - 1 && (widget.hasNext == null ? true : widget.hasNext(index));
  bool _hasBack(int index) => index > 0 && (widget.hasBack == null ? true : widget.hasBack(index));
}
