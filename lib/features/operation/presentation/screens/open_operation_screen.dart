import 'dart:async';

import 'package:SarSys/features/operation/presentation/pages/download_page.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/core/presentation/widgets/stepped_page.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/features/operation/presentation/pages/passcode_page.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';

typedef OpenCallback = Future<Personnel> Function(Operation operation, StreamSink<DownloadProgress> onProgress);

class OpenOperationScreen extends StatefulWidget {
  static const String ROUTE = 'open_operation';
  static const int PASSCODE = 0;
  static const int DOWNLOAD = 1;

  OpenOperationScreen({
    Key key,
    @required this.operation,
    @required this.onCancel,
    @required this.onDownload,
    @required this.onAuthorize,
  }) : super(key: key) {
    assert(operation != null, 'Operation is required');
  }

  final Operation operation;
  final OpenCallback onDownload;
  final ValueSetter<int> onCancel;
  final PasscodeCallback onAuthorize;

  @override
  _OpenOperationScreenState createState() => _OpenOperationScreenState();
}

class _OpenOperationScreenState extends State<OpenOperationScreen> {
  List<Widget> views;

  int _index = 0;

  Stream<DownloadProgress> get onProgress => _progressController.stream;
  StreamController<DownloadProgress> _progressController = StreamController.broadcast();

  bool get isAuthorized => context.bloc<UserBloc>().isAuthorized(widget.operation);

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    return SteppedScreen(
      views: views,
      index: _index,
      onNext: _onNext,
      withProgress: false,
      onCancel: _onCancel,
      hasBack: (_) => false,
      onComplete: _onComplete,
      isComplete: (_) => false,
      hasNext: (index) => isAuthorized || OpenOperationScreen.PASSCODE == _index,
    );
  }

  void _onNext(int step) async {
    // 'Next' on bottom bar was pressed?
    if (step == OpenOperationScreen.DOWNLOAD && step > _index) {
      _onOpen();
    }
    _index = step;
  }

  void _onOpen() async {
    final personnel = await widget.onDownload(
      widget.operation,
      _progressController.sink,
    );
    _onComplete(
      OpenOperationScreen.DOWNLOAD,
      personnel: personnel,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    views = [
      PasscodePage(
        operation: widget.operation,
        onAuthorize: widget.onAuthorize,
        onComplete: (result) => _onPasscode(
          result,
        ),
      ),
      DownloadPage(
        onProgress: _progressController.stream,
      ),
    ];
  }

  void _onPasscode(bool result) {
    if (result) {
      _onOpen();
      _deferNext(
        OpenOperationScreen.DOWNLOAD,
      );
    } else {
      _onCancel(
        OpenOperationScreen.PASSCODE,
      );
    }
  }

  Future<dynamic> _deferNext(int step) {
    return Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _index = step;
        });
      }
    });
  }

  @override
  void dispose() {
    if (_progressController.hasListener) {
      _progressController.close();
    }
    super.dispose();
  }

  void _onCancel(int step) {
    widget.onCancel(step);
    _onComplete(step);
  }

  void _onComplete(int step, {Personnel personnel}) {
    Navigator.pop(context, personnel);
  }
}
