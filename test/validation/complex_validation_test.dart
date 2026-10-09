import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// merge() by hand, and paths through several levels of objects and lists. One level of
/// valid()/validEach() is in validation_behavior_test.dart.
void main() {
  test('merge() keeps the order, and a prefix names the path', () {
    ConstraintValidatorContext withViolation(String field) =>
        ConstraintValidatorContext()..addViolation(
          ConstraintViolation(value: null, fieldName: field, message: 'm'),
        );

    final cvc = withViolation('field1')
      ..merge(withViolation('field2'))
      ..merge(withViolation('field'), prefix: 'parent')
      ..merge(withViolation('field'), prefix: '[0]')
      ..merge(withViolation(''), prefix: 'items');

    expect(cvc.violations.map((v) => v.fieldName), [
      'field1',
      'field2',
      'parent.field',
      '[0].field',
      'items',
    ]);
  });

  test('three levels of objects', () {
    final root = _Root(
      child: _Child(grandChild: _GrandChild(name: '')),
    );

    expect(
      root.validate().violations.single.fieldName,
      'child.grandChild.name',
    );
  });

  test('lists inside lists', () {
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

    expect(catalog.validate().violations.map((v) => v.fieldName), [
      'categories[0].products[1].name',
      'categories[0].products[1].price',
      'categories[1].name',
    ]);
  });

  test('a valid tree has no violations', () {
    final catalog = _Catalog(
      categories: [
        _Category(
          name: 'Books',
          products: [_Product(name: 'Dune', price: 9)],
        ),
      ],
    );

    expect(catalog.validate().isValid, isTrue);
  });
}

class _GrandChild implements Validatable {
  final String name;

  _GrandChild({required this.name});

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('name', name).notBlank();
}

class _Child implements Validatable {
  final _GrandChild grandChild;

  _Child({required this.grandChild});

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('grandChild', grandChild).valid();
}

class _Root implements Validatable {
  final _Child child;

  _Root({required this.child});

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('child', child).valid();
}

class _Product implements Validatable {
  final String name;
  final double price;

  _Product({required this.name, required this.price});

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('name', name).notBlank()
    ..field('price', price).min(0);
}

class _Category implements Validatable {
  final String name;
  final List<_Product> products;

  _Category({required this.name, required this.products});

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('name', name).notBlank()
    ..field('products', products).validEach();
}

class _Catalog implements Validatable {
  final List<_Category> categories;

  _Catalog({required this.categories});

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('categories', categories).validEach();
}
