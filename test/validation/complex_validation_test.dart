import 'package:test/test.dart';
import 'package:winter/winter.dart';

void main() {
  group('ConstraintValidatorContext Merge Tests', () {
    test('Should merge violations from two contexts', () {
      final cvc1 = ConstraintValidatorContext();
      cvc1.addViolation(
        const ConstrainViolation(
          value: null,
          fieldName: 'field1',
          message: 'error1',
        ),
      );

      final cvc2 = ConstraintValidatorContext();
      cvc2.addViolation(
        const ConstrainViolation(
          value: null,
          fieldName: 'field2',
          message: 'error2',
        ),
      );

      cvc1.merge(cvc2);

      expect(cvc1.violations.length, equals(2));
      expect(cvc1.violations[0].fieldName, equals('field1'));
      expect(cvc1.violations[1].fieldName, equals('field2'));
    });
  });

  group('ConstraintValidatorContext Merge with Prefix Tests', () {
    test('Should merge violations with prefix', () {
      final cvc1 = ConstraintValidatorContext();
      final cvc2 = ConstraintValidatorContext();
      cvc2.addViolation(
        const ConstrainViolation(
          value: 'val',
          fieldName: 'field',
          message: 'error',
        ),
      );

      cvc1.merge(cvc2, prefix: 'parent');

      expect(cvc1.violations.first.fieldName, equals('parent.field'));
    });

    test('Should merge violations with index prefix', () {
      final cvc1 = ConstraintValidatorContext();
      final cvc2 = ConstraintValidatorContext();
      cvc2.addViolation(
        const ConstrainViolation(
          value: 'val',
          fieldName: 'field',
          message: 'error',
        ),
      );

      cvc1.merge(cvc2, prefix: '[0]');

      expect(cvc1.violations.first.fieldName, equals('[0].field'));
    });
  });

  group('List Validation Tests', () {
    test('Should pass when all models are valid', () {
      final request = [
        _SimpleValidatable(name: 'test1'),
        _SimpleValidatable(name: 'test2'),
      ];

      final cvc = request.validate();

      expect(cvc.isValid, isTrue);
      expect(cvc.violations, isEmpty);
    });

    test('Should fail when an element in the list is invalid', () {
      final request = [
        _SimpleValidatable(name: 'valid'),
        _SimpleValidatable(name: null),
        _SimpleValidatable(name: ''),
      ];

      final cvc = request.validate(prefix: 'items');

      expect(cvc.isValid, isFalse);
      // items[1].name -> null -> notNull failure
      expect(cvc.violations.any((v) => v.fieldName == 'items[1].name'), isTrue);
      // items[2].name -> '' -> notBlank failure
      expect(cvc.violations.any((v) => v.fieldName == 'items[2].name'), isTrue);
    });
  });

  group('Complex Object Validation (Nested & Manual Merge)', () {
    test('Should validate nested object and manual merge with path', () {
      final user = _User(
        username: 'john_doe',
        profile: _Profile(email: 'invalid-email'),
        addresses: [
          _Address(street: 'Main St', city: ''),
          _Address(street: null, city: 'New York'),
        ],
      );

      final cvc = user.validate();

      expect(cvc.isValid, isFalse);

      // Check profile error
      expect(cvc.violations.any((v) => v.fieldName == 'profile.email'), isTrue);

      // Check address errors with indices
      // addresses[0].city -> '' -> notBlank
      expect(
        cvc.violations.any((v) => v.fieldName == 'addresses[0].city'),
        isTrue,
      );
      // addresses[1].street -> null -> notNull
      expect(
        cvc.violations.any((v) => v.fieldName == 'addresses[1].street'),
        isTrue,
      );
    });

    test('Should pass complex validation when everything is correct', () {
      final user = _User(
        username: 'john_doe',
        profile: _Profile(email: 'john@example.com'),
        addresses: [_Address(street: '123 Main St', city: 'Miami')],
      );

      final cvc = user.validate();
      expect(cvc.isValid, isTrue);
    });

    test('Deeply nested validation with 3 levels', () {
      final root = _Root(
        child: _Child(grandChild: _GrandChild(name: '')),
      );

      final cvc = root.validate();

      expect(cvc.isValid, isFalse);
      expect(
        cvc.violations.any((v) => v.fieldName == 'child.grandChild.name'),
        isTrue,
      );
    });

    test('Multiple nested lists validation', () {
      final catalog = _Catalog(
        categories: [
          _Category(
            name: 'Electronics',
            products: [
              _Product(name: 'Phone', price: 500),
              _Product(name: '', price: -1),
            ],
          ),
          _Category(name: '', products: []),
        ],
      );

      final cvc = catalog.validate();

      expect(cvc.isValid, isFalse);

      // Category 0, Product 1 errors
      expect(
        cvc.violations.any(
          (v) => v.fieldName == 'categories[0].products[1].name',
        ),
        isTrue,
      );
      expect(
        cvc.violations.any(
          (v) => v.fieldName == 'categories[0].products[1].price',
        ),
        isTrue,
      );

      // Category 1 errors
      expect(
        cvc.violations.any((v) => v.fieldName == 'categories[1].name'),
        isTrue,
      );
    });
  });
}

class _SimpleValidatable implements Validatable {
  final String? name;

  _SimpleValidatable({required this.name});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.buildValidator('name').notNull().notBlank().validate(name);
    return cvc;
  }
}

class _Profile implements Validatable {
  final String? email;

  _Profile({required this.email});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.buildValidator('email').notNull().email().validate(email);
    return cvc;
  }
}

class _Address implements Validatable {
  final String? street;
  final String? city;

  _Address({required this.street, required this.city});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.buildValidator('street').notNull().notBlank().validate(street);
    cvc.buildValidator('city').notNull().notBlank().validate(city);
    return cvc;
  }
}

class _User implements Validatable {
  final String? username;
  final _Profile profile;
  final List<_Address> addresses;

  _User({
    required this.username,
    required this.profile,
    required this.addresses,
  });

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();

    // 1. Validate self
    cvc.buildValidator('username').notNull().notBlank().validate(username);

    // 2. Validate nested object manually
    cvc.merge(profile.validate(), prefix: 'profile');

    // 3. Validate list of objects manually using extension or loop
    cvc.merge(addresses.validate(), prefix: 'addresses');

    return cvc;
  }
}

// Deep nesting models
class _GrandChild implements Validatable {
  final String name;

  _GrandChild({required this.name});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.buildValidator('name').notBlank().validate(name);
    return cvc;
  }
}

class _Child implements Validatable {
  final _GrandChild grandChild;

  _Child({required this.grandChild});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.merge(grandChild.validate(), prefix: 'grandChild');
    return cvc;
  }
}

class _Root implements Validatable {
  final _Child child;

  _Root({required this.child});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.merge(child.validate(), prefix: 'child');
    return cvc;
  }
}

// Multiple nested lists models
class _Product implements Validatable {
  final String name;
  final double price;

  _Product({required this.name, required this.price});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.buildValidator('name').notBlank().validate(name);
    cvc.buildValidator('price').min(0).validate(price);
    return cvc;
  }
}

class _Category implements Validatable {
  final String name;
  final List<_Product> products;

  _Category({required this.name, required this.products});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.buildValidator('name').notBlank().validate(name);
    cvc.merge(products.validate(), prefix: 'products');
    return cvc;
  }
}

class _Catalog implements Validatable {
  final List<_Category> categories;

  _Catalog({required this.categories});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.merge(categories.validate(), prefix: 'categories');
    return cvc;
  }
}
