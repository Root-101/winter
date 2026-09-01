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

  ConstraintValidator buildValidator(String propertyName) {
    return ConstraintValidator(propertyName, this);
  }

  @override
  String toString() {
    return 'ConstraintValidatorContext{_violations: $_violations}';
  }
}

/// Class that represent a fail validation
class ConstrainViolation implements Serializable {
  ///Valor con el que fallo la validacion
  final dynamic value;

  ///Nombre del campo en el que fallo la validacion
  ///Si forma parte de un objeto anidado o una lista o map o similar,
  ///el nombre del field sera una concatenacion de todos los field-name desde el root hasta el campos especifico
  final String fieldName;

  ///El mensaje de la validacion fallida
  final String message;

  const ConstrainViolation({
    required this.value,
    required this.fieldName,
    required this.message,
  });

  ConstrainViolation copyWith({
    dynamic value,
    String? fieldName,
    String? message,
  }) {
    return ConstrainViolation(
      value: value ?? this.value,
      fieldName: fieldName ?? this.fieldName,
      message: message ?? this.message,
    );
  }

  @override
  Object? toJson() {
    return {'value': value, 'fieldName': fieldName, 'message': message};
  }

  @override
  String toString() {
    return 'ConstrainViolation{value: $value, fieldName: $fieldName, message: $message}';
  }

  //needed for tests
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstrainViolation &&
          runtimeType == other.runtimeType &&
          value.toString() == other.value.toString() &&
          fieldName == other.fieldName &&
          message == other.message;

  @override
  int get hashCode => value.hashCode ^ fieldName.hashCode ^ message.hashCode;
}
