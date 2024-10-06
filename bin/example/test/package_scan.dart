import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter/winter.dart';

// Definir una anotación
class RequestBody {
  const RequestBody();
}

class RequestRoute {
  final String path;
  final String method;

  const RequestRoute({
    required this.path,
    required this.method,
  });
}

class GetRoute extends RequestRoute {
  const GetRoute({required super.path}) : super(method: 'GET');
}

class RequestHeader {
  final String headerName;

  const RequestHeader({
    required this.headerName,
  });
}

@GetRoute(path: '/test')
//@RequestRoute(path: '/test', method: 'get')
ResponseEntity handler({
  @RequestBody() String body = 'body',
  @RequestHeader(headerName: 'abc') String headerAbc = 'abc',
}) {
  return ResponseEntity.ok(body: 'Body: $body, header: $headerAbc');
}

void main() {
  Route? loadedRoute = route();
  if (loadedRoute != null) {
    WinterServer(
      config: ServerConfig(port: 8080),
      router: BasicRouter(
        routes: [
          loadedRoute,
        ],
      ),
    ).start();
  }
}

typedef ParamExtractor = dynamic Function(RequestEntity request);

Route? route() {
  // Obtener el MirrorSystem
  MirrorSystem mirrorSystem = currentMirrorSystem();

  // Iterar sobre todas las librerías cargadas
  for (var entry in mirrorSystem.libraries.entries) {
    final uri = entry.key;
    final libMirror = entry.value;
    if (uri.toString().contains('package_scan.dart')) {
      for (var entry2 in libMirror.declarations.entries) {
        final symbol = entry2.key;
        final declaration = entry2.value;
        if (declaration is MethodMirror) {
          MethodMirror methodMirror = declaration;
          RequestRoute? mapper = methodMirror.metadata
              .firstWhereOrNull(
                (metadata) => metadata.reflectee is RequestRoute,
              )
              ?.reflectee;
          if (mapper != null) {
            String method = mapper.method;
            String path = mapper.path;

            List<ParamExtractor> positionalArgumentsFunctions = [];
            Map<Symbol, ParamExtractor> namedArgumentsFunctions = {};
            for (var singleParam in methodMirror.parameters) {
              bool paramSuccessfullyExtracted = extractParam(
                positionalArgumentsFunctions,
                namedArgumentsFunctions,
                singleParam,
              );

              if (!paramSuccessfullyExtracted) {
                throw StateError(
                    'Param ${singleParam.simpleName} don\'t have any recognised annotation (or any at all)');
              }
            }

            return Route(
              path: path,
              method: HttpMethod(method),
              handler: (request) async {
                List<dynamic> posArgs = [];
                for (var element in positionalArgumentsFunctions) {
                  posArgs.add(await element(request));
                }

                Map<Symbol, dynamic> namedArgs = {};
                for (var entry in namedArgumentsFunctions.entries) {
                  namedArgs[entry.key] = await entry.value(request);
                }

                return libMirror
                    .invoke(
                      methodMirror.simpleName,
                      posArgs,
                      namedArgs,
                    )
                    .reflectee;
              },
            );
          }
        } /*else if (declaration is ClassMirror) {
          // Verificar si la clase tiene la anotación MyAnnotation
          if (declaration.metadata.any(
              (metadata) => metadata.reflectee.runtimeType == RequestBody)) {
            print("Clase anotada encontrada: ${MirrorSystem.getName(symbol)}");
          }
        }*/
      }
    }
  }
  return null;
}

bool extractParam(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
) {
  //Process request body
  bool processedBody = _processRequestBody(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  //Process request header
  bool processedHeader = _processRequestHeader(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  return processedBody || processedHeader;
}

bool _processRequestBody(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
) {
  RequestBody? body = singleParam.metadata
      .firstWhereOrNull(
        (metadata) => metadata.reflectee.runtimeType == RequestBody,
      )
      ?.reflectee;
  if (body != null) {
    bool isRequired = !singleParam.isOptional;

    var defaultValue = singleParam.hasDefaultValue
        ? singleParam.defaultValue?.reflectee
        : null;

    extractor(request) => isRequired
        ? request.body<String>()
        : request.body<String>() ?? defaultValue;

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return body != null;
}

bool _processRequestHeader(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
) {
  //Process request body
  RequestHeader? header = singleParam.metadata
      .firstWhereOrNull(
        (metadata) => metadata.reflectee.runtimeType == RequestHeader,
      )
      ?.reflectee;
  if (header != null) {
    bool isRequired = !singleParam.isOptional;

    var defaultValue = singleParam.hasDefaultValue
        ? singleParam.defaultValue?.reflectee
        : null;

    extractor(request) => isRequired
        ? request.headers[header.headerName]
        : request.headers[header.headerName] ?? defaultValue;

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return header != null;
}
