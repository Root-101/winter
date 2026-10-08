import 'package:winter/winter.dart';

/// What a router does with its routes when it's built. An invalid or duplicated route fails
/// (a [StateError]) by default: it's a bug of the app, better found at start than as a 404.
class RouterConfig {
  RouterConfig({
    OnInvalidUrl? onInvalidUrl,
    OnLoadedRoutes? onLoadedRoutes,
    OnDuplicatedRoute? onDuplicatedRoute,
  }) : onInvalidUrl = onInvalidUrl ?? DefaultOnInvalidUrl.fail(),
       onLoadedRoutes = onLoadedRoutes ?? DefaultOnLoadedRoutes.ignore(),
       onDuplicatedRoute = onDuplicatedRoute ?? DefaultOnDuplicatedRoute.fail();

  final OnInvalidUrl onInvalidUrl;
  final OnLoadedRoutes onLoadedRoutes;
  final OnDuplicatedRoute onDuplicatedRoute;
}

typedef OnInvalidUrl = void Function(Route failedRoute);

class DefaultOnInvalidUrl {
  static OnInvalidUrl ignore({bool log = true}) {
    return (failedRoute) {
      if (log) {
        logger.warning(
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
        logger.warning(
          'Key: ${duplicatedRoute.key} / Method: ${duplicatedRoute.method?.name ?? 'PARENT'} / Path: ${duplicatedRoute.path} => is a duplicated route. Excluded from routing config',
        );
      }
    };
  }

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

typedef OnLoadedRoutes = void Function(List<Route> allRoutes);

class DefaultOnLoadedRoutes {
  static OnLoadedRoutes ignore() {
    return (allRoutes) {};
  }

  static OnLoadedRoutes log() {
    return (allRoutes) {
      final StringBuffer log = StringBuffer()
        ..writeln('Routes log start ======================================');

      final int defaultPad = 5;
      // 1. Find the max length of every column
      int maxKeyLen = 0;
      int maxMethodLen = 6; // At least the length of 'METHOD'
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

      // 2. Print the routes aligned by those lengths
      for (var element in allRoutes) {
        final methodText = element.method != null
            ? element.method!.name.toUpperCase()
            : 'PARENT';

        // Pad using the max length found
        final formattedMethod = methodText
            .padRight(maxMethodLen + defaultPad)
            .stylize(bold: true);
        final formattedKey = element.key.padRight(maxKeyLen + defaultPad);
        final formattedPath = element.path.padRight(maxPathLen + defaultPad);
        final formattedFilters = '${element.filterConfig}';

        log
          ..writeln('Key: ${formattedKey.stylize(bold: true)}')
          ..writeln('Method: ${formattedMethod.stylize(bold: true)}')
          ..writeln('Path: ${formattedPath.stylize(bold: true)}')
          ..writeln('Filters:')
          ..writeln(formattedFilters.stylize(bold: true))
          ..writeln('');
      }

      log.write('Routes log end ========================================');
      logger.info(log.toString());
    };
  }
}
