

import 'package:flutter/material.dart';

class StreamBuilderWidget<T> extends StatelessWidget {
  const StreamBuilderWidget({
    Key? key,
    required this.stream,
    required this.builder,
    this.initialData,
  }) : assert(builder != null);

  final T? initialData;
  final Stream<T> stream;
  final Function(BuildContext, T?) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
        stream: stream,
        initialData: initialData,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.active:
            case ConnectionState.done:
              return builder(context, snapshot.data);
            case ConnectionState.none:
            case ConnectionState.waiting:
              if ((initialData ?? snapshot.data) != null) {
                return builder(context, snapshot.data);
              }
              break;
          }
          final children = <Widget>[
            if (snapshot.hasData)
              SizedBox(
                child: CircularProgressIndicator(),
                width: 60,
                height: 60,
              ),
            if (snapshot.hasError) Text('${snapshot.error}'),
          ];
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          );
        });
  }
}
