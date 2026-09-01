import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('ConstraintValidator Individual Methods Tests', () {
    group('notNull()', () {
      test('Success when value is not null', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notNull().validate('content');
        expect(cvc.isValid, isTrue);
      });

      test('Failure when value is null', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notNull().validate(null);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('cannot be null'));
      });

      test('Failure when value is null with custom message', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notNull(message: 'Required').validate(null);
        expect(cvc.violations.first.message, equals('Required'));
      });

      test('stopOnFailure: true (default) stops subsequent rules', () {
        final cvc = ConstraintValidatorContext();
        cvc
            .buildValidator('test')
            .notNull()
            .custom((v) => 'should not run')
            .validate(null);
        expect(cvc.violations.length, equals(1));
      });

      test('stopOnFailure: false continues to subsequent rules', () {
        final cvc = ConstraintValidatorContext();
        cvc
            .buildValidator('test')
            .notNull(stopOnFailure: false)
            .custom((v) => 'should run')
            .validate(null);
        expect(cvc.violations.length, equals(2));
      });
    });

    group('notBlank()', () {
      test('Success when string has content', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notBlank().validate('hello');
        expect(cvc.isValid, isTrue);
      });

      test('Failure when string is empty', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notBlank().validate('');
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('cannot be blank'));
      });

      test('Failure when string is whitespace', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notBlank().validate('   ');
        expect(cvc.isValid, isFalse);
      });

      test('Failure with custom message', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notBlank(message: 'Blank').validate('');
        expect(cvc.violations.first.message, equals('Blank'));
      });

      test('Ignore if value is null (delegate to notNull)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notBlank().validate(null);
        expect(cvc.isValid, isTrue);
      });

      test('Failure if value is not a string', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').notBlank().validate(123);
        expect(cvc.isValid, isFalse);
      });
    });

    group('size()', () {
      test('Success within bounds (String)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').size(min: 2, max: 5).validate('abc');
        expect(cvc.isValid, isTrue);
      });

      test('Failure too short (String)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').size(min: 5).validate('abc');
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('at least 5 characters'));
      });

      test('Failure too long (String)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').size(max: 2).validate('abc');
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('at most 2 characters'));
      });

      test('Success within bounds (List)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').size(min: 1, max: 2).validate([1]);
        expect(cvc.isValid, isTrue);
      });

      test('Failure too many items (List)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').size(max: 1).validate([1, 2]);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('at most 1 items'));
      });

      test('Exact size success', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').size(min: 3, max: 3).validate('abc');
        expect(cvc.isValid, isTrue);
      });

      test('Failure if value is not a String or Iterable', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').size(min: 1).validate(123);
        expect(cvc.isValid, isFalse);
        expect(
          cvc.violations.first.message,
          contains('must be a String or Iterable'),
        );
      });
    });

    group('email()', () {
      test('Success with valid email', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').email().validate('user@domain.com');
        expect(cvc.isValid, isTrue);
      });

      test('Failure if value is not a String', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').email().validate(123);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('must be a String'));
      });

      test('Failure with invalid formats', () {
        final invalidEmails = [
          'plain',
          '@missing-user',
          'user@',
          'user@.com',
          'user@domain..com',
        ];
        for (var email in invalidEmails) {
          final tempCvc = ConstraintValidatorContext();
          tempCvc.buildValidator('test').email().validate(email);
          expect(tempCvc.isValid, isFalse, reason: 'Failed for $email');
        }
      });
    });

    group('min()', () {
      test('Success when value >= min (inclusive: true)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').min(10).validate(10);
        cvc.buildValidator('test2').min(10).validate(11);
        expect(cvc.isValid, isTrue);
      });

      test('Failure when value == min (inclusive: false)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').min(10, inclusive: false).validate(10);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('greater than 10'));
      });

      test('Failure when value < min', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').min(10).validate(9.9);
        expect(cvc.isValid, isFalse);
      });

      test('Failure with non-numeric value', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').min(10).validate('10');
        expect(cvc.isValid, isFalse);
      });
    });

    group('max()', () {
      test('Success when value <= max (inclusive: true)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').max(10).validate(10);
        cvc.buildValidator('test2').max(10).validate(9);
        expect(cvc.isValid, isTrue);
      });

      test('Failure when value == max (inclusive: false)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').max(10, inclusive: false).validate(10);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('less than 10'));
      });

      test('Failure when value > max', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').max(10).validate(10.1);
        expect(cvc.isValid, isFalse);
      });

      test('Failure with non-numeric value', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').max(10).validate('10');
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('must be a number'));
      });
    });

    group('pattern()', () {
      test('Success with matching regex', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').pattern(r'^[0-9]+$').validate('12345');
        expect(cvc.isValid, isTrue);
      });

      test('Failure if value is not a String', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').pattern(r'^[0-9]+$').validate(123);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('must be a String'));
      });

      test('Failure with non-matching regex', () {
        final cvc = ConstraintValidatorContext();
        cvc
            .buildValidator('test')
            .pattern(RegExp(r'^[0-9]+$'))
            .validate('abc12');
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('invalid format'));
      });
    });

    group('custom()', () {
      test('Success when custom returns null', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').custom((v) => null).validate('any');
        expect(cvc.isValid, isTrue);
      });

      test('Failure when custom returns message', () {
        final cvc = ConstraintValidatorContext();
        cvc
            .buildValidator('test')
            .custom((v) => 'custom error')
            .validate('any');
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, equals('custom error'));
      });
    });

    group('isEnum()', () {
      test('Success matching by name (default)', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').isEnum(_TestEnum.values).validate('val1');
        expect(cvc.isValid, isTrue);
      });

      test('Failure when name does not exist', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').isEnum(_TestEnum.values).validate('other');
        expect(cvc.isValid, isFalse);
        expect(
          cvc.violations.first.message,
          contains('must be one of: val1, val2'),
        );
      });

      test('Success using custom resolver (index)', () {
        final cvc = ConstraintValidatorContext();
        cvc
            .buildValidator('test')
            .isEnum(_TestEnum.values, resolver: (e) => e.index)
            .validate(0);
        expect(cvc.isValid, isTrue);
      });

      test('Success matching against a specific list subset', () {
        final cvc = ConstraintValidatorContext();
        cvc.buildValidator('test').isEnum([_TestEnum.val1]).validate('val1');
        expect(cvc.isValid, isTrue);
      });
    });
  });

  group('ConstraintValidatorContext Internal Tests', () {
    test('Violations list should be unmodifiable', () {
      final cvc = ConstraintValidatorContext();
      cvc.addViolation(
        const ConstrainViolation(value: 1, fieldName: 'f', message: 'm'),
      );

      expect(
        () => (cvc.violations as dynamic).add(
          const ConstrainViolation(value: 2, fieldName: 'f2', message: 'm2'),
        ),
        throwsUnsupportedError,
      );
    });

    test('toString() contains violations', () {
      final cvc = ConstraintValidatorContext();
      cvc.addViolation(
        const ConstrainViolation(value: 1, fieldName: 'f', message: 'm'),
      );
      expect(cvc.toString(), contains('f'));
      expect(cvc.toString(), contains('m'));
    });
  });
}

enum _TestEnum { val1, val2 }
