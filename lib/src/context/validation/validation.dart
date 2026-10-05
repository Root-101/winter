import 'package:winter/winter.dart';

abstract class Validatable {
  ConstraintValidatorContext validate() {
    return ConstraintValidatorContext();
  }
}

extension ValidatableExtension on List<Validatable> {
  ConstraintValidatorContext validate({String? prefix}) {
    final cvc = ConstraintValidatorContext();
    for (var i = 0; i < length; i++) {
      final itemPrefix = prefix != null ? '$prefix[$i]' : '[$i]';
      cvc.merge(this[i].validate(), prefix: itemPrefix);
    }
    return cvc;
  }
}

class ConstraintValidatorContext {
  final List<ConstrainViolation> _violations = [];

  bool get isValid => _violations.isEmpty;

  List<ConstrainViolation> get violations => List.unmodifiable(_violations);

  void addViolation(ConstrainViolation violation) {
    _violations.add(violation);
  }

  /// Merges another [ConstraintValidatorContext] into this one.
  /// If a [prefix] is provided, it will be prepended to the field names of the merged violations.
  ConstraintValidatorContext merge(
    ConstraintValidatorContext other, {
    String? prefix,
  }) {
    if (prefix == null || prefix.isEmpty) {
      _violations.addAll(other._violations);
    } else {
      _violations.addAll(
        other._violations.map((v) {
          final String newFieldName;
          if (v.fieldName.isEmpty) {
            newFieldName = prefix;
          } else if (v.fieldName.startsWith('[')) {
            newFieldName = '$prefix${v.fieldName}';
          } else {
            newFieldName = '$prefix.${v.fieldName}';
          }
          return v.copyWith(fieldName: newFieldName);
        }),
      );
    }
    return this;
  }

  /// Use [sensitive] for fields like passwords or tokens: their value is never included in the violations
  ConstraintValidator buildValidator(
    String propertyName, {
    bool sensitive = false,
  }) {
    return ConstraintValidator(propertyName, this, sensitive: sensitive);
  }

  @override
  String toString() {
    return 'ConstraintValidatorContext{_violations: $_violations}';
  }

  void throwOnFailure() {
    if (!isValid) {
      throw ValidationException(violations: violations);
    }
  }
}

/// Class that represent a fail validation
class ConstrainViolation implements Serializable {
  ///Value that failed the validation
  final dynamic value;

  ///Name of the field that failed the validation
  ///Si forma parte de un objeto anidado o una lista o map o similar,
  ///the name will be the concatenation of every field-name from the root to the specific field
  final String fieldName;

  ///Message of the failed validation, always in English (it's the one in logs and `toString`)
  final String message;

  ///Translated message, resolved with the locale of the request when the response is built.
  ///Null when the message is the same in every language (custom message, `addRule`).
  final LocalizedText? localizedMessage;

  ///If true, the value is hidden (not included in the json nor in the toString)
  final bool sensitive;

  const ConstrainViolation({
    required this.value,
    required this.fieldName,
    required this.message,
    this.localizedMessage,
    this.sensitive = false,
  });

  /// [message] for [locale]
  String messageFor(WinterLocale locale) =>
      localizedMessage?.call(locale) ?? message;

  /// A copy with the [message] in [locale] and without `localizedMessage`
  ConstrainViolation localize(WinterLocale locale) => ConstrainViolation(
    value: value,
    fieldName: fieldName,
    message: messageFor(locale),
    sensitive: sensitive,
  );

  /// A new [message] without a new [localizedMessage] drops the old translation
  ConstrainViolation copyWith({
    dynamic value,
    String? fieldName,
    String? message,
    LocalizedText? localizedMessage,
    bool? sensitive,
  }) {
    return ConstrainViolation(
      value: value ?? this.value,
      fieldName: fieldName ?? this.fieldName,
      message: message ?? this.message,
      localizedMessage:
          localizedMessage ?? (message == null ? this.localizedMessage : null),
      sensitive: sensitive ?? this.sensitive,
    );
  }

  @override
  Object? toJson() {
    return {
      if (!sensitive) 'value': value,
      'fieldName': fieldName,
      'message': message,
    };
  }

  @override
  String toString() {
    return 'ConstrainViolation{value: ${sensitive ? '<hidden>' : value}, fieldName: $fieldName, message: $message}';
  }

  //needed for tests
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstrainViolation &&
          runtimeType == other.runtimeType &&
          value.toString() == other.value.toString() &&
          fieldName == other.fieldName &&
          message == other.message &&
          sensitive == other.sensitive;

  @override
  int get hashCode =>
      value.hashCode ^
      fieldName.hashCode ^
      message.hashCode ^
      sensitive.hashCode;
}
