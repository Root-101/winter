import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter/winter.dart';

// Definir una anotación
class RequestBody {
  const RequestBody();
}

class RequestMapper {
  final String path;
  final String method;

  const RequestMapper({
    required this.path,
    required this.method,
  });
}

@RequestMapper(path: '/test', method: 'get')
ResponseEntity handler(@RequestBody() String body) {
  return ResponseEntity.ok(body: body);
}

void main() {
  Route? loadedRoute = route();
  if (loadedRoute != null) {
    WinterServer(
      config: ServerConfig(port: 8080),
      router: WinterRouter(
        routes: [
          loadedRoute,
        ],
      ),
    ).start();
  }
}

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
          RequestMapper? mapper = methodMirror.metadata
              .firstWhereOrNull(
                (metadata) => metadata.reflectee.runtimeType == RequestMapper,
              )
              ?.reflectee;
          if (mapper != null) {
            String method = mapper.method;
            String path = mapper.path;

            List<dynamic Function(RequestEntity request)>
                positionalArgumentsFunctions = [];
            for (var singleParam in methodMirror.parameters) {
              RequestBody? body = singleParam.metadata
                  .firstWhereOrNull(
                    (metadata) => metadata.reflectee.runtimeType == RequestBody,
                  )
                  ?.reflectee;
              if (body != null) {
                positionalArgumentsFunctions.add(
                  (request) => request.body<String>(),
                );
              }
            }
            return Route(
              path: path,
              method: HttpMethod(method),
              handler: (request) async {
                List<dynamic> args = [];
                for (var element in positionalArgumentsFunctions) {
                  args.add(await element(request));
                }

                return libMirror
                    .invoke(
                      methodMirror.simpleName,
                      args,
                    )
                    .reflectee;
              },
            );
          }
        } else if (declaration is ClassMirror) {
          // Verificar si la clase tiene la anotación MyAnnotation
          if (declaration.metadata.any(
              (metadata) => metadata.reflectee.runtimeType == RequestBody)) {
            print("Clase anotada encontrada: ${MirrorSystem.getName(symbol)}");
          }
        }
      }
    }
  }
  return null;
}
