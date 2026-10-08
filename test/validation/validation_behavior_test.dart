@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:winter/winter.dart';

/// The behavior decided in the review of the validation (DECISIONS.md §3)
void main() {
  late ConstraintValidatorContext cvc;

  setUp(() => cvc = ConstraintValidatorContext());

  group('field(name, value): the rules run as they are chained (§3)', () {
    test('there is no final call to forget', () {
      cvc.field('name', null).notNull();

      expect(cvc.isValid, isFalse);
      expect(cvc.violations.single.fieldName, 'name');
    });

    test('stopOnFailure skips the next rules of the field, not the others', () {
      cvc.field('name', null).notNull().custom((value) => 'never');
      cvc.field('other', 'x').custom((value) => 'runs');

      expect(cvc.violations.map((v) => v.message), [
        'The field cannot be null',
        'runs',
      ]);
    });

    test('a custom rule is not run after a rule that stopped the field', () {
      cvc
          .field<String?>('name', null)
          .notNull()
          .custom((value) => value!.isEmpty ? 'empty' : null);

      expect(cvc.violations, hasLength(1));
    });

    test('a validator of your own is an extension that calls addRule', () {
      cvc.field('count', 3).even();

      expect(cvc.violations.single.toJson(), {
        'fieldName': 'count',
        'message': 'The value must be even',
        'code': 'even',
      });
    });
  });

  group('body<T>() validates by default (§3)', () {
    late WinterTestClient client;

    setUp(() {
      om.addDeserializer(Deserializer<_User>.json(_User.fromJson));
      addTearDown(() => om.removeDeserializer<_User>());
      client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/users',
              handler: (request) async =>
                  ResponseEntity.ok(body: (await request.body<_User>()).email),
            ),
            Route.post(
              path: '/users/batch',
              handler: (request) async => ResponseEntity.ok(
                body: (await request.body<List<_User>>()).length,
              ),
            ),
            Route.patch(
              path: '/users',
              handler: (request) async => ResponseEntity.ok(
                body: (await request.body<_User>(validate: false)).email,
              ),
            ),
          ],
        ),
      );
    });

    test('a valid body passes', () async {
      final response = await client.post('/users', body: {'email': 'a@b.co'});

      expect(response.statusCode, 200);
      expect(response.body, 'a@b.co');
    });

    test('an invalid body is a 422 with the violations', () async {
      final response = await client.post('/users', body: {'email': 'x'});

      expect(response.statusCode, 422);
      expect((response.json as Map)['violations'], [
        {
          'fieldName': 'email',
          'message': 'The value is not a valid email',
          'code': 'email',
        },
      ]);
    });

    test('every element of a list is validated, with its index', () async {
      final response = await client.post(
        '/users/batch',
        body: [
          {'email': 'a@b.co'},
          {'email': 'x'},
        ],
      );

      expect(response.statusCode, 422);
      expect(
        ((response.json as Map)['violations'] as List).single,
        containsPair('fieldName', '[1].email'),
      );
    });

    test('validate: false reads it without validating', () async {
      final response = await client.patch('/users', body: {'email': 'x'});

      expect(response.statusCode, 200);
      expect(response.body, 'x');
    });
  });

  group('Nested objects: valid() and validEach() (§3)', () {
    test('the violations are prefixed with the path', () {
      final order = _Order(
        address: _Address(zip: ''),
        items: [_Item(quantity: 1), null, _Item(quantity: 0)],
      );

      expect(order.validate().violations.map((v) => v.fieldName), [
        'address.zipCode',
        'items[2].quantity',
      ]);
    });

    test('a null nested object is only checked by notNull()', () {
      final cvc = _Order(address: null, items: null).validate();

      expect(cvc.violations.map((v) => v.fieldName), ['address']);
    });

    test('validEach() of a list without a name gives [0].field', () {
      cvc.field('', [_Item(quantity: 0)]).validEach();

      expect(cvc.violations.single.fieldName, '[0].quantity');
    });

    test('valid() and validEach() pass the clock to the nested objects', () {
      final fixed = ConstraintValidatorContext(clock: () => DateTime(2030));
      fixed.field('events', [_Event(DateTime(2029))]).validEach();

      expect(fixed.violations.single.fieldName, 'events[0].at');
    });
  });

  group('code and params (§3)', () {
    test('the JSON has the code and the parameters of the message', () {
      cvc.field('name', null).notNull();
      cvc.field('password', 'short', sensitive: true).size(min: 8);
      cvc.field('age', 5).min(18, inclusive: false);

      expect(cvc.violations.map((v) => v.toJson()), [
        {
          'fieldName': 'name',
          'message': 'The field cannot be null',
          'code': 'notNull',
        },
        {
          'fieldName': 'password',
          'message': 'The minimum is 8',
          'code': 'size.min',
          'params': {'value': 8},
        },
        {
          'fieldName': 'age',
          'message': 'The value must be greater than 18',
          'code': 'min.exclusive',
          'params': {'value': 18},
        },
      ]);
    });

    test('a custom rule has no code unless it gives one', () {
      cvc.field('name', 'x').custom((_) => 'bad');
      cvc.field('other', 'x').custom((_) => 'bad', code: 'my.code');

      expect(cvc.violations[0].toJson(), isNot(contains('code')));
      expect(cvc.violations[1].toJson(), containsPair('code', 'my.code'));
    });

    test('the allowed values are a list in params', () {
      cvc.field('color', 'blue').isEnum(_Color.values);
      cvc.field('size', 'XL').oneOf(['S', 'M']);

      expect(
        cvc.violations[0].toJson(),
        containsPair('params', {
          'values': ['red', 'green'],
        }),
      );
      expect(
        cvc.violations[1].toJson(),
        containsPair('params', {
          'values': ['S', 'M'],
        }),
      );
    });
  });

  group('The 422 never has the value (§3)', () {
    test('a value without toJson() is still a 422', () async {
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/',
              handler: (request) {
                final cvc = ConstraintValidatorContext();
                cvc.field('point', _Point()).custom((_) => 'invalid point');
                cvc.throwOnFailure();
                return ResponseEntity.ok();
              },
            ),
          ],
        ),
      );

      final response = await client.get('/');

      expect(response.statusCode, 422);
      expect((response.json as Map)['violations'], [
        {'fieldName': 'point', 'message': 'invalid point'},
      ]);
    });

    test('a valid request does not read the language (no Vary)', () async {
      Winter.context.setUp(
        localeConfig: LocaleConfig(
          supported: [WinterLocale.english, WinterLocale.spanish],
        ),
      );
      addTearDown(() => Winter.context.setUp(localeConfig: LocaleConfig()));
      final client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.get(
              path: '/',
              handler: (request) {
                final cvc = ConstraintValidatorContext();
                cvc.field('date', DateTime(2000)).notNull().past();
                cvc.field('n', 1).positive().min(0);
                cvc.throwOnFailure();
                return ResponseEntity.ok();
              },
            ),
          ],
        ),
      );

      final response = await client.get('/');

      expect(response.statusCode, 200);
      expect(response.headers, isNot(contains('vary')));
    });
  });

  group('ConstraintViolation equality (§3)', () {
    test('equal violations have the same hashCode', () {
      ConstraintViolation violation() =>
          (ConstraintValidatorContext()..field('c', 'x').oneOf(['a', 'b']))
              .violations
              .single;
      final a = violation();
      final b = violation();

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
      expect(
        a,
        isNot(
          a.copyWith(
            params: {
              'values': ['a'],
            },
          ),
        ),
      );
    });

    test('values that only look the same are not equal', () {
      const a = ConstraintViolation(value: 1, fieldName: 'f', message: 'm');
      const b = ConstraintViolation(value: '1', fieldName: 'f', message: 'm');

      expect(a, isNot(b));
    });

    test('toString shows the value, unless it is sensitive', () {
      cvc.field('name', 'Ann').size(min: 5);
      cvc.field('password', 'secret', sensitive: true).size(min: 8);

      expect(cvc.violations[0].toString(), contains('Ann'));
      expect(cvc.violations[1].toString(), isNot(contains('secret')));
      expect(cvc.violations[1].value, isNull);
    });
  });

  group('Chaining keeps the type of the field (§3)', () {
    test('validEach() after notEmpty()', () {
      cvc.field('items', [_Item(quantity: 0)]).notEmpty().validEach();

      expect(cvc.violations.single.fieldName, 'items[0].quantity');
    });

    test('valid() after notNull()', () {
      cvc.field('address', _Address(zip: '')).notNull().valid();

      expect(cvc.violations.single.fieldName, 'address.zipCode');
    });

    test('your own validator of int after min()', () {
      cvc.field('count', 3).min(1).even();

      expect(cvc.violations.single.code, 'even');
    });

    test('custom() after min() receives the type of the field', () {
      cvc
          .field('count', 3)
          .min(1)
          .custom((count) => count.isOdd ? 'odd' : null);
      cvc
          .field('name', 'Ann')
          .notBlank()
          .custom((name) => name.length < 5 ? 'short' : null);

      expect(cvc.violations.map((v) => v.message), ['odd', 'short']);
    });
  });

  group('fieldName follows the fieldNaming of the mapper (§3)', () {
    late WinterTestClient client;

    setUp(() {
      final previous = om;
      Winter.context.setUp(
        objectMapper: ObjectMapper(
          fieldNaming: FieldNaming.snakeCase,
          deserializers: [Deserializer<_Signup>.json(_Signup.fromJson)],
        ),
      );
      addTearDown(() => Winter.context.setUp(objectMapper: previous));
      client = WinterTestClient.build(
        router: WinterRouter(
          routes: [
            Route.post(
              path: '/',
              handler: (request) async {
                await request.body<_Signup>();
                return ResponseEntity.ok();
              },
            ),
          ],
        ),
      );
    });

    test('the 422 names the fields as the client sent them', () async {
      final response = await client.post(
        '/',
        body: '{"first_name": "", "home_address": {"zip_code": ""}}',
        headers: {HttpHeader.contentType: 'application/json'},
      );

      expect(response.statusCode, 422);
      expect(
        ((response.json as Map)['violations'] as List).map(
          (v) => (v as Map)['fieldName'],
        ),
        ['first_name', 'home_address.zip_code'],
      );
    });

    test('jsonFieldName() converts every name of a path, not the indexes', () {
      final snake = ObjectMapper(fieldNaming: FieldNaming.snakeCase);
      final kebab = ObjectMapper(fieldNaming: FieldNaming.kebabCase);

      expect(
        snake.jsonFieldName('lineItems[10].unitPrice'),
        'line_items[10].unit_price',
      );
      expect(
        kebab.jsonFieldName('homeAddress.zipCode'),
        'home-address.zip-code',
      );
      expect(
        ObjectMapper().jsonFieldName('homeAddress.zipCode'),
        'homeAddress.zipCode',
      );
    });
  });

  group('Fixes of the second review (§3)', () {
    test('url() rejects whitespace', () {
      cvc.field('host', 'http://exa mple.com').url();
      cvc.field('tab', 'http://example.com/\ta').url();

      expect(cvc.violations.map((v) => v.fieldName), ['host', 'tab']);
    });

    test('email() checks the lengths of RFC 5321', () {
      final local64 = '${'a' * 64}@example.com';
      final local65 = '${'a' * 65}@example.com';
      final total255 = 'a@${'b' * 63}.${'c' * 63}.${'d' * 63}.${'e' * 58}.co';

      cvc.field('local64', local64).email();
      cvc.field('local65', local65).email();
      cvc.field('total255', total255).email();

      expect(total255.length, 255);
      expect(cvc.violations.map((v) => v.fieldName), ['local65', 'total255']);
    });

    test('the params of oneOf() and isEnum() are JSON values', () async {
      final point = _Point();
      cvc.field('point', _Point()).oneOf([point]);
      cvc.field('code', 'x').isEnum(_Color.values, resolver: (_) => point);

      expect(cvc.violations[0].params['values'], ["Instance of '_Point'"]);
      expect(cvc.violations[1].params['values'], [
        "Instance of '_Point'",
        "Instance of '_Point'",
      ]);
      // So the 422 is never a 500
      expect(() => om.encode(cvc.violations), returnsNormally);
    });

    test('violationsOf() gives the violations of a field', () {
      cvc.field('email', 'x').email();
      cvc.field('age', 1).min(18).max(0);

      expect(cvc.violationsOf('email').single.code, 'email');
      expect(cvc.violationsOf('age').map((v) => v.code), [
        'min.inclusive',
        'max.inclusive',
      ]);
      expect(cvc.violationsOf('name'), isEmpty);
    });

    test('a validate() written with cascades', () {
      final violations = _Signup(
        firstName: '',
        address: null,
      ).validate().violations;

      expect(violations.map((v) => v.fieldName), ['firstName']);
    });
  });

  group('Validators (§3)', () {
    test('pattern() uses a RegExp as it is, flags included', () {
      cvc.field('a', 'abc').pattern(RegExp(r'^abc$'));
      cvc.field('b', 'ABC').pattern(RegExp(r'^abc$', caseSensitive: false));
      cvc.field('c', 'ABC').pattern(RegExp(r'^abc$'));

      expect(cvc.violations.map((v) => v.fieldName), ['c']);
    });

    test('pattern() with any other Pattern uses its matches', () {
      cvc.field('ok', 'a-b').pattern(const _Contains('-'));
      cvc.field('ko', 'ab').pattern(const _Contains('-'));

      expect(cvc.violations.map((v) => v.fieldName), ['ko']);
    });

    test('pattern() with a String is a regular expression', () {
      cvc.field('ok', '123').pattern(r'^\d+$');
      cvc.field('ko', '12a').pattern(r'^\d+$');

      expect(cvc.violations.map((v) => v.fieldName), ['ko']);
    });

    test('size() and notEmpty() work with a Map', () {
      cvc.field('tags', {'a': 1, 'b': 2}).size(max: 1);
      cvc.field('empty', <String, int>{}).notEmpty();

      expect(cvc.violations.map((v) => v.code), ['size.max', 'notEmpty']);
    });

    test('notEmpty() of a list or a set', () {
      cvc.field('list', <int>[]).notEmpty();
      cvc.field('set', {1}).notEmpty();

      expect(cvc.violations.map((v) => v.fieldName), ['list']);
    });

    test('url() needs a scheme of the list and a host', () {
      for (final valid in ['https://example.com', 'http://x.co/a?b=1']) {
        cvc.field('valid', valid).url();
      }
      for (final invalid in ['example.com', 'ftp://x.co', 'https://', 'a b']) {
        cvc.field(invalid, invalid).url();
      }
      cvc.field('ftp', 'ftp://x.co').url(schemes: ['ftp']);

      expect(cvc.violations.map((v) => v.fieldName), [
        'example.com',
        'ftp://x.co',
        'https://',
        'a b',
      ]);
      expect(
        cvc.violations.first.toJson(),
        containsPair('params', {
          'schemes': ['http', 'https'],
        }),
      );
    });

    test('uuid() of any version or of a given one', () {
      const v4 = '123e4567-e89b-42d3-a456-426614174000';
      cvc.field('any', v4).uuid();
      cvc.field('upper', v4.toUpperCase()).uuid();
      cvc.field('v4', v4).uuid(version: 4);
      cvc.field('v7', v4).uuid(version: 7);
      cvc.field('short', '123e4567-e89b-42d3-a456').uuid();

      expect(cvc.violations.map((v) => v.fieldName), ['v7', 'short']);
      expect(
        cvc.violations.first.toJson(),
        containsPair('params', {'version': 7}),
      );
    });

    test('positive(), negative() and their OrZero versions', () {
      for (final n in [-1, 0, 1]) {
        cvc.field('positive $n', n).positive();
        cvc.field('positiveOrZero $n', n).positiveOrZero();
        cvc.field('negative $n', n).negative();
        cvc.field('negativeOrZero $n', n).negativeOrZero();
      }

      expect(cvc.violations.map((v) => v.fieldName), [
        'positive -1',
        'positiveOrZero -1',
        'positive 0',
        'negative 0',
        'negative 1',
        'negativeOrZero 1',
      ]);
    });

    test('past(), future() and the OrPresent versions use the clock', () {
      final now = DateTime(2026, 10, 6, 12);
      final fixed = ConstraintValidatorContext(clock: () => now);
      final dates = {
        'before': now.subtract(const Duration(seconds: 1)),
        'now': now,
        'after': now.add(const Duration(seconds: 1)),
      };
      for (final MapEntry(key: name, value: date) in dates.entries) {
        fixed.field('past $name', date).past();
        fixed.field('pastOrPresent $name', date).pastOrPresent();
        fixed.field('future $name', date).future();
        fixed.field('futureOrPresent $name', date).futureOrPresent();
      }

      expect(fixed.violations.map((v) => v.fieldName), [
        'future before',
        'futureOrPresent before',
        'past now',
        'future now',
        'past after',
        'pastOrPresent after',
      ]);
    });

    test('oneOf() of enum values uses their names in the message', () {
      cvc.field('color', _Color.green).oneOf([_Color.red]);

      expect(cvc.violations.single.message, 'The value must be one of: red');
    });
  });
}

