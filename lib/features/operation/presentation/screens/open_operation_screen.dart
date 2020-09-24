import 'package:SarSys/core/presentation/widgets/stepped_page.dart';
import 'package:SarSys/features/operation/presentation/pages/passcode_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';

class OpenOperationScreen extends StatefulWidget {
  static const String ROUTE = 'open_operation';

  OpenOperationScreen({
    Key key,
    @required this.operation,
  }) : super(key: key) {
    assert(operation != null, 'Operation is required');
  }

  final Operation operation;

  @override
  _OpenOperationScreenState createState() => _OpenOperationScreenState();
}

class _OpenOperationScreenState extends State<OpenOperationScreen> {
  List<Widget> views;

  @override
  Widget build(BuildContext context) {
    return SteppedScreen(
      views: views,
      onNext: (_) {},
      withProgress: false,
      onCancel: (_) => Navigator.pop(context),
      onComplete: (_) => Navigator.pop(context),
      isComplete: (_) => context.bloc<UserBloc>().isAuthorized(widget.operation),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    views = [
      PasscodePage(operation: widget.operation),
    ];
  }
}
