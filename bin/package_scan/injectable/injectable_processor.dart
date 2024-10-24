import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter.dart';

class InjectableProcessor {
  const InjectableProcessor();

  ({Object? dependency, String? tag}) processInjectableFromVariable(
    VariableMirror variableMirror,
  ) {
    // Try to get the GlobalFilter annotation on the method
    Injectable? injectable = variableMirror.metadata
        .firstWhereOrNull(
          (metadata) => metadata.reflectee is Injectable,
        )
        ?.reflectee;

    // If the annotation exists, process it
    if (injectable != null) {
      Object? value;

      // Verifica si el owner es un ClassMirror o un LibraryMirror
      var owner = variableMirror.owner;

      if (owner is ClassMirror) {
        // Accede al campo usando el nombre simple de la variable
        var fieldMirror = owner.getField(variableMirror.simpleName);
        value = fieldMirror.reflectee;
      } else if (owner is LibraryMirror) {
        // Para variables top-level
        value = owner.getField(variableMirror.simpleName).reflectee;
      }

      return (dependency: value, tag: injectable.tag);
    }

    return (dependency: null, tag: null);
  }

  ({Object? dependency, String? tag}) processInjectableFromMethod(
    MethodMirror methodMirror,
    DependencyInjection di,
  ) {
    // Try to get the GlobalFilter annotation on the method
    Injectable? injectable = methodMirror.metadata
        .firstWhereOrNull(
          (metadata) => metadata.reflectee is Injectable,
        )
        ?.reflectee;

    // If the annotation exists, process it
    if (injectable != null) {
      List<dynamic> positionalArgumentsFunctions = [];
      Map<Symbol, dynamic> namedArgumentsFunctions = {};
      for (var singleParam in methodMirror.parameters) {
        Type paramType = singleParam.type.reflectedType;

        Injected? injected = singleParam.metadata
            .firstWhereOrNull(
              (metadata) => metadata.reflectee is Injected,
            )
            ?.reflectee;

        String? paramTag = injected != null
            ? injected.tag
            : MirrorSystem.getName(singleParam.simpleName);

        var defaultValue = singleParam.hasDefaultValue
            ? singleParam.defaultValue?.reflectee
            : null;

        dynamic finalParam =
            di.findByType(paramType, tag: paramTag) ?? defaultValue;

        if (singleParam.isNamed) {
          namedArgumentsFunctions[singleParam.simpleName] = finalParam;
        } else {
          positionalArgumentsFunctions.add(finalParam);
        }
      }

      Object? value;

      // Verifica si el owner es un ClassMirror o un LibraryMirror
      var owner = methodMirror.owner;

      if (owner is LibraryMirror) {
        value = owner
            .invoke(
              methodMirror.simpleName,
              positionalArgumentsFunctions,
              namedArgumentsFunctions,
            )
            .reflectee;
      }

      return (dependency: value, tag: injectable.tag);
    }

    return (dependency: null, tag: null);
  }
}
