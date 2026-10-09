import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  validationFixesTests();

  group('ConstraintValidator Individual Methods Tests', () {
    group('notNull()', () {
      test('Success when value is not null', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'content').notNull();
        expect(cvc.isValid, isTrue);
      });

      test('Failure when value is null', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', null).notNull();
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('cannot be null'));
      });

      test('Failure when value is null with custom message', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', null).notNull(message: 'Required');
        expect(cvc.violations.first.message, equals('Required'));
      });

      test('stopOnFailure: true (default) stops subsequent rules', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', null).notNull().custom((v) => 'should not run');
        expect(cvc.violations.length, equals(1));
      });

      test('stopOnFailure: false continues to subsequent rules', () {
        final cvc = ConstraintValidatorContext();
        cvc
            .field('test', null)
            .notNull(stopOnFailure: false)
            .custom((v) => 'should run');
        expect(cvc.violations.length, equals(2));
      });
    });

    group('notBlank()', () {
      test('Success when string has content', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'hello').notBlank();
        expect(cvc.isValid, isTrue);
      });

      test('Failure when string is empty', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', '').notBlank();
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('cannot be blank'));
      });

      test('Failure when string is whitespace', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', '   ').notBlank();
        expect(cvc.isValid, isFalse);
      });

      test('Failure with custom message', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', '').notBlank(message: 'Blank');
        expect(cvc.violations.first.message, equals('Blank'));
      });

      test('Ignore if value is null (delegate to notNull)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', null).notBlank();
        expect(cvc.isValid, isTrue);
      });
    });

    group('size()', () {
      test('Success within bounds (String)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'abc').size(min: 2, max: 5);
        expect(cvc.isValid, isTrue);
      });

      test('Failure too short (String)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'abc').size(min: 5);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('The minimum is 5'));
      });

      test('Failure too long (String)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'abc').size(max: 2);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('The maximum is 2'));
      });

      test('Success within bounds (List)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', [1]).size(min: 1, max: 2);
        expect(cvc.isValid, isTrue);
      });

      test('Failure too many items (List)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', [1, 2]).size(max: 1);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('The maximum is 1'));
      });

      test('Exact size success', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'abc').size(min: 3, max: 3);
        expect(cvc.isValid, isTrue);
      });
    });

    group('email()', () {
      test('Success with valid email', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'user@domain.com').email();
        expect(cvc.isValid, isTrue);
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
          tempCvc.field('test', email).email();
          expect(tempCvc.isValid, isFalse, reason: 'Failed for $email');
        }
      });
    });

    group('min()', () {
      test('Success when value >= min (inclusive: true)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 10).min(10);
        cvc.field('test2', 11).min(10);
        expect(cvc.isValid, isTrue);
      });

      test('Failure when value == min (inclusive: false)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 10).min(10, inclusive: false);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('greater than 10'));
      });

      test('Failure when value < min', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 9.9).min(10);
        expect(cvc.isValid, isFalse);
      });
    });

    group('max()', () {
      test('Success when value <= max (inclusive: true)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 10).max(10);
        cvc.field('test2', 9).max(10);
        expect(cvc.isValid, isTrue);
      });

      test('Failure when value == max (inclusive: false)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 10).max(10, inclusive: false);
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('less than 10'));
      });

      test('Failure when value > max', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 10.1).max(10);
        expect(cvc.isValid, isFalse);
      });
    });

    group('pattern()', () {
      test('Success with matching regex', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', '12345').pattern(r'^[0-9]+$');
        expect(cvc.isValid, isTrue);
      });

      test('Failure with non-matching regex', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'abc12').pattern(RegExp(r'^[0-9]+$'));
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, contains('invalid format'));
      });
    });

    group('custom()', () {
      test('Success when custom returns null', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'any').custom((v) => null);
        expect(cvc.isValid, isTrue);
      });

      test('Failure when custom returns message', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'any').custom((v) => 'custom error');
        expect(cvc.isValid, isFalse);
        expect(cvc.violations.first.message, equals('custom error'));
      });
    });

    group('isEnum()', () {
      test('Success matching by name (default)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'val1').isEnum(_TestEnum.values);
        expect(cvc.isValid, isTrue);
      });

      test('Failure when name does not exist', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'other').isEnum(_TestEnum.values);
        expect(cvc.isValid, isFalse);
        expect(
          cvc.violations.first.message,
          contains('must be one of: val1, val2'),
        );
      });

      test('Success using custom resolver (index)', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 0).isEnum(_TestEnum.values, resolver: (e) => e.index);
        expect(cvc.isValid, isTrue);
      });

      test('Success matching against a specific list subset', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', 'val1').isEnum([_TestEnum.val1]);
        expect(cvc.isValid, isTrue);
      });
    });
  });

  group('ConstraintValidatorContext Internal Tests', () {
    test('Violations list should be unmodifiable', () {
      final cvc = ConstraintValidatorContext();
      cvc.addViolation(
        const ConstraintViolation(value: 1, fieldName: 'f', message: 'm'),
      );

      expect(
        () => (cvc.violations as dynamic).add(
          const ConstraintViolation(value: 2, fieldName: 'f2', message: 'm2'),
        ),
        throwsUnsupportedError,
      );
    });

    test('toString() contains violations', () {
      final cvc = ConstraintValidatorContext();
      cvc.addViolation(
        const ConstraintViolation(value: 1, fieldName: 'f', message: 'm'),
      );
      expect(cvc.toString(), contains('f'));
      expect(cvc.toString(), contains('m'));
    });
  });
}

void validationFixesTests() {
  group('email() accepted formats', () {
    for (final email in [
      'user+tag@domain.com',
      'first.last@sub.domain.co',
      'user@domain.photography',
      'user_name-1@my-domain.museum',
    ]) {
      test('Valid: $email', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', email).email();
        expect(cvc.isValid, isTrue);
      });
    }

    for (final email in [
      'user@domain',
      'user@-domain.com',
      'user@domain-.com',
      'user name@domain.com',
    ]) {
      test('Invalid: $email', () {
        final cvc = ConstraintValidatorContext();
        cvc.field('test', email).email();
        expect(cvc.isValid, isFalse);
      });
    }
  });

  group('Sensitive fields', () {
    test('The value of a sensitive field is never exposed', () {
      final cvc = ConstraintValidatorContext();
      cvc.field('password', 'secret', sensitive: true).size(min: 8);

      final violation = cvc.violations.single;
      expect(violation.value, isNull);
      expect(violation.toJson(), isNot(contains('value')));
      expect(violation.toJson(), containsPair('fieldName', 'password'));
      expect(violation.toString(), isNot(contains('secret')));
    });

    test('Sensitive stays hidden when merged with a prefix', () {
      final inner = ConstraintValidatorContext();
      inner.field('password', 'secret', sensitive: true).size(min: 8);

      final outer = ConstraintValidatorContext()..merge(inner, prefix: 'user');

      expect(outer.violations.single.fieldName, 'user.password');
      expect(outer.violations.single.toJson(), isNot(contains('value')));
    });

    test('Non sensitive fields keep the value in Dart, never in the JSON', () {
      final cvc = ConstraintValidatorContext();
      cvc.field('name', 'short').size(min: 8);

      expect(cvc.violations.single.value, 'short');
      expect(cvc.violations.single.toJson(), isNot(contains('value')));
    });
  });
}

enum _TestEnum { val1, val2 }
