import '../winter.dart';

class RouterConfig {
  RouterConfig({
    OnInvalidUrl? onInvalidUrl,
    OnLoadedRoutes? onLoadedRoutes,
  })  : onInvalidUrl = onInvalidUrl ?? OnInvalidUrl.ignore(),
        onLoadedRoutes = onLoadedRoutes ?? OnLoadedRoutes.log();

  final OnInvalidUrl onInvalidUrl;
  final OnLoadedRoutes onLoadedRoutes;
}

class OnInvalidUrl {
  final void Function(Route failedRoute) onInvalid;

  OnInvalidUrl(this.onInvalid);

  factory OnInvalidUrl.ignore({bool log = true}) {
    return OnInvalidUrl(
      (failedRoute) {
        if (log) {
          print(
              '${failedRoute.path} is not a valid URL. Excluded from routing config');
        }
      },
    );
  }

  factory OnInvalidUrl.fail() {
    return OnInvalidUrl(
      (failedRoute) {
        throw StateError(
            '${failedRoute.path} is not a valid URL. Failing to start app');
      },
    );
  }
}

class OnLoadedRoutes {
  final void Function(List<Route> allRoutes) afterInit;

  OnLoadedRoutes(this.afterInit);

  factory OnLoadedRoutes.ignore() {
    return OnLoadedRoutes(
      (allRoutes) {},
    );
  }

  factory OnLoadedRoutes.log() {
    return OnLoadedRoutes(
      (allRoutes) {
        print('');
        print('Routes:');
        for (var element in allRoutes) {
          print('${element.method.name.toUpperCase()}:    ${element.path}    ${element.filterConfig}');
        }
        print('');
      },
    );
  }
}
