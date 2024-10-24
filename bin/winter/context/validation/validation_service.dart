import '../../winter.dart';

/// Class that represent a fail validation
/// (Details and examples in docs)
class ConstrainViolation {
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

///Default class to define the validation
abstract class ValidationService {
  List<ConstrainViolation> validate(
    dynamic object, {
    String? parentFieldName,
    String? fieldSeparator,
    bool? throwExceptionOnFail,
  });
}

///mixin to implement in every class where the validation want to be done it by hand
mixin Validatable {
  List<ConstrainViolation> validate({
    String? parentFieldName,
    String? fieldSeparator,
  });
}

///extension to make every object validatable
///Just call: `someObject.validate()`
///
/// NOTE: this only work with an already initialized winter-server with a
/// previously configured ValidationService instance
extension GloballyValidatable on Object {
  List<ConstrainViolation> validate({
    String? parentFieldName,
    String? fieldSeparator,
    bool? throwExceptionOnFail,
  }) {
    return vs.validate(
      this,
      parentFieldName: parentFieldName,
      fieldSeparator: fieldSeparator,
      throwExceptionOnFail: throwExceptionOnFail,
    );
  }
}
