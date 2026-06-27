import 'dart:io';

import 'package:collection/collection.dart';

class Env {
  final Map<String, String> _env;

  Env._(this._env);

  factory Env({Map<String, String>? env}) {
    return Env._({...Platform.environment, ...(env ?? {})});
  }

  Map<String, String> get all => Map.from(_env);

  T? find<T>(String key, {bool caseSensitive = true, bool required = false}) {
    final StateError notFoundError = StateError('Env $key not found');
    StateError unsupportedTypeError(Type type) => StateError(
      'Trying to find env of \'${type.toString()}\', supported ones are: num, int, double, bool, String, List<num>, List<int>, List<double>, List<String>',
    );
    StateError wrongTypeError(String value, Type type) => StateError(
      'Env $key IS found with value \'$value\' but parse fail to type $type',
    );

    // 1. Obtener el valor crudo en String
    final String? rawFind = _rawFind(key, caseSensitive: caseSensitive);

    if (rawFind == null || rawFind.trim().isEmpty) {
      if (required) throw notFoundError;
      return null;
    }

    final String cleanValue = rawFind.trim();

    // 3. Evaluar y parsear según el tipo genérico T

    // ---- STRINGS ----
    if (T == String) {
      return cleanValue as T;
    }

    // ---- BOOLEANS ----
    if (T == bool) {
      if (cleanValue.toLowerCase() == 'true') return true as T;
      if (cleanValue.toLowerCase() == 'false') return false as T;
      throw wrongTypeError(cleanValue, T);
    }

    // ---- NÚMEROS ----
    if (T == num || T == int || T == double) {
      num? parsedNum = num.tryParse(cleanValue);
      if (parsedNum == null) throw wrongTypeError(cleanValue, T);

      if (T == int) return parsedNum.toInt() as T;
      if (T == double) return parsedNum.toDouble() as T;
      return parsedNum as T;
    }

    // ---- LISTAS (Aquí está la magia del split y el parseo) ----

    // Lista de Strings (ej: "admin,editor,user")
    if (T == List<String>) {
      final list = cleanValue.split(',').map((e) => e.trim()).toList();
      return list as T;
    }

    // Lista de Números (ej: "1, 2.5, 3, 4")
    bool listNum = T == List<num>;
    bool listInt = T == List<int>;
    bool listDouble = T == List<double>;
    bool listBool = T == List<bool>;
    if (listNum || listInt || listDouble || listBool) {
      final rawItems = cleanValue.split(',').map((e) => e.trim());

      try {
        if (listInt) {
          return rawItems.map((e) => int.parse(e)).toList() as T;
        }
        if (listDouble) {
          return rawItems.map((e) => double.parse(e)).toList() as T;
        }
        if (listBool) {
          return rawItems.map((e) => bool.parse(e)).toList() as T;
        }
        // Por defecto List<num>
        return rawItems.map((e) => num.parse(e)).toList() as T;
      } catch (_) {
        throw wrongTypeError(cleanValue, T);
      }
    }

    // Si llega aquí, es un tipo que no soportamos
    throw unsupportedTypeError(T);
  }

  String? _rawFind(String key, {bool caseSensitive = true}) {
    if (caseSensitive) {
      return _env[key];
    } else {
      return _env.entries
          .firstWhereOrNull(
            (element) => element.key.toLowerCase() == key.toLowerCase(),
          )
          ?.value;
    }
  }

  T put<T>(String key, T value) {
    String stringValue;

    if (value is List) {
      stringValue = value.join(',');
    } else {
      stringValue = value.toString();
    }

    _env[key] = stringValue;

    return find<T>(key, required: true)!;
  }
}
