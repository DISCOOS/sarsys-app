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
import 'dart:math';

typedef OpenCallback = Future<Personnel> Function(Operation operation, StreamSink<DownloadProgress> onProgress);

class OpenOperationScreen extends StatefulWidget {
  static const String ROUTE = 'open_operation';
  static const int PASSCODE = 1;
  static const int DOWNLOAD = 2;

  OpenOperationScreen(
      {Key key,
      @required this.onCancel,
      @required this.operation,
      @required this.onDownload,
      @required this.onAuthorize,
      @required this.requirePasscode})
      : super(key: key) {
    assert(operation != null, 'Operation is required');
  }

  final Operation operation;
  final OpenCallback onDownload;
  final ValueSetter<int> onCancel;
  final PasscodeCallback onAuthorize;
  final int requirePasscode;

  @override
  _OpenOperationScreenState createState() => _OpenOperationScreenState();
}

class _OpenOperationScreenState extends State<OpenOperationScreen> {
  List<Widget> views;

  int _index = 0;

  final ValueNotifier _onVerify = ValueNotifier<bool>(true);

  Stream<DownloadProgress> get onProgress => _progressController.stream;
  StreamController<DownloadProgress> _progressController = StreamController.broadcast();

  bool get isAuthorized => context.read<UserBloc>().isAuthorized(widget.operation);

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    if (widget.requirePasscode == 1) {
      _onDownload();
    }
    return SteppedScreen(
      views: views,
      index: max(widget.requirePasscode, _index),
      onNext: _onNext,
      canScroll: false,
      withProgress: false,
      onCancel: _onCancel,
      withBackAction: false,
      hasBack: (_) => false,
      enableAutoScroll: true,
      onComplete: _onComplete,
      isComplete: (_) => false,
      hasNext: (index) => isAuthorized,
    );
  }

  void _onNext(int step) async {
    if (step > _index) {
      switch (step) {
        case OpenOperationScreen.DOWNLOAD:
          if (isAuthorized) {
            _onDownload();
          } else {
            _onVerify.value = true;
          }
          break;
        default:
          _deferNext(OpenOperationScreen.PASSCODE);
      }
    }
  }

  void _onDownload() async {
    _index = OpenOperationScreen.DOWNLOAD;
    final personnel = await widget.onDownload(
      widget.operation,
      _progressController.sink,
    );
    if (mounted) {
      _onComplete(
        _index,
        personnel: personnel,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    views = [
      PasscodePage(
        onVerify: _onVerify,
        operation: widget.operation,
        onComplete: _onPasscodeChange,
        onAuthorize: widget.onAuthorize,
      ),
      DownloadPage(
        onProgress: _progressController.stream,
      ),
    ];
  }

  void _onPasscodeChange(bool validated) {
    if (validated) {
      _onDownload();
      _deferNext(
        OpenOperationScreen.DOWNLOAD,
      );
    } else {
      _onCancel(
        OpenOperationScreen.PASSCODE,
      );
    }
  }

  void _deferNext(int step) {
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _index = step;
          _onVerify.value = true;
        });
      }
    });
  }

  @override
  void dispose() {
    if (_progressController.hasListener) {
      _progressController.close();
    }
    _onVerify.dispose();
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
