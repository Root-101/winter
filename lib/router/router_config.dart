import 'dart:io';

import 'package:winter/winter.dart';

class RouterConfig {
  RouterConfig({
    OnInvalidUrl? onInvalidUrl,
    OnLoadedRoutes? onLoadedRoutes,
    OnDuplicatedRoute? onDuplicatedRoute,
  }) : onInvalidUrl = onInvalidUrl ?? DefaultOnInvalidUrl.ignore(),
       onLoadedRoutes = onLoadedRoutes ?? DefaultOnLoadedRoutes.ignore(),
       onDuplicatedRoute =
           onDuplicatedRoute ?? DefaultOnDuplicatedRoute.ignore();

  final OnInvalidUrl onInvalidUrl;
  final OnLoadedRoutes onLoadedRoutes;
  final OnDuplicatedRoute onDuplicatedRoute;
}

typedef OnInvalidUrl = void Function(Route failedRoute);

class DefaultOnInvalidUrl {
  static OnInvalidUrl ignore({bool log = true}) {
    return (failedRoute) {
      if (log) {
        stdout.writeln(
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

typedef OnDuplicatedRoute = void Function(Route duplicatedRoute);

class DefaultOnDuplicatedRoute {
  static OnDuplicatedRoute ignore({bool log = true}) {
    return (duplicatedRoute) {
      if (log) {
        stdout.writeln(
          'Key: ${duplicatedRoute.key} / Method: ${duplicatedRoute.method?.name ?? 'PARENT'} / Path: ${duplicatedRoute.path} => is a duplicated route. Excluded from routing config',
        );
      }
    };
  }

  static OnDuplicatedRoute fail() {
    return (duplicatedRoute) {
      throw StateError(
        '${duplicatedRoute.key} is a duplicated route. Failing to start app',
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
      stdout.writeln('');
      stdout.writeln('Routes:');

      final int defaultPad = 5;
      // 1. Encontramos dinámicamente las longitudes máximas
      int maxKeyLen = 0;
      int maxMethodLen = 6; // 'METHOD' por defecto mínimo
      int maxPathLen = 0;

      for (var element in allRoutes) {
        if (element.key.length > maxKeyLen) {
          maxKeyLen = element.key.length;
        }

        final methodText = element.method != null
            ? element.method!.name
            : 'PARENT';
        if (methodText.length > maxMethodLen) {
          maxMethodLen = methodText.length;
        }

        if (element.path.length > maxPathLen) {
          maxPathLen = element.path.length;
        }
      }

      // 2. Imprimimos las rutas con su espaciado dinámico
      for (var element in allRoutes) {
        final methodText = element.method != null
            ? element.method!.name.toUpperCase()
            : 'PARENT';

        // Aplicamos el padding usando el tamaño máximo detectado
        final formattedMethod = methodText
            .padRight(maxMethodLen + defaultPad)
            .stylize(bold: true);
        final formattedKey = element.key.padRight(maxKeyLen + defaultPad);
        final formattedPath = element.path.padRight(maxPathLen + defaultPad);
        final formattedFilters = '${element.filterConfig}';

        stdout.writeln(
          'Key: ${formattedKey.stylize(bold: true)}  Method: ${formattedMethod.stylize(bold: true)}  Path: ${formattedPath.stylize(bold: true)}  Filters: ${formattedFilters.stylize(bold: true)}',
        );
      }
      stdout.writeln('');
    };
  }
}
