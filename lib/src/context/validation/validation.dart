import 'dart:async';

import 'package:collection/collection.dart';
import 'package:winter/winter.dart';

/// An object that knows how to validate itself.
///
/// `body<T>()` validates a [Validatable] body (or a list of them) by default and answers 422
/// with the violations:
///
/// ```dart
/// class CreateUser implements Validatable {
///   final String? email;
///   final int? age;
///
///   CreateUser({this.email, this.age});
///
///   @override
///   ConstraintValidatorContext validate() {
///     final cvc = ConstraintValidatorContext();
///     cvc.field('email', email).notNull().email();
///     cvc.field('age', age).min(18);
///     return cvc;
///   }
/// }
/// ```
///
/// Build the validators inside [validate] (never in a `static final`), so their messages are in
/// the language of the request.
abstract interface class Validatable {
  /// The violations of this object, in a new [ConstraintValidatorContext]
  ConstraintValidatorContext validate();
}

/// Collects the [ConstraintViolation]s of a validation.
class ConstraintValidatorContext {
  /// The current time for `past()`, `future()`... Tests can give a fixed one.
  final DateTime Function() clock;

  final List<ConstraintViolation> _violations = [];

  /// A context without violations, with [clock] for the date validators. Without it, the clock of
  /// the object being validated by `valid()`/`validEach()` (so nested objects use the clock of the
  /// root), or `DateTime.now`.
  ConstraintValidatorContext({DateTime Function()? clock})
    : clock =
          clock ??
          Zone.current[_clockKey] as DateTime Function()? ??
          DateTime.now;

  static final Object _clockKey = Object();

  /// Runs the `validate()` of a nested object, whose new contexts take the [clock] of this one
  ConstraintValidatorContext _validateNested(Validatable nested) =>
      runZoned(nested.validate, zoneValues: {_clockKey: clock});

  /// Whether there is no violation
  bool get isValid => _violations.isEmpty;

  /// The violations found so far, in order (read-only)
  List<ConstraintViolation> get violations => UnmodifiableListView(_violations);

  /// Starts the validation of the field [name], whose value is [value]. Every validator chained
  /// on the result runs right away:
  ///
  /// ```dart
  /// cvc.field('email', email).notNull().email();
  /// ```
  ///
  /// The validators available depend on the type of [value] (`min()` only for numbers,
  /// `email()` only for Strings...). With [sensitive] (passwords, tokens) the value is never
  /// shown, not even in `toString()`.
  FieldValidator<T> field<T>(String name, T value, {bool sensitive = false}) =>
      FieldValidator._(this, name, value, sensitive: sensitive);

  /// Adds a violation found by hand
  void addViolation(ConstraintViolation violation) {
    _violations.add(violation);
  }

  /// Merges another [ConstraintValidatorContext] into this one.
  /// If a [prefix] is provided, it will be prepended to the field names of the merged violations
  /// (`address` + `zip` = `address.zip`, `items` + `[0].name` = `items[0].name`).
  ConstraintValidatorContext merge(
    ConstraintValidatorContext other, {
    String? prefix,
  }) {
    if (prefix == null || prefix.isEmpty) {
      _violations.addAll(other._violations);
      return this;
    }
    for (final violation in other._violations) {
      final String fieldName = switch (violation.fieldName) {
        '' => prefix,
        final name when name.startsWith('[') => '$prefix$name',
        final name => '$prefix.$name',
      };
      _violations.add(violation.copyWith(fieldName: fieldName));
    }
    return this;
  }

  /// Throws a [ValidationException] (422) when there is any violation
  void throwOnFailure() {
    if (!isValid) {
      throw ValidationException(violations: violations);
    }
  }

  @override
  String toString() {
    return 'ConstraintValidatorContext{violations: $_violations}';
  }
}

/// The validation of one field, created by [ConstraintValidatorContext.field].
///
/// The validators are extensions on it, for the type of the value (`FieldValidator<String?>`,
/// `FieldValidator<num?>`...), and each one runs as soon as it's chained. Every validator except
/// `notNull()` passes on `null`.
///
/// To write your own validator, add an extension that calls [addRule]:
///
/// ```dart
/// extension EvenValidator on FieldValidator<int?> {
///   FieldValidator<int?> even() => addRule(
///     (value) => value == null || value.isEven,
///     message: () => 'The value must be even',
///     code: 'even',
///   );
/// }
/// ```
class FieldValidator<T> {
  /// The context where the violations are added
  final ConstraintValidatorContext context;

  /// The name of the field, the `fieldName` of its violations
  final String name;

  /// The value being validated
  final T value;

  /// Hide the value (passwords, tokens)
  final bool sensitive;

  /// A rule with `stopOnFailure` failed: the next rules of this field are skipped
  bool _stopped = false;

  FieldValidator._(
    this.context,
    this.name,
    this.value, {
    required this.sensitive,
  });

