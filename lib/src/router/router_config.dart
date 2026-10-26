import 'dart:math';

import 'package:winter/winter.dart';

/// What a router does with its routes when it's built. An invalid or duplicated route fails
/// (a [StateError]) by default: it's a bug of the app, better found at start than as a 404.
///
/// ```dart
/// WinterRouter(
///   routes: routes,
///   config: RouterConfig(onLoadedRoutes: DefaultOnLoadedRoutes.log()), // print the route table
/// );
/// ```
///
/// {@category Routing}
class RouterConfig {
  /// The hooks of a router; each one defaults to failing ([onInvalidUrl], [onDuplicatedRoute])
  /// or doing nothing ([onLoadedRoutes])
  RouterConfig({
    OnInvalidUrl? onInvalidUrl,
    OnLoadedRoutes? onLoadedRoutes,
    OnDuplicatedRoute? onDuplicatedRoute,
  }) : onInvalidUrl = onInvalidUrl ?? DefaultOnInvalidUrl.fail(),
       onLoadedRoutes = onLoadedRoutes ?? DefaultOnLoadedRoutes.ignore(),
       onDuplicatedRoute = onDuplicatedRoute ?? DefaultOnDuplicatedRoute.fail();

  /// Called with a route whose path is not a valid url
  final OnInvalidUrl onInvalidUrl;

  /// Called with every route once the router is built
  final OnLoadedRoutes onLoadedRoutes;

  /// Called with a route that has the same key, or the same method and path, as another one
  final OnDuplicatedRoute onDuplicatedRoute;
}

/// What to do with a route whose path is not a valid url (see [DefaultOnInvalidUrl])
///
/// {@category Routing}
typedef OnInvalidUrl = void Function(Route failedRoute);

/// The ready-made [OnInvalidUrl]s
///
/// {@category Routing}
class DefaultOnInvalidUrl {
  /// Drops the route, with a warning unless [log] is false
  static OnInvalidUrl ignore({bool log = true}) {
    return (failedRoute) {
      if (log) {
        logger.warning(
          '${failedRoute.path} is not a valid URL. Excluded from routing config',
        );
      }
    };
  }

  /// Throws a [StateError]: the router (and the start of the server) fails. The default.
  static OnInvalidUrl fail() {
    return (failedRoute) {
      throw StateError(
        '${failedRoute.path} is not a valid URL. Failing to start app',
      );
    };
  }
}

/// What to do with a route that could never be reached: another one has the same key, or the same
/// method and path (see [DefaultOnDuplicatedRoute])
///
/// {@category Routing}
typedef OnDuplicatedRoute = void Function(Route duplicatedRoute);

/// The ready-made [OnDuplicatedRoute]s
///
/// {@category Routing}
class DefaultOnDuplicatedRoute {
  /// Drops the second route, with a warning unless [log] is false
  static OnDuplicatedRoute ignore({bool log = true}) {
    return (duplicatedRoute) {
      if (log) {
        logger.warning(
          'Key: ${duplicatedRoute.key} / Method: ${duplicatedRoute.method?.name ?? 'PARENT'} / Path: ${duplicatedRoute.path} => is a duplicated route. Excluded from routing config',
        );
      }
    };
  }

  /// Throws a [StateError]: the router (and the start of the server) fails. The default.
  static OnDuplicatedRoute fail() {
    return (duplicatedRoute) {
      throw StateError(
        '${duplicatedRoute.method?.name.toUpperCase() ?? 'PARENT'} ${duplicatedRoute.path} '
        '(key: ${duplicatedRoute.key}) is a duplicated route: another one has the same key, or '
        'the same method and path. Failing to start app',
      );
    };
  }
}

/// Receives every route of a router once it's built (see [DefaultOnLoadedRoutes])
///
/// {@category Routing}
typedef OnLoadedRoutes = void Function(List<Route> allRoutes);

/// The ready-made [OnLoadedRoutes]
///
/// {@category Routing}
class DefaultOnLoadedRoutes {
  /// Does nothing. The default.
  static OnLoadedRoutes ignore() {
    return (allRoutes) {};
  }

  /// Logs the route table at info: a start line, one line per route with its method, path, key
  /// and filters, aligned in columns, and an end line. No line breaks nor terminal codes: the
  /// logger escapes them, and a JSON log keeps each route in its own entry
  static OnLoadedRoutes log() {
    return (allRoutes) {
      String methodOf(Route route) =>
          route.method?.name.toUpperCase() ?? 'PARENT';
      int widest(Iterable<String> texts) =>
          texts.fold(0, (width, text) => max(width, text.length));

      final methodWidth = widest(allRoutes.map(methodOf));
      final pathWidth = widest(allRoutes.map((route) => route.path));
      final keyWidth = widest(allRoutes.map((route) => route.key));

      logger.info('Routes log start ======================================');
      for (final route in allRoutes) {
        logger.info(
          '${methodOf(route).padRight(methodWidth)}  '
          '${route.path.padRight(pathWidth)}  '
          'key: ${route.key.padRight(keyWidth)}  '
          'filters: ${route.filterConfig}',
        );
      }
      logger.info('Routes log end ========================================');
    };
  }
}
