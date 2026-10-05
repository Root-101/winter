import 'package:winter/src/i18n/winter_messages.dart';
import 'package:winter/winter.dart';

class _ValidationRule {
  final LocalizedText? Function(dynamic) validator;

  ///False for rules with a fixed message ([ConstraintValidator.addRule]): their violation has no `localizedMessage`
  final bool localized;
  final bool stopOnFailure;

  _ValidationRule(
    this.validator, {
    required this.localized,
    this.stopOnFailure = false,
  });
}

class ConstraintValidator {
  final String propertyName;
  final ConstraintValidatorContext cvc;
  final List<_ValidationRule> _rules = [];

  /// If true, the value is not included in the violations (ex: passwords, tokens),
  /// so it's never sent back in the response
  final bool sensitive;

  ConstraintValidator(this.propertyName, this.cvc, {this.sensitive = false});

  /// Internal method to add a validation rule.
  /// This allows extensions to add rules without having access to the private [_rules] list.
  void addRule(
    String? Function(dynamic) validator, {
    bool stopOnFailure = false,
  }) {
    _rules.add(
      _ValidationRule(
        (value) {
          final String? message = validator(value);
          return message == null ? null : (_) => message;
        },
        localized: false,
        stopOnFailure: stopOnFailure,
      ),
    );
  }

  /// Like [addRule], but the message is translated when the response is built (see [LocalizedText]).
  /// The violation keeps the English text in `message` (for logs) and the function in `localizedMessage`.
  void addLocalizedRule(
    LocalizedText? Function(dynamic) validator, {
    bool stopOnFailure = false,
  }) {
    _rules.add(
      _ValidationRule(validator, localized: true, stopOnFailure: stopOnFailure),
    );
  }

  /// Executes all registered rules against the [value].
  void validate(dynamic value) {
    for (var rule in _rules) {
      final LocalizedText? error = rule.validator(value);
      if (error != null) {
        cvc.addViolation(
          ConstrainViolation(
            value: sensitive ? null : value,
            fieldName: propertyName,
            message: error(WinterLocale.english),
            localizedMessage: rule.localized ? error : null,
            sensitive: sensitive,
          ),
        );
        if (rule.stopOnFailure) break;
      }
    }
  }
}

