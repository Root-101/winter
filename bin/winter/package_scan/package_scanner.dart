import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../winter.dart';

///Function used to extract a param, like the body or an header from a request
typedef ParamExtractor = dynamic Function(RequestEntity request);

class PackageScanner {
  final BuildContext context;
  final BasicRouter _router;
  final List<String> packageScan; //TODO: as a lib, always scan itself

  PackageScanner._(
    this._router, {
    required this.context,
    required this.packageScan,
  });

  factory PackageScanner({
    BuildContext? context,
    List<String>? packageScan,
    bool autoScan = true,
  }) {
    PackageScanner scanner = PackageScanner._(
      BasicRouter(),
      context: context ?? BuildContext(),
      packageScan: packageScan ?? [],
    );

    if (autoScan) {
      scanner.scan();
    }

    return scanner;
  }

  WinterRouter get router => _router;

  void scan() {
    // Obtener el MirrorSystem
    MirrorSystem mirrorSystem = currentMirrorSystem();

    // Iterar sobre todas las librerías cargadas
    for (var library in mirrorSystem.libraries.entries) {
      final uri = library.key;
      final libMirror = library.value;

      String uriPath = uri.toString();

      ///Dont scan if:
      ///1 - Is a dart package
      ///2 - Is an external package and it's not specified to scan it in `packageScan`'s list
      if (uriPath.startsWith('dart:') ||
          (uriPath.startsWith('package:') && !packageScan.contains(uriPath))) {
        continue;
      }
      for (var entry in libMirror.declarations.entries) {
        print('key: ${entry.key}, value: ${entry.value}');

        final declaration = entry.value;
        if (declaration is MethodMirror) {
          _processRouteFromMethod(libMirror, declaration);
        }
      }
    }
  }

  void _processRouteFromMethod(
    LibraryMirror libMirror,
    MethodMirror methodMirror,
  ) {
    ///try to get the RequestRoute annotation on method
    RequestRoute? mapper = methodMirror.metadata
        .firstWhereOrNull(
          (metadata) => metadata.reflectee is RequestRoute,
        )
        ?.reflectee;

    ///If there is this annotation process it
    ///Ignored if not (someone else will process it)
    if (mapper != null) {
      HttpMethod method = mapper.method;
      String path = mapper.path;

      List<ParamExtractor> positionalArgumentsFunctions = [];
      Map<Symbol, ParamExtractor> namedArgumentsFunctions = {};
      for (var singleParam in methodMirror.parameters) {
        bool paramSuccessfullyExtracted = _extractParam(
          positionalArgumentsFunctions,
          namedArgumentsFunctions,
          singleParam,
          context.objectMapper,
        );

        if (!paramSuccessfullyExtracted) {
          throw StateError(
              'Param ${MirrorSystem.getName(singleParam.simpleName)} '
              'don\'t have any recognised annotation (or any at all)');
        }
      }

      ///add route to router
      _router.add(
        path,
        method,
        (request) async {
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
  }
}

bool _extractParam(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
  ObjectMapper om,
) {
  ///Process request body
  bool processedBody = processBodyAnnotation(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
    om,
  );

  ///Process request header
  bool processedHeader = processHeaderAnnotation(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  ///Process raw request entity
  bool processedRawRequest = _processRawRequest(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  ///Process path param
  bool processedPathParam = processPathParamAnnotation(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  ///Process query param
  bool processedQueryParam = processQueryParamAnnotation(
    positionalArgumentsFunctions,
    namedArgumentsFunctions,
    singleParam,
  );

  return processedBody ||
      processedHeader ||
      processedRawRequest ||
      processedPathParam ||
      processedQueryParam;
}

bool _processRawRequest(
  List<ParamExtractor> positionalArgumentsFunctions,
  Map<Symbol, ParamExtractor> namedArgumentsFunctions,
  ParameterMirror singleParam,
) {
  bool isRequestEntity = singleParam.type.reflectedType == RequestEntity;

  if (isRequestEntity) {
    extractor(RequestEntity request) => request;

    if (singleParam.isNamed) {
      namedArgumentsFunctions[singleParam.simpleName] = extractor;
    } else {
      positionalArgumentsFunctions.add(extractor);
    }
  }
  return isRequestEntity;
}
