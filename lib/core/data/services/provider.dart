import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// -----------------------------------------------
// This code is based on RepositoryProvider and
// related classes in the dart package
// https://pub.dev/packages/provider
// -----------------------------------------------

/// Mixin which allows `MultiServiceProvider` to infer the types
/// of multiple [ServiceProvider]s.
mixin ServiceProviderSingleChildWidget on SingleChildWidget {}

/// {@template serviceprovider}
/// Takes a `ValueBuilder` that is responsible for creating the service and
/// a [child] which will have access to the ervice via
/// `ServiceProvider.of(context)`.
/// It is used as a dependency injection (DI) widget so that a single instance
/// of a service can be provided to multiple widgets within a subtree.
///
/// Lazily creates the provided service unless [lazy] is set to `false`.
///
/// ```dart
/// ServiceProvider(
///   create: (context) => ServiceA(),
///   child: ChildA(),
/// );
/// ```
/// {@endtemplate}
class ServiceProvider<T> extends Provider<T> with ServiceProviderSingleChildWidget {
  /// {@macro serviceprovider}
  ServiceProvider({
    Key key,
    @required Create<T> create,
    Widget child,
    bool lazy,
  }) : super(
          key: key,
          create: create,
          dispose: (_, __) {},
          child: child,
          lazy: lazy,
        );

  /// Takes a service and a [child] which will have access to the service.
  /// A new service should not be created in `ServiceProvider.value`.
  /// Repositories should always be created using the default constructor
  /// within the [builder].
  ServiceProvider.value({
    Key key,
    @required T value,
    Widget child,
  }) : super.value(
          key: key,
          value: value,
          child: child,
        );

  /// Method that allows widgets to access a service instance as long as
  /// their `BuildContext` contains a [ServiceProvider] instance.
  static T of<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: false);
    } on ProviderNotFoundException catch (_) {
      throw FlutterError(
        """
        ServiceProvider.of() called with a context that does not contain a service of type $T.
        No ancestor could be found starting from the context that was passed to ServiceProvider.of<$T>().

        This can happen if the context you used comes from a widget above the ServiceProvider.

        The context used was: $context
        """,
      );
    }
  }
}

/// Extends the `BuildContext` class with the ability
/// to perform a lookup based on a service type.
extension ServiceProviderExtension on BuildContext {
  /// Performs a lookup using the `BuildContext` to obtain
  /// the nearest ancestor service of type [T].
  ///
  /// Calling this method is equivalent to calling:
  ///
  /// ```dart
  /// ServiceProvider.of<T>(context)
  /// ```
  T service<T>() => ServiceProvider.of<T>(this);
}

/// {@template multiserviceprovider}
/// Merges multiple [ServiceProvider] widgets into one widget tree.
///
/// [MultiServiceProvider] improves the readability and eliminates the need
/// to nest multiple [ServiceProvider]s.
///
/// By using [MultiServiceProvider] we can go from:
///
/// ```dart
/// ServiceProvider<ServiceA>(
///   create: (context) => ServiceA(),
///   child: ServiceProvider<ServiceB>(
///     create: (context) => ServiceB(),
///     child: ServiceProvider<ServiceC>(
///       create: (context) => ServiceC(),
///       child: ChildA(),
///     )
///   )
/// )
/// ```
///
/// to:
///
/// ```dart
/// MultiServiceProvider(
///   providers: [
///     ServiceProvider<ServiceA>(create: (context) => ServiceA()),
///     ServiceProvider<ServiceB>(create: (context) => ServiceB()),
///     ServiceProvider<ServiceC>(create: (context) => ServiceC()),
///   ],
///   child: ChildA(),
/// )
/// ```
///
/// [MultiServiceProvider] converts the [ServiceProvider] list into a tree
/// of nested [ServiceProvider] widgets.
/// As a result, the only advantage of using [MultiServiceProvider] is
/// improved readability due to the reduction in nesting and boilerplate.
/// {@endtemplate}
class MultiServiceProvider extends StatelessWidget {
  /// The [ServiceProvider] list which is converted into a tree of
  /// [ServiceProvider] widgets.
  /// The tree of [ServiceProvider] widgets is created in order meaning
  /// the first [ServiceProvider] will be the top-most [ServiceProvider]
  /// and the last [ServiceProvider] will be a direct ancestor of [child].
  final List<ServiceProviderSingleChildWidget> providers;

  /// The widget and its descendants which will have access to every value
  /// provided by [providers].
  /// [child] will be a direct descendent of the last [ServiceProvider] in
  /// [providers].
  final Widget child;

  /// {@macro multiserviceprovider}
  const MultiServiceProvider({
    Key key,
    @required this.providers,
    @required this.child,
  })  : assert(providers != null),
        assert(child != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers,
      child: child,
    );
  }
}