extension on FieldValidator<int?> {
  FieldValidator<int?> even() => addRule(
    (value) => value == null || value.isEven,
    message: () => 'The value must be even',
    code: 'even',
  );
}

enum _Color { red, green }

/// A [Pattern] that is not a RegExp nor a String
class _Contains implements Pattern {
  final String text;

  const _Contains(this.text);

  @override
  Iterable<Match> allMatches(String string, [int start = 0]) =>
      text.allMatches(string, start);

  @override
  Match? matchAsPrefix(String string, [int start = 0]) =>
      text.matchAsPrefix(string, start);
}

class _Point {}

class _Signup implements Validatable {
  final String? firstName;
  final _Address? address;

  _Signup({this.firstName, this.address});

  factory _Signup.fromJson(Map<String, dynamic> json) => _Signup(
    firstName: json['firstName'] as String?,
    address: json['homeAddress'] == null
        ? null
        : _Address(
            zip:
                (json['homeAddress'] as Map<String, dynamic>)['zipCode']
                    as String?,
          ),
  );

  @override
  ConstraintValidatorContext validate() => ConstraintValidatorContext()
    ..field('firstName', firstName).notBlank()
    ..field('homeAddress', address).valid();
}

class _User implements Validatable {
  final String? email;

  _User({this.email});

  factory _User.fromJson(Map<String, dynamic> json) =>
      _User(email: json['email'] as String?);

  Map<String, Object?> toJson() => {'email': email};

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('email', email).notNull().email();
    return cvc;
  }
}

class _Address implements Validatable {
  final String? zip;

  _Address({this.zip});

  @override
  ConstraintValidatorContext validate() =>
      ConstraintValidatorContext()..field('zipCode', zip).notBlank();
}

class _Item implements Validatable {
  final int quantity;

  _Item({required this.quantity});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('quantity', quantity).positive();
    return cvc;
  }
}

class _Order implements Validatable {
  final _Address? address;
  final List<_Item?>? items;

  _Order({required this.address, required this.items});

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('address', address).notNull().valid();
    cvc.field('items', items).validEach();
    return cvc;
  }
}

class _Event implements Validatable {
  final DateTime at;

  _Event(this.at);

  @override
  ConstraintValidatorContext validate() {
    final cvc = ConstraintValidatorContext();
    cvc.field('at', at).future();
    return cvc;
  }
}
