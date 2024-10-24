import 'validation_service_impl.dart';

//-------------- Not Null --------------\\
class NotNull extends Valid with ValidMessage {
  const NotNull() : super(const [notNull]);

  @override
  String get defaultMessage => 'Value can\'t be null';
}

bool notNull(dynamic property, ConstraintValidatorContext cvc) {
  return property != null;
}

//-------------- Not Blank --------------\\
class NotBlank extends Valid with ValidMessage {
  const NotBlank() : super(const [notBlank]);

  @override
  String get defaultMessage => 'Value can\'t be blank';
}

bool notBlank(dynamic property, ConstraintValidatorContext cvc) {
  if (property == null) {
    return false;
  }
  if (property is! String) {
    throw StateError('NotBlank validation can only by tested on a String');
  }
  return property.replaceAll(' ', '').isNotEmpty;
}

//-------------- Not Empty --------------\\
class NotEmpty extends Valid with ValidMessage {
  final String? message;

  const NotEmpty({this.message}) : super(const [notEmpty]);

  @override
  String get defaultMessage => message ?? 'Value can\'t be empty';
}

bool notEmpty(dynamic property, ConstraintValidatorContext cvc) {
  if (property == null) {
    return true;
  } else if (property is String && property.isEmpty) {
    cvc.addTemplateViolation('Text can\'t be empty');
  } else if (property is List && property.isEmpty) {
    cvc.addTemplateViolation('List can\'t be empty');
  } else if (property is Map && property.isEmpty) {
    cvc.addTemplateViolation('Map can\'t be empty');
  } else if (property is Set && property.isEmpty) {
    cvc.addTemplateViolation('Set can\'t be empty');
  }
  return cvc.isValid();
}

class Size extends Valid {
  final int min;
  final int max;
  final bool validOnNull;

  const Size({
    required this.min,
    required this.max,
    this.validOnNull = true,
  }) : super(const [size]);
}

bool size(dynamic property, ConstraintValidatorContext cvc) {
  if (cvc.parent is! Size) {
    throw StateError(
      'size validation called inside a non Size annotation (@Size)',
    );
  }
  Size rawAnnotation = cvc.parent as Size;
  if (rawAnnotation.min > rawAnnotation.max) {
    throw StateError('Min size must be less than Max (min <= max)');
  }

  int length = 0;
  String type = '';
  if (property == null) {
    if (!rawAnnotation.validOnNull) {
      cvc.addTemplateViolation('Property can\'t be null');
    }
  } else if (property is String) {
    length = property.length;
    type = 'Text';
  } else if (property is List) {
    length = property.length;
    type = 'List';
  } else if (property is Map) {
    length = property.length;
    type = 'Map';
  } else if (property is Set) {
    length = property.length;
    type = 'Set';
  }

  if (length < rawAnnotation.min) {
    cvc.addTemplateViolation(
      '$type length must be greater than ${rawAnnotation.min}',
    );
  }
  if (length > rawAnnotation.max) {
    cvc.addTemplateViolation(
      '$type length must be less than ${rawAnnotation.max}',
    );
  }
  return cvc.isValid();
}
