import 'package:flutter/widgets.dart';

typedef MessageCallback = void Function(String message);
typedef SelectedCallback<T> = void Function(BuildContext context, T item);
typedef ItemWidgetBuilder<T> = Widget Function(BuildContext context, T item);
typedef PromptCallback = Future<bool> Function(String title, String message);
typedef ActionCallback<T> = void Function(String message, {String action, VoidCallback onPressed, T data});
typedef AsyncActionCallback<T> = Future Function(String message, {String action, VoidCallback onPressed, T data});
