import 'dart:mirrors';

import 'package:collection/collection.dart';

import '../../winter.dart';

typedef ValidationFunction = bool Function(
  dynamic object,
  ConstraintValidatorContext cvc,
);

class Valid {
  final List<ValidationFunction> validations;

  const Valid(this.validations);
}

mixin ValidMessage {
  String get defaultMessage;
}

class ConstraintValidatorContext {
  List<String> templateViolations;
  List<ConstrainViolation> constrainViolations;
  final bool concatParentName;
  final Valid parent;

  ConstraintValidatorContext({
    required this.parent,
    List<ConstrainViolation>? constrainViolations,
    this.concatParentName = true,
  })  : constrainViolations = constrainViolations ?? [],
        templateViolations = [];

  ///Add a default violation that will be completed with the default value and field name
  void addTemplateViolation(String message) {
    templateViolations.add(message);
  }

  ///Add a fully customizable violation
  void addViolation({
    required dynamic value,
    required String fieldName,
    required String message,
  }) {
    constrainViolations.add(
      ConstrainViolation(
        value: value,
        fieldName: fieldName,
        message: message,
      ),
    );
  }

  bool hasAnyViolations() {
    return constrainViolations.isNotEmpty || templateViolations.isNotEmpty;
  }

  bool isValid() {
    return constrainViolations.isEmpty && templateViolations.isEmpty;
  }
}

class ValidationServiceImpl extends ValidationService {
  late final NamingStrategy namingStrategy;
  final String? baseName;
  final String? defaultFieldSeparator;
  final bool? defaultTrowException;

  ValidationServiceImpl({
    NamingStrategy? namingStrategy,
    this.baseName = 'root',
    this.defaultFieldSeparator = '.',
    this.defaultTrowException = false,
  }) {
    this.namingStrategy = namingStrategy ?? NamingStrategies.basic;
  }

  @override
  List<ConstrainViolation> validate(
    dynamic object, {
    String? parentFieldName,
    String? fieldSeparator,
    bool? throwExceptionOnFail = false,
  }) {
    //if its null set the default base-name as parent field name, and,
    //the default field-separator
    //When: usually the first time its called if user dont specify it this default values are used
    parentFieldName ??= baseName;
    fieldSeparator ??= defaultFieldSeparator;
    throwExceptionOnFail ??= defaultTrowException;

    List<ConstrainViolation> violations = [];

    if (object is List) {
      for (var i = 0; i < object.length; ++i) {
        dynamic element = object[i];
        violations.addAll(
          validate(
            element,
            parentFieldName: '$parentFieldName[$i]',
          ),
        );
      }
    } else if (object is Map) {
      for (var element in object.entries) {
        violations.addAll(
          validate(
            element.value,
            parentFieldName: '$parentFieldName[${element.key}]',
          ),
        );
      }
    } else {
      if (object is Validatable) {
        violations.addAll(
          object.validate(
            parentFieldName: parentFieldName,
            fieldSeparator: fieldSeparator,
          ),
        );
      } else {
        var objectMirror = reflect(object);
        var classMirror = objectMirror.type;

        //process class level annotations
        List<Valid> rootValid = _getValid(classMirror.metadata);
        violations.addAll(
          processValid(
            valid: rootValid,
            fieldValue: object,
            fieldName: parentFieldName!,
          ),
        );

        for (var declaration in classMirror.declarations.values) {
          if (declaration is VariableMirror && !declaration.isStatic) {
            var fieldName =
                '$parentFieldName$fieldSeparator${_getFieldName(declaration)}';
            var fieldValue =
                objectMirror.getField(declaration.simpleName).reflectee;

            List<Valid> valid = _getValid(declaration.metadata);
            violations.addAll(
              processValid(
                valid: valid,
                fieldValue: fieldValue,
                fieldName: fieldName,
              ),
            );

            if (doRecursiveType(fieldValue)) {
              violations.addAll(
                validate(
                  fieldValue,
                  parentFieldName: fieldName,
                ),
              );
            }
          }
        }
      }
    }

    if (throwExceptionOnFail == true && violations.isNotEmpty) {
      throw ValidationException(violations: violations);
    } else {
      return violations;
    }
  }

  bool doRecursiveType(dynamic object) {
    bool primitive = object is int ||
        object is double ||
        object is bool ||
        object is String ||
        object is num ||
        object == null;
    if (primitive) {
      return false; //if its primitive, dont do recursive
    }
    if (object is Iterable || object is Map) {
      return true; //if its iterable (list) or map, do recursive, check every element
    }
    if (object is DateTime ||
        object is Duration ||
        object is Stream ||
        object is Future) {
      return false; //if its any of this types, dont validate recursive, are native types
    }

    //if not, check if its from dart SDK
    ClassMirror classMirror = reflect(object).type;
    Uri? libraryUri = classMirror.owner?.location?.sourceUri;

    // Si el URI de la biblioteca es del SDK, debería empezar con "dart:"
    bool isFromDartSdk = libraryUri?.scheme == 'dart';

    return !isFromDartSdk;
  }

  List<ConstrainViolation> processValid({
    required List<Valid> valid,
    required Object? fieldValue,
    required String fieldName,
  }) {
    List<ConstrainViolation> violations = [];
    if (valid.isNotEmpty) {
      for (var element in valid) {
        for (var singleValidation in element.validations) {
          ConstraintValidatorContext cvc = ConstraintValidatorContext(
            parent: element,
          );
          bool valid = singleValidation(fieldValue, cvc);
          if (!valid) {
            if (cvc.hasAnyViolations()) {
              violations.addAll(
                cvc.templateViolations
                    .map(
                      (message) => ConstrainViolation(
                        value: fieldValue,
                        fieldName: fieldName,
                        message: message,
                      ),
                    )
                    .toList(),
              );
              if (cvc.concatParentName) {
                violations.addAll(
                  cvc.constrainViolations
                      .map(
                        (e) => ConstrainViolation(
                          value: e.value,
                          fieldName: '$fieldName.${e.fieldName}',
                          message: e.message,
                        ),
                      )
                      .toList(),
                );
              } else {
                violations.addAll(cvc.constrainViolations);
              }
            } else if (element is ValidMessage) {
              violations.add(
                ConstrainViolation(
                  value: fieldValue,
                  fieldName: fieldName,
                  message: (element as ValidMessage).defaultMessage,
                ),
              );
            } else {
              violations.add(
                ConstrainViolation(
                  value: fieldValue,
                  fieldName: fieldName,
                  message: 'Error validating field',
                ),
              );
            }
          }
        }
      }
    }
    return violations;
  }

  List<Valid> _getValid(List<InstanceMirror> metadata) {
    Iterable<InstanceMirror> rawValid =
        metadata.where((element) => element.reflectee is Valid);
    return rawValid
        .map(
          (e) => e.reflectee as Valid,
        )
        .toList();
  }

  //Duplicated from object mapper
  String _getFieldName(DeclarationMirror field) {
    JsonProperty? jsonPropAnnotation = field.metadata
        .firstWhereOrNull((element) => element.reflectee is JsonProperty)
        ?.reflectee as JsonProperty?;

    if (jsonPropAnnotation != null) {
      return jsonPropAnnotation.name;
    }

    String rawFieldName = MirrorSystem.getName(field.simpleName);
    return namingStrategy(rawFieldName);
  }
}
