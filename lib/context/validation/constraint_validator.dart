import 'package:winter/winter.dart';

class _ValidationRule {
  final String? Function(dynamic) validator;
  final bool stopOnFailure;

  _ValidationRule(this.validator, {this.stopOnFailure = false});
}

class ConstraintValidator {
  final String propertyName;
  final ConstraintValidatorContext cvc;
  final List<_ValidationRule> _rules = [];

  ConstraintValidator(this.propertyName, this.cvc);

  /// Internal method to add a validation rule.
  /// This allows extensions to add rules without having access to the private [_rules] list.
  void addRule(
    String? Function(dynamic) validator, {
    bool stopOnFailure = false,
  }) {
    _rules.add(_ValidationRule(validator, stopOnFailure: stopOnFailure));
  }

  /// Executes all registered rules against the [value].
  void validate(dynamic value) {
    for (var rule in _rules) {
      final error = rule.validator(value);
      if (error != null) {
        cvc.addViolation(
          ConstrainViolation(
            value: value,
            fieldName: propertyName,
            message: error,
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
  ConstraintValidator notNull({String? message, bool stopOnFailure = true}) {
    addRule((value) {
      if (value == null) {
        return message ?? 'The field $propertyName cannot be null';
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
    addRule((value) {
      if (value == null) return null;
      if (value is! String || value.trim().isEmpty) {
        return message ?? 'The field $propertyName cannot be blank';
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
    addRule((value) {
      if (value == null) return null;
      if (value is String) {
        if (min != null && value.length < min) {
          return message ??
              'The field $propertyName must be at least $min characters long';
        }
        if (max != null && value.length > max) {
          return message ??
              'The field $propertyName must be at most $max characters long';
        }
      } else if (value is Iterable) {
        if (min != null && value.length < min) {
          return message ??
              'The field $propertyName must have at least $min items';
        }
        if (max != null && value.length > max) {
          return message ??
              'The field $propertyName must have at most $max items';
        }
      } else {
        return message ?? 'The field $propertyName must be a String or Iterable';
      }
      return null;
    }, stopOnFailure: stopOnFailure);
    return this;
  }
}

extension EmailValidator on ConstraintValidator {
  /// Validates that the value is a valid email.
  ConstraintValidator email({String? message, bool stopOnFailure = false}) {
    addRule((value) {
      if (value == null) return null;
      if (value is! String) {
        return message ?? 'The field $propertyName must be a String';
      }
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return message ?? 'The field $propertyName is not a valid email';
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
    addRule((value) {
      if (value == null) return null;
      if (value is! num) {
        return message ?? 'The field $propertyName must be a number';
      }
      final isInvalid = inclusive ? (value < min) : (value <= min);
      if (isInvalid) {
        final operator = inclusive ? 'at least' : 'greater than';
        return message ?? 'The field $propertyName must be $operator $min';
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
    addRule((value) {
      if (value == null) return null;
      if (value is! num) {
        return message ?? 'The field $propertyName must be a number';
      }
      final isInvalid = inclusive ? (value > max) : (value >= max);
      if (isInvalid) {
        final operator = inclusive ? 'at most' : 'less than';
        return message ?? 'The field $propertyName must be $operator $max';
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
    addRule((value) {
      if (value == null) return null;
      if (value is! String) {
        return message ?? 'The field $propertyName must be a String';
      }
      if (!RegExp(pattern.toString()).hasMatch(value)) {
        return message ?? 'The field $propertyName has an invalid format';
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
    addRule(
      (value) {
        if (value == null) return null;

        final resolvedValues =
            values.map((e) => resolver?.call(e) ?? e.name).toList();

        if (!resolvedValues.contains(value)) {
          final allowed = resolvedValues.join(', ');
          return message ?? 'The field $propertyName must be one of: $allowed';
        }
        return null;
      },
      stopOnFailure: stopOnFailure,
    );
    return this;
  }
}
