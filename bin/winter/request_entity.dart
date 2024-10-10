import 'package:shelf/shelf.dart';

import 'winter.dart';

class RequestEntity extends Request {
  late final Map<String, String> pathParams;
  late final Map<String, String> queryParams;

  late final String templateUrl;

  RequestEntity(
    super.method,
    super.requestedUri, {
    super.protocolVersion,
    super.headers,
    super.handlerPath,
    super.url,
    super.body,
    super.encoding,
    super.context,
  }) {
    queryParams = _extractQueryParams(requestedUri.toString());
  }

  HttpMethod get httpMethod => HttpMethod(method);

  void setUpPathParams(String template) {
    templateUrl = template;
    pathParams = _extractPathParams(
      templateUrl,
      requestedUri.toString(),
    );
  }

  Future<T?> body<T>({ObjectMapper? om}) async {
    if (_cachedBody == null || _cachedBody is! T) {
      String rawString = await readAsString(encoding);
      _cachedBody = (om ?? WinterServer.instance.context.objectMapper)
          .deserialize<T>(rawString);
    }
    return _cachedBody as T;
  }

  Object? _cachedBody;
}

Map<String, String> _extractPathParams(String templateUrl, String actualUrl) {
  actualUrl = Uri.parse(actualUrl).path; //remove http(s)://domain.com

  // Separar la parte de la URL que contiene los parámetros de consulta (si existe)
  String templateUrlPath = templateUrl.split('?').first;
  String actualUrlPath = actualUrl.split('?').first;

  // Crear una expresión regular para encontrar los parámetros de ruta en la plantilla
  final RegExp pathParamPattern = RegExp(r'{([^}]+)}');

  // Crear una expresión regular para capturar los valores correspondientes en la URL real
  String regexPattern = templateUrlPath.replaceAllMapped(
      pathParamPattern, (match) => r'([^/?]+)');

  // Añadir el inicio (^) y el final opcional ($) para asegurar una coincidencia completa
  regexPattern = '^' + regexPattern;

  // Encontrar los valores de los parámetros de ruta en la URL real
  final RegExpMatch? matchUrl = RegExp(regexPattern).firstMatch(actualUrlPath);

  Map<String, String> pathParam = {};
  Iterable<RegExpMatch> matches = pathParamPattern.allMatches(templateUrlPath);

  int index = 1;
  for (final RegExpMatch match in matches) {
    String paramName = match.group(1)!;
    String paramValue = matchUrl?.group(index++) ?? '';
    pathParam[paramName] = paramValue;
  }

  return pathParam;
}

Map<String, String> _extractQueryParams(String actualUrl) {
  Uri uri = Uri.parse(actualUrl);
  return Map.of(uri.queryParameters);
}
