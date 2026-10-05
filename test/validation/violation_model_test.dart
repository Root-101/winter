import 'package:test/test.dart';
import 'package:winter/winter.dart';

class _EmptyModel extends Validatable {}

enum _Color { red }

void main() {
  group('ConstrainViolation', () {
    const violation = ConstrainViolation(
      value: 'x',
      fieldName: 'name',
      message: 'too short',
    );

    test('equality & hashCode', () {
      const same = ConstrainViolation(
        value: 'x',
        fieldName: 'name',
        message: 'too short',
      );

      expect(violation, same);
      expect(violation.hashCode, same.hashCode);
      expect(violation, isNot(violation.copyWith(message: 'other')));
      expect(violation, isNot(violation.copyWith(sensitive: true)));
    });

    test('copyWith changes only the given fields', () {
      final copy = violation.copyWith(fieldName: 'user.name');

      expect(copy.fieldName, 'user.name');
      expect(copy.value, 'x');
      expect(copy.message, 'too short');
      expect(copy.sensitive, isFalse);
    });
  });

  group('Validatable', () {
    test('a model without rules is valid by default', () {
      expect(_EmptyModel().validate().isValid, isTrue);
    });

    test('throwOnFailure throws a ValidationException with the violations', () {
      final cvc = ConstraintValidatorContext();
      cvc.buildValidator('tags').size(min: 2).validate(['only-one']);

      expect(
        cvc.throwOnFailure,
        throwsA(
          isA<ValidationException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.violations.single.message,
                'message',
                'The minimum is 2',
              )
              .having((e) => e.toString(), 'toString', contains('tags')),
        ),
      );
    });

    test('throwOnFailure does nothing when valid', () {
      expect(ConstraintValidatorContext().throwOnFailure, returnsNormally);
    });
  });

  test('Optional fields: null is valid for every rule except notNull', () {
    final cvc = ConstraintValidatorContext();
    cvc
        .buildValidator('optional')
        .notBlank()
        .size(min: 1)
        .email()
        .min(1)
        .max(1)
        .pattern(RegExp('x'))
        .isEnum(_Color.values)
        .validate(null);

    expect(cvc.isValid, isTrue);

    cvc.buildValidator('required').notNull().validate(null);
    expect(cvc.violations.single.fieldName, 'required');
  });

  test('merge with a prefix names a violation without field name', () {
    final inner = ConstraintValidatorContext()
      ..addViolation(
        const ConstrainViolation(value: 1, fieldName: '', message: 'm'),
      );

    final outer = ConstraintValidatorContext()..merge(inner, prefix: 'items');

    expect(outer.violations.single.fieldName, 'items');
  });
}