extension NotNullValidator on ConstraintValidator {
  /// Validates that the value is not null.
  /// If [stopOnFailure] is true, the validation process for this field will stop if the value is null.
  /// A custom [message] is used as is, in every language.
  ConstraintValidator notNull({String? message, bool stopOnFailure = true}) {
    addLocalizedRule((value) {
      if (value == null) {
        return _text(message, (m) => m.errors.validations.notNull);
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}

extension NotBlankValidator on ConstraintValidator {
  /// Validates that the string value is not empty or composed only of whitespace.
  /// If [stopOnFailure] is true, the validation process for this field will stop if the value is blank.
  ConstraintValidator notBlank({String? message, bool stopOnFailure = false}) {
    addLocalizedRule((value) {
      if (value == null) return null;
      if (value is! String || value.trim().isEmpty) {
        return _text(message, (m) => m.errors.validations.notBlank);
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}

extension SizeValidator on ConstraintValidator {
  /// Validates the size of a String or Iterable.
  ConstraintValidator size({
    int? min,
    int? max,
    String? message,
    bool stopOnFailure = false,
  }) {
    addLocalizedRule((value) {
      if (value == null) return null;
      final int length;
      if (value is String) {
        length = value.length;
      } else if (value is Iterable) {
        length = value.length;
      } else {
        return _text(message, (m) => m.errors.validations.size.invalidType);
      }
      if (min != null && length < min) {
        return _text(message, (m) => m.errors.validations.size.min(value: min));
      }
      if (max != null && length > max) {
        return _text(message, (m) => m.errors.validations.size.max(value: max));
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}

/// The custom [message] of the user (same in every language) or the translated message of Winter
LocalizedText _text(String? message, String Function(WinterMessages) text) =>
    message != null ? (_) => message : (locale) => text(winterMessages(locale));

/// Same rules as the HTML5 spec (WHATWG) for `<input type="email">`, but requiring a dot in the domain:
/// - local part: letters, digits and the special characters allowed by the spec (so `user+tag@x.com` is valid)
/// - domain: labels of letters, digits and `-` (not at the start/end of the label), any TLD length
final RegExp _emailRegex = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+"
  r'@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
);

extension EmailValidator on ConstraintValidator {
  /// Validates that the value is a valid email.
  ConstraintValidator email({String? message, bool stopOnFailure = false}) {
    addLocalizedRule((value) {
      if (value == null) return null;
      if (value is! String) {
        return _text(message, (m) => m.errors.validations.type.string);
      }
      if (!_emailRegex.hasMatch(value)) {
        return _text(message, (m) => m.errors.validations.email);
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}

extension MinValidator on ConstraintValidator {
  /// Validates that the numeric value is at least [min].
  /// If [inclusive] is true (default), the value must be greater than or equal to [min].
  /// If [inclusive] is false, the value must be strictly greater than [min].
  ConstraintValidator min(
    num min, {
    String? message,
    bool inclusive = true,
    bool stopOnFailure = false,
  }) {
    addLocalizedRule((value) {
      if (value == null) return null;
      if (value is! num) {
        return _text(message, (m) => m.errors.validations.type.number);
      }
      final isInvalid = inclusive ? (value < min) : (value <= min);
      if (isInvalid) {
        return _text(
          message,
          (m) => inclusive
              ? m.errors.validations.min.inclusive(value: min)
              : m.errors.validations.min.exclusive(value: min),
        );
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}

extension MaxValidator on ConstraintValidator {
  /// Validates that the numeric value is at most [max].
  /// If [inclusive] is true (default), the value must be less than or equal to [max].
  /// If [inclusive] is false, the value must be strictly less than [max].
  ConstraintValidator max(
    num max, {
    String? message,
    bool inclusive = true,
    bool stopOnFailure = false,
  }) {
    addLocalizedRule((value) {
      if (value == null) return null;
      if (value is! num) {
        return _text(message, (m) => m.errors.validations.type.number);
      }
      final isInvalid = inclusive ? (value > max) : (value >= max);
      if (isInvalid) {
        return _text(
          message,
          (m) => inclusive
              ? m.errors.validations.max.inclusive(value: max)
              : m.errors.validations.max.exclusive(value: max),
        );
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}

extension PatternValidator on ConstraintValidator {
  /// Validates that the value matches the [pattern].
  ConstraintValidator pattern(
    Pattern pattern, {
    String? message,
    bool stopOnFailure = false,
  }) {
    addLocalizedRule((value) {
      if (value == null) return null;
      if (value is! String) {
        return _text(message, (m) => m.errors.validations.type.string);
      }
      if (!RegExp(pattern.toString()).hasMatch(value)) {
        return _text(message, (m) => m.errors.validations.pattern);
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}

extension CustomValidator on ConstraintValidator {
  /// Adds a custom validation rule.
  /// The [validator] function should return an error message if the value is invalid,
  /// or `null` if the value is valid.
  ConstraintValidator custom(
    String? Function(dynamic value) validator, {
    bool stopOnFailure = false,
  }) {
    addRule(validator, stopOnFailure: stopOnFailure);
    return this;
  }
}

extension EnumValidator on ConstraintValidator {
  /// Validates that the value matches one of the allowed enum values.
  /// By default, it matches the value against the enum's name.
  /// A custom [resolver] can be provided to change how enum values are compared (e.g., comparing against a specific property).
  ConstraintValidator isEnum<T extends Enum>(
    Iterable<T> values, {
    Object? Function(T)? resolver,
    String? message,
    bool stopOnFailure = false,
  }) {
    addLocalizedRule((value) {
      if (value == null) return null;

      final resolvedValues = values
          .map((e) => resolver?.call(e) ?? e.name)
          .toList();

      if (!resolvedValues.contains(value)) {
        final allowed = resolvedValues.join(', ');
        return _text(
          message,
          (m) => m.errors.validations.isEnum(values: allowed),
        );
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}
