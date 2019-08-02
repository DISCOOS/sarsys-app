import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';

typedef LabelTransformer = List<Widget> Function();

class LabelingOptions extends LayerOptions {
  final LabelTransformer transformer;

  LabelingOptions({
    @required this.transformer,
    Stream<void> rebuild,
  }) : super(rebuild: rebuild);

  List<Widget> get labels => transformer();
}
