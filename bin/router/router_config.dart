import '../winter.dart';
import 'dart:developer' as dev;

class RouterConfig {
  RouterConfig({
    OnInvalidUrl? onInvalidUrl,
    OnLoadedRoutes? onLoadedRoutes,
  })  : onInvalidUrl = onInvalidUrl ?? DefaultOnInvalidUrl.ignore(),
        onLoadedRoutes = onLoadedRoutes ?? DefaultOnLoadedRoutes.ignore();

  final OnInvalidUrl onInvalidUrl;
  final OnLoadedRoutes onLoadedRoutes;
}

typedef OnInvalidUrl = void Function(Route failedRoute);

class DefaultOnInvalidUrl {
  static OnInvalidUrl ignore({bool log = true}) {
    return (failedRoute) {
      if (log) {
        dev.log(
          '${failedRoute.path} is not a valid URL. Excluded from routing config',
        );
      }
    };
  }

  static OnInvalidUrl fail() {
    return (failedRoute) {
      throw StateError(
        '${failedRoute.path} is not a valid URL. Failing to start app',
      );
    };
  }
}

typedef OnLoadedRoutes = void Function(List<Route> allRoutes);

class DefaultOnLoadedRoutes {
  static OnLoadedRoutes ignore() {
    return (allRoutes) {};
  }

  static OnLoadedRoutes log() {
    return (allRoutes) {
      dev.log('');
      dev.log('Routes:');
      for (var element in allRoutes) {
        dev.log(
            '${element.method.name.toUpperCase()}:    ${element.path}    ${element.filterConfig}');
      }
      dev.log('');
    };
  }
}