  /// Runs a rule now: when [isValid] returns false, a violation with the [message] (built only
  /// then, so it can use the language of the request), [code] and [params] is added.
  /// With [stopOnFailure], a failure skips the next rules of this field.
  FieldValidator<T> addRule(
    bool Function(T value) isValid, {
    required String Function() message,
    String? code,
    Map<String, Object?> params = const {},
    bool stopOnFailure = false,
  }) {
    if (_stopped || isValid(value)) return this;
    context.addViolation(
      ConstraintViolation(
        // A sensitive value (a password) is never kept, so no log can show it
        value: sensitive ? null : value,
        fieldName: name,
        message: message(),
        code: code,
        params: params,
        sensitive: sensitive,
      ),
    );
    if (stopOnFailure) _stopped = true;
    return this;
  }

  /// Merges the violations of [other] prefixed with [prefix], unless a rule stopped the field
  FieldValidator<T> _mergeNested(
    ConstraintValidatorContext other, {
    required String prefix,
  }) {
    if (!_stopped) context.merge(other, prefix: prefix);
    return this;
  }
}

extension NestedValidator on FieldValidator<Validatable?> {
  /// Validates the nested object, prefixing its violations with the name of the field:
  /// `cvc.field('address', address).notNull().valid()` gives `address.zip`.
  FieldValidator<Validatable?> valid() {
    final Validatable? nested = value;
    return nested == null
        ? this
        : _mergeNested(context._validateNested(nested), prefix: name);
  }
}

extension NestedListValidator on FieldValidator<Iterable<Validatable?>?> {
  /// Validates every element of the list, prefixing its violations with the name of the field and
  /// the index: `cvc.field('items', items).validEach()` gives `items[0].quantity`.
  FieldValidator<Iterable<Validatable?>?> validEach() {
    final Iterable<Validatable?>? elements = value;
    if (elements == null) return this;
    final cvc = ConstraintValidatorContext(clock: context.clock);
    var index = 0;
    for (final element in elements) {
      if (element != null) {
        cvc.merge(context._validateNested(element), prefix: '[$index]');
      }
      index++;
    }
    return _mergeNested(cvc, prefix: name);
  }
}

/// A failed validation of a field.
///
/// Its JSON (the body of the 422) has the [fieldName], the [message] (in the language of the
/// request) and, for the validators of Winter, a [code] and its [params] that a client can use to
/// show its own text. The [value] is never in the JSON: the client knows what it sent.
class ConstraintViolation {
  /// The value that failed the validation, null for a [sensitive] field. Never in the JSON.
  final Object? value;

  /// Name of the field that failed the validation.
  /// In a nested object or a list it's the path from the root: `address.zip`, `items[0].name`.
  final String fieldName;

  /// Message of the failed validation, in the language of the request that validated it
  /// (`requestLocale`)
  final String message;

  /// Machine-readable reason: the key of the message in Winter's `*.i18n.yaml` (`notNull`,
  /// `size.min`...), or the one given to a custom rule. Null when there is none.
  final String? code;

  /// The parameters of the message (`{'value': 8}` for `size.min`)
  final Map<String, Object?> params;

  /// If true, the value is hidden in [toString]
  final bool sensitive;

  /// A violation of [fieldName] with its [message]
  const ConstraintViolation({
    required this.fieldName,
    required this.message,
    this.value,
    this.code,
    this.params = const {},
    this.sensitive = false,
  });

  /// A copy with the given fields replaced
  ConstraintViolation copyWith({
    Object? value,
    String? fieldName,
    String? message,
    String? code,
    Map<String, Object?>? params,
    bool? sensitive,
  }) {
    return ConstraintViolation(
      value: value ?? this.value,
      fieldName: fieldName ?? this.fieldName,
      message: message ?? this.message,
      code: code ?? this.code,
      params: params ?? this.params,
      sensitive: sensitive ?? this.sensitive,
    );
  }

  /// `fieldName`, `message`, and `code` and `params` when there are; never the value
  Map<String, Object?> toJson() => {
    'fieldName': fieldName,
    'message': message,
    if (code != null) 'code': code,
    if (params.isNotEmpty) 'params': params,
  };

  @override
  String toString() {
    return 'ConstraintViolation{fieldName: $fieldName, message: $message, code: $code, '
        'params: $params, value: ${sensitive ? '<hidden>' : value}}';
  }

  static const DeepCollectionEquality _paramsEquality =
      DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstraintViolation &&
          value == other.value &&
          fieldName == other.fieldName &&
          message == other.message &&
          code == other.code &&
          sensitive == other.sensitive &&
          _paramsEquality.equals(params, other.params);

  @override
  int get hashCode => Object.hash(
    value,
    fieldName,
    message,
    code,
    sensitive,
    _paramsEquality.hash(params),
  );
}
