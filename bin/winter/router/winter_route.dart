import '../winter.dart';

class ParentRoute extends Route {
  ParentRoute({
    required String path,
    required List<Route> routes,
  }) : super._(
          path,
          HttpMethod(''),
          (request) => ResponseEntity.ok(),
          routes,
        );
}

class Route {
  final String path;
  final HttpMethod method;
  final RequestHandler handler;

  final List<Route> routes;

  Route._(
    this.path,
    this.method,
    this.handler,
    this.routes,
  );

  factory Route({
    required String path,
    required HttpMethod method,
    required RequestHandler handler,
    List<Route> routes = const [],
  }) {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(
          path, 'path', 'expected route to start with a slash');
    }

    return Route._(
      path,
      method,
      handler,
      routes,
    );
  }

  bool match(String rawActualUrl) {
    // Separar las partes de la URL y los parámetros de consulta
    String templateUrlPath = path.split('?').first;
    String actualUrlPath = rawActualUrl.split('?').first;

    // Crear una expresión regular para encontrar los parámetros de ruta en la plantilla
    final RegExp pathParamPattern = RegExp(r'{([^}]+)}');

    // Crear una expresión regular para capturar los valores correspondientes en la URL real
    String regexPattern = templateUrlPath.replaceAllMapped(
        pathParamPattern, (match) => r'([^/?]+)');
    regexPattern = '^' + regexPattern + r'$'; // Añadir el inicio y el final

    // Comprobar si la parte de la URL coincide
    final RegExpMatch? matchUrlPath =
        RegExp(regexPattern).firstMatch(actualUrlPath);

    return matchUrlPath != null;
  }
}
