import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter.dart';

class RouteProcessor {
  const RouteProcessor();

  Route? processRouteFromMethod(
    LibraryMirror libMirror,
    MethodMirror methodMirror,
    ObjectMapper objectMapper,
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
      FilterConfig? filterConfig = mapper.filterConfig;

      List<ParamExtractor> positionalArgumentsFunctions = [];
      Map<Symbol, ParamExtractor> namedArgumentsFunctions = {};
      for (var singleParam in methodMirror.parameters) {
        bool paramSuccessfullyExtracted = extractRuteParam(
          positionalArgumentsFunctions,
          namedArgumentsFunctions,
          singleParam,
          objectMapper,
        );

        if (!paramSuccessfullyExtracted) {
          throw StateError(
              'Param ${MirrorSystem.getName(singleParam.simpleName)} '
              'don\'t have any recognised annotation (or any at all)');
        }
      }

      return Route(
        path: path,
        method: method,
        filterConfig: filterConfig,
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
    return null;
  }

  bool extractRuteParam(
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
    bool processedRawRequest = processRouteRawRequest(
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

  bool processRouteRawRequest(
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
}
