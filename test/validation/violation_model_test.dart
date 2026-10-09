import 'package:test/test.dart';
import 'package:winter/winter.dart';

enum _Color { red }

/// throwOnFailure and the rule that every validator but notNull passes on null. Equality and
/// copyWith of ConstraintViolation are in validation_behavior_test.dart.
void main() {
  group('throwOnFailure', () {
    test('throws a ValidationException with the violations', () {
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

    test('does nothing when valid', () {
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
}
