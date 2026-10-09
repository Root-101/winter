import 'package:auth_security_example/auth_security_example.dart';

/// The body of `POST /register`: its format is checked first (`validate`), and only then whether
/// the email is free (`validateAsync`, a lookup), both as a 422 per field
class RegisterRequest implements Validatable, AsyncValidatable {
  final String name;
  final String email;
  final String password;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      RegisterRequest(
        name: json.field<String>('name'),
        email: json.field<String>('email'),
        password: json.field<String>('password'),
      );

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('name', name).notBlank()
    ..field('email', email).email()
    ..field('password', password, sensitive: true).size(min: 8);

  /// Runs only when [validate] passed: an invalid email never reaches the lookup
  @override
  Future<ConstraintValidatorContext> validateAsync() async {
    final cvc = ConstraintValidatorContext();
    await cvc.check(
      'email',
      () async => di.find<UserService>().getByEmail(email) == null,
      message: () => 'The email is already registered',
      code: 'email.taken',
    );
    return cvc;
  }
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) => LoginRequest(
    email: json['email'] as String,
    password: json['password'] as String,
  );
}
