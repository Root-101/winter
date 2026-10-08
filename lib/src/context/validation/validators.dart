import 'package:winter/src/i18n/winter_messages.dart';
import 'package:winter/winter.dart';

/// The validators of Winter, as extensions on [FieldValidator] for the type of the value.
///
/// - Every one except `notNull()` passes on `null`.
/// - Without `message`, the text is the one of Winter in the language of the request
///   (`requestLocale`), and the violation has a `code` (the key of the text) and its `params`.
/// - With `stopOnFailure`, a failure skips the next validators of the field.

/// Messages of Winter in the language of the request in progress, like the `t` of an app
WinterMessages get _intl => winterMessages(requestLocale);

/// For any type of value
extension CommonValidators<T> on FieldValidator<T> {
  /// The value is not null. By default a null value stops the validation of the field.
  FieldValidator<T> notNull({String? message, bool stopOnFailure = true}) =>
      addRule(
        (value) => value != null,
        message: () => message ?? _intl.errors.validations.notNull,
        code: 'notNull',
        stopOnFailure: stopOnFailure,
      );

  /// A rule of its own: [rule] returns the message of the violation, or null when the value is
  /// valid. Give it a [code] (and [params]) if clients need one.
  FieldValidator<T> custom(
    String? Function(T value) rule, {
    String? code,
    Map<String, Object?> params = const {},
    bool stopOnFailure = false,
  }) {
    // The rule runs inside addRule, so it's skipped when a previous rule stopped the field
    String? failure;
    return addRule(
      (value) => (failure = rule(value)) == null,
      message: () => failure!,
      code: code,
      params: params,
      stopOnFailure: stopOnFailure,
    );
  }

  /// The value is one of [values] (compared with `==`)
  FieldValidator<T> oneOf(
    Iterable<T> values, {
    String? message,
    bool stopOnFailure = false,
  }) {
    final List<T> allowed = values.toList();
    return addRule(
      (value) => value == null || allowed.contains(value),
      message: () =>
          message ??
          _intl.errors.validations.oneOf(values: _joinValues(allowed)),
      code: 'oneOf',
      params: {'values': _jsonValues(allowed)},
      stopOnFailure: stopOnFailure,
    );
  }

  /// The value is the name of one of the [values] of an enum, or what [resolver] gives for it
  /// (to compare with another property). For a body already deserialized as the enum
  /// (`Deserializer<E>.enumByName`), this check is not needed.
  FieldValidator<T> isEnum<E extends Enum>(
    Iterable<E> values, {
    Object? Function(E value)? resolver,
    String? message,
    bool stopOnFailure = false,
  }) {
    final List<Object?> allowed = [
      for (final value in values) resolver?.call(value) ?? value.name,
    ];
    return addRule(
      (value) => value == null || allowed.contains(value),
      message: () =>
          message ??
          _intl.errors.validations.isEnum(values: _joinValues(allowed)),
      code: 'isEnum',
      params: {'values': _jsonValues(allowed)},
      stopOnFailure: stopOnFailure,
    );
  }
}

String _joinValues(Iterable<Object?> values) => _jsonValues(values).join(', ');

/// The values for the `params` of a violation, that are serialized in the 422: JSON values as they
/// are, an enum as its name and anything else as its text, so an object without `toJson()` never
/// turns the 422 into a 500
List<Object?> _jsonValues(Iterable<Object?> values) => [
  for (final value in values)
    switch (value) {
      null || String() || num() || bool() => value,
      Enum() => value.name,
      _ => '$value',
    },
];

/// Same rules as the HTML5 spec (WHATWG) for `<input type="email">`, but requiring a dot in the domain
/// (the lengths, 254 in total and 64 for the local part, are checked apart):
/// - local part: letters, digits and the special characters allowed by the spec (so `user+tag@x.com` is valid)
/// - domain: labels of letters, digits and `-` (not at the start/end of the label), any TLD length
final RegExp _emailRegex = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+"
  r'@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
);

final RegExp _uuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-([0-9a-fA-F])[0-9a-fA-F]{3}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

final RegExp _whitespace = RegExp(r'\s');

/// The regular expressions given as a String, compiled once
final Map<String, RegExp> _patterns = {};

/// For a String
extension StringValidators<T extends String?> on FieldValidator<T> {
  /// The value is not empty nor only whitespace
  FieldValidator<T> notBlank({String? message, bool stopOnFailure = false}) =>
      addRule(
        (value) => value == null || value.trim().isNotEmpty,
        message: () => message ?? _intl.errors.validations.notBlank,
        code: 'notBlank',
        stopOnFailure: stopOnFailure,
      );

