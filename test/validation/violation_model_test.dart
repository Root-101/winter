import 'package:test/test.dart';
import 'package:winter/winter.dart';

enum _Color { red }

void main() {
  group('ConstraintViolation', () {
    const violation = ConstraintViolation(
      value: 'x',
      fieldName: 'name',
      message: 'too short',
    );

    test('equality & hashCode', () {
      const same = ConstraintViolation(
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
    test('throwOnFailure throws a ValidationException with the violations', () {
      final cvc = ConstraintValidatorContext();
      cvc.field('tags', ['only-one']).size(min: 2);

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
        .field<String?>('text', null)
        .notBlank()
        .size(min: 1)
        .email()
        .pattern(RegExp('x'))
        .url()
        .uuid()
        .isEnum(_Color.values)
        .oneOf(['a']);
    cvc
        .field<int?>('number', null)
        .min(1)
        .max(1)
        .positive()
        .negative()
        .positiveOrZero()
        .negativeOrZero();
    cvc.field<List<int>?>('list', null).size(min: 1).notEmpty();
    cvc.field<Map<String, int>?>('map', null).size(min: 1).notEmpty();
    cvc
        .field<DateTime?>('date', null)
        .past()
        .future()
        .pastOrPresent()
        .futureOrPresent();

    expect(cvc.isValid, isTrue);

    cvc.field('required', null).notNull();
    expect(cvc.violations.single.fieldName, 'required');
  });

  test('merge with a prefix names a violation without field name', () {
    final inner = ConstraintValidatorContext()
      ..addViolation(
        const ConstraintViolation(value: 1, fieldName: '', message: 'm'),
      );

    final outer = ConstraintValidatorContext()..merge(inner, prefix: 'items');

    expect(outer.violations.single.fieldName, 'items');
  });
}
