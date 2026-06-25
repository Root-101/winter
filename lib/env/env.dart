import 'dart:io';

import 'package:collection/collection.dart';

class Env {
  final Map<String, String> _env;

  Env._(this._env);

  factory Env({Map<String, String>? env}) {
    return Env._({...Platform.environment, ...(env ?? {})});
  }

  Map<String, String> get all => Map.from(_env);

  String? find(String key, {bool caseSensitive = true}) {
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

  String put(String key, String value) {
    _env[key] = value;

    return find(key)!;
  }
}