  /// The length is between [min] and [max] (both inclusive)
  FieldValidator<T> size({
    int? min,
    int? max,
    String? message,
    bool stopOnFailure = false,
  }) => _size(this, value?.length, min, max, message, stopOnFailure);

  /// The value is an email: the rules of `<input type="email">`, with a dot in the domain, and
  /// the lengths of RFC 5321 (254 characters in total, 64 before the `@`)
  FieldValidator<T> email({String? message, bool stopOnFailure = false}) =>
      addRule(
        (value) =>
            value == null ||
            (value.length <= 254 &&
                value.indexOf('@') <= 64 &&
                _emailRegex.hasMatch(value)),
        message: () => message ?? _intl.errors.validations.email,
        code: 'email',
        stopOnFailure: stopOnFailure,
      );

  /// The value has a match of [pattern]: a [RegExp] (used as it is, flags included), a String
  /// with a regular expression (compiled once), or any other [Pattern]. Anchor a regular
  /// expression (`^...$`) to match the whole value.
  FieldValidator<T> pattern(
    Pattern pattern, {
    String? message,
    bool stopOnFailure = false,
  }) {
    final bool Function(String value) matches = switch (pattern) {
      RegExp() => pattern.hasMatch,
      String() => (_patterns[pattern] ??= RegExp(pattern)).hasMatch,
      _ => (value) => pattern.allMatches(value).isNotEmpty,
    };
    return addRule(
      (value) => value == null || matches(value),
      message: () => message ?? _intl.errors.validations.pattern,
      code: 'pattern',
      stopOnFailure: stopOnFailure,
    );
  }

  /// The value is an absolute URL with one of the [schemes] and a host, without whitespace
  FieldValidator<T> url({
    List<String> schemes = const ['http', 'https'],
    String? message,
    bool stopOnFailure = false,
  }) => addRule(
    (value) {
      if (value == null) return true;
      // Uri.tryParse accepts a space in the host (`http://exa mple.com`)
      if (value.contains(_whitespace)) return false;
      final Uri? uri = Uri.tryParse(value);
      return uri != null &&
          schemes.contains(uri.scheme.toLowerCase()) &&
          uri.host.isNotEmpty;
    },
    message: () => message ?? _intl.errors.validations.url,
    code: 'url',
    params: {'schemes': schemes},
    stopOnFailure: stopOnFailure,
  );

  /// The value is a UUID (`8-4-4-4-12` hexadecimal digits), of the given [version] if any
  FieldValidator<T> uuid({
    int? version,
    String? message,
    bool stopOnFailure = false,
  }) => addRule(
    (value) {
      if (value == null) return true;
      final match = _uuidRegex.firstMatch(value);
      return match != null &&
          (version == null || match[1] == version.toRadixString(16));
    },
    message: () => message ?? _intl.errors.validations.uuid,
    code: 'uuid',
    params: {'version': ?version},
    stopOnFailure: stopOnFailure,
  );
}

/// For a number
extension NumberValidators<T extends num?> on FieldValidator<T> {
  /// The value is at least [min] (`inclusive`, the default) or greater than [min]
  FieldValidator<T> min(
    num min, {
    String? message,
    bool inclusive = true,
    bool stopOnFailure = false,
  }) => addRule(
    (value) => value == null || (inclusive ? value >= min : value > min),
    message: () =>
        message ??
        (inclusive
            ? _intl.errors.validations.min.inclusive(value: min)
            : _intl.errors.validations.min.exclusive(value: min)),
    code: inclusive ? 'min.inclusive' : 'min.exclusive',
    params: {'value': min},
    stopOnFailure: stopOnFailure,
  );

  /// The value is at most [max] (`inclusive`, the default) or less than [max]
  FieldValidator<T> max(
    num max, {
    String? message,
    bool inclusive = true,
    bool stopOnFailure = false,
  }) => addRule(
    (value) => value == null || (inclusive ? value <= max : value < max),
    message: () =>
        message ??
        (inclusive
            ? _intl.errors.validations.max.inclusive(value: max)
            : _intl.errors.validations.max.exclusive(value: max)),
    code: inclusive ? 'max.inclusive' : 'max.exclusive',
    params: {'value': max},
    stopOnFailure: stopOnFailure,
  );

  /// The value is greater than 0
  FieldValidator<T> positive({String? message, bool stopOnFailure = false}) =>
      addRule(
        (value) => value == null || value > 0,
        message: () => message ?? _intl.errors.validations.positive,
        code: 'positive',
        stopOnFailure: stopOnFailure,
      );

