import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('Validation Tests', () {
    test('Should pass when all fields are valid', () {
      final request = LoginRequest(
        username: 'test@example.com',
        password: 'password123',
      );

      final cvc = request.validate();

      expect(cvc.isValid, isTrue);
      expect(cvc.violations, isEmpty);
    });

    test('Should fail when username is null', () {
      final request = LoginRequest(username: null, password: 'password123');

      final cvc = request.validate();

      expect(cvc.isValid, isFalse);
      expect(
        cvc.violations.any(
          (v) =>
              v.fieldName == 'username' && v.message.contains('cannot be null'),
        ),
        isTrue,
      );

      // Because notNull has stopOnFailure: true by default, it shouldn't trigger size or email validations
      expect(
        cvc.violations.where((v) => v.fieldName == 'username').length,
        equals(1),
      );
    });

    test('Should fail when username is too short', () {
      final request = LoginRequest(username: 'a@', password: 'password123');

      final cvc = request.validate();

      expect(cvc.isValid, isFalse);
      expect(
        cvc.violations.any(
          (v) =>
              v.fieldName == 'username' &&
              v.message.contains('The minimum is 3'),
        ),
        isTrue,
      );
    });

    test('Should fail when password is too short', () {
      final request = LoginRequest(
        username: 'test@example.com',
        password: '123',
      );

      final cvc = request.validate();

      expect(cvc.isValid, isFalse);
      expect(
        cvc.violations.any(
          (v) =>
              v.fieldName == 'password' &&
              v.message.contains('The minimum is 8'),
        ),
        isTrue,
      );
    });

    test('Should merge multiple violations from different fields', () {
      final request = LoginRequest(username: null, password: 'short');

      final cvc = request.validate();

      expect(cvc.isValid, isFalse);
      expect(cvc.violations.any((v) => v.fieldName == 'username'), isTrue);
      expect(cvc.violations.any((v) => v.fieldName == 'password'), isTrue);
    });

    test('Should continue validations when stopOnFailure is false', () {
      final cvc = ConstraintValidatorContext();
      cvc
          .field('testField', 'some value')
          .custom((v) => 'error1', stopOnFailure: false)
          .custom((v) => 'error2', stopOnFailure: false);

      expect(cvc.violations.length, equals(2));
      expect(cvc.violations[0].message, equals('error1'));
      expect(cvc.violations[1].message, equals('error2'));
    });

    test('Should stop validations when stopOnFailure is true', () {
      final cvc = ConstraintValidatorContext();
      cvc
          .field('testField', 'some value')
          .custom((v) => 'error1', stopOnFailure: true)
          .custom((v) => 'error2', stopOnFailure: false);

      expect(cvc.violations.length, equals(1));
      expect(cvc.violations[0].message, equals('error1'));
    });
  });
}

class LoginRequest implements Validatable {
  final String? username;
  final String? password;

  LoginRequest({required this.username, required this.password});

  @override
  ConstraintValidatorContext validate() {
    ConstraintValidatorContext cvc = ConstraintValidatorContext();

    //username
    cvc
        .field('username', username)
        .notNull()
        .notBlank()
        .email()
        .size(min: 3, max: 20);

    //password
    cvc
        .field('password', password)
        .notNull()
        .size(min: 8, max: 20)
        .custom(
          (value) =>
              password == '12345678' ? 'Password can\'t be 12345678' : null,
        );

    return cvc;
  }
}
