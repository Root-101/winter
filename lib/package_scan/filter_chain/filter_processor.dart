import 'dart:async';
import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter.dart';

class FilterProcessor {
  const FilterProcessor();

  Filter? processFilterFromClass(
    LibraryMirror libMirror,
    ClassMirror classMirror,
  ) {
    // Try to get the GlobalFilter annotation on the method
    GlobalFilter? globalFilter = classMirror.metadata
        .firstWhereOrNull(
          (metadata) => metadata.reflectee is GlobalFilter,
        )
        ?.reflectee;

    // If the annotation exists, process it
    if (globalFilter != null) {
      // Verify if the method is compatible with FunctionFilter
      if (!_isClassAFilter(classMirror)) {
        throw StateError(
          'Annotated class with @GlobalFilter should implement: "Filter"',
        );
      }
      if (!_hasDefaultConstructor(classMirror)) {
        //TODO: load this params from DI
        throw StateError(
          'Annotated class with @GlobalFilter should have en empty constructor: "YouFilterClass();"',
        );
      }
      return classMirror.newInstance(const Symbol(''), [], {}).reflectee;
    }
    return null;
  }

  bool _isClassAFilter(ClassMirror classMirror) {
    ClassMirror filterClassMirror = reflectClass(Filter);

    return classMirror.superinterfaces.any(
      (interfaceMirror) => interfaceMirror == filterClassMirror,
    );
  }

  bool _hasDefaultConstructor(ClassMirror classMirror) {
    return classMirror.declarations.values.any(
      (declaration) =>
          declaration is MethodMirror &&
          declaration.isConstructor &&
          declaration.constructorName == const Symbol('') &&
          declaration.parameters.isEmpty,
    );
  }

  Filter? processFilterFromMethod(
    LibraryMirror libMirror,
    MethodMirror methodMirror,
  ) {
    // Try to get the GlobalFilter annotation on the method
    GlobalFilter? globalFilter = methodMirror.metadata
        .firstWhereOrNull(
          (metadata) => metadata.reflectee is GlobalFilter,
        )
        ?.reflectee;

    // If the annotation exists, process it
    if (globalFilter != null) {
      // Verify if the method is compatible with FunctionFilter
      if (_isMethodCompatibleWithFunctionFilter(methodMirror)) {
        return FunctionAsFilter(
          functionFilter: (request, chain) => libMirror
              .invoke(methodMirror.simpleName, [request, chain]).reflectee,
        );
      } else {
        throw StateError(
          'Annotated functions with @GlobalFilter should be of type FunctionFilter: "FutureOr<ResponseEntity> Function(RequestEntity request, FilterChain chain)"',
        );
      }
    }
    return null;
  }

  bool _isMethodCompatibleWithFunctionFilter(MethodMirror methodMirror) {
    // Verificar que el número de parámetros sea 2
    if (methodMirror.parameters.length != 2) {
      return false;
    }

    // Verificar los tipos de los parámetros
    final firstParamType = methodMirror.parameters[0].type;
    final secondParamType = methodMirror.parameters[1].type;
    final returnType = methodMirror.returnType;

    if (firstParamType.reflectedType != RequestEntity ||
        secondParamType.reflectedType != FilterChain) {
      return false;
    }

    // Verificar el tipo de retorno
    if (!returnType.isSubtypeOf(reflectType(FutureOr)) ||
        !returnType.typeArguments.first
            .isAssignableTo(reflectType(ResponseEntity))) {
      return false;
    }

    return true;
  }
}