  /// The value is 0 or greater
  FieldValidator<T> positiveOrZero({
    String? message,
    bool stopOnFailure = false,
  }) => addRule(
    (value) => value == null || value >= 0,
    message: () => message ?? _intl.errors.validations.positiveOrZero,
    code: 'positiveOrZero',
    stopOnFailure: stopOnFailure,
  );

  /// The value is less than 0
  FieldValidator<T> negative({String? message, bool stopOnFailure = false}) =>
      addRule(
        (value) => value == null || value < 0,
        message: () => message ?? _intl.errors.validations.negative,
        code: 'negative',
        stopOnFailure: stopOnFailure,
      );

  /// The value is 0 or less
  FieldValidator<T> negativeOrZero({
    String? message,
    bool stopOnFailure = false,
  }) => addRule(
    (value) => value == null || value <= 0,
    message: () => message ?? _intl.errors.validations.negativeOrZero,
    code: 'negativeOrZero',
    stopOnFailure: stopOnFailure,
  );
}

/// For a list, a set or any [Iterable]
extension IterableValidators<T extends Iterable<Object?>?>
    on FieldValidator<T> {
  /// The number of elements is between [min] and [max] (both inclusive)
  FieldValidator<T> size({
    int? min,
    int? max,
    String? message,
    bool stopOnFailure = false,
  }) => _size(this, value?.length, min, max, message, stopOnFailure);

  /// The value has at least one element
  FieldValidator<T> notEmpty({String? message, bool stopOnFailure = false}) =>
      addRule(
        (value) => value == null || value.isNotEmpty,
        message: () => message ?? _intl.errors.validations.notEmpty,
        code: 'notEmpty',
        stopOnFailure: stopOnFailure,
      );
}

/// For a [Map]
extension MapValidators<T extends Map<Object?, Object?>?> on FieldValidator<T> {
  /// The number of entries is between [min] and [max] (both inclusive)
  FieldValidator<T> size({
    int? min,
    int? max,
    String? message,
    bool stopOnFailure = false,
  }) => _size(this, value?.length, min, max, message, stopOnFailure);

  /// The value has at least one entry
  FieldValidator<T> notEmpty({String? message, bool stopOnFailure = false}) =>
      addRule(
        (value) => value == null || value.isNotEmpty,
        message: () => message ?? _intl.errors.validations.notEmpty,
        code: 'notEmpty',
        stopOnFailure: stopOnFailure,
      );
}

FieldValidator<T> _size<T>(
  FieldValidator<T> field,
  int? length,
  int? min,
  int? max,
  String? message,
  bool stopOnFailure,
) {
  if (min != null) {
    field.addRule(
      (_) => length == null || length >= min,
      message: () => message ?? _intl.errors.validations.size.min(value: min),
      code: 'size.min',
      params: {'value': min},
      stopOnFailure: stopOnFailure,
    );
  }
  if (max != null) {
    field.addRule(
      (_) => length == null || length <= max,
      message: () => message ?? _intl.errors.validations.size.max(value: max),
      code: 'size.max',
      params: {'value': max},
      stopOnFailure: stopOnFailure,
    );
  }
  return field;
}

/// For a [DateTime], compared with the `clock` of the [ConstraintValidatorContext]
extension DateTimeValidators<T extends DateTime?> on FieldValidator<T> {
  /// The date is before now
  FieldValidator<T> past({String? message, bool stopOnFailure = false}) =>
      _compareWithNow(
        (date, now) => date.isBefore(now),
        () => message ?? _intl.errors.validations.past,
        'past',
        stopOnFailure,
      );

  /// The date is now or before
  FieldValidator<T> pastOrPresent({
    String? message,
    bool stopOnFailure = false,
  }) => _compareWithNow(
    (date, now) => !date.isAfter(now),
    () => message ?? _intl.errors.validations.pastOrPresent,
    'pastOrPresent',
    stopOnFailure,
  );

  /// The date is after now
  FieldValidator<T> future({String? message, bool stopOnFailure = false}) =>
      _compareWithNow(
        (date, now) => date.isAfter(now),
        () => message ?? _intl.errors.validations.future,
        'future',
        stopOnFailure,
      );

  /// The date is now or after
  FieldValidator<T> futureOrPresent({
    String? message,
    bool stopOnFailure = false,
  }) => _compareWithNow(
    (date, now) => !date.isBefore(now),
    () => message ?? _intl.errors.validations.futureOrPresent,
    'futureOrPresent',
    stopOnFailure,
  );

  FieldValidator<T> _compareWithNow(
    bool Function(DateTime date, DateTime now) isValid,
    String Function() message,
    String code,
    bool stopOnFailure,
  ) => addRule(
    (value) => value == null || isValid(value, context.clock()),
    message: message,
    code: code,
    stopOnFailure: stopOnFailure,
  );
}
